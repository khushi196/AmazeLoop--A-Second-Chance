/**
 * AmazeLoopRouteFunction  (POST /route)
 *
 * Given an evaluationId, fetches the Evaluation record and reads the fields
 * needed to decide the best disposition route for the item. The routing
 * decision logic is built on top of these inputs.
 *
 * Request:  { "evaluationId": "EVAL-..." }
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

// ---------------------------------------------------------------------------
// Configuration & shared clients
// ---------------------------------------------------------------------------
const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
const MODEL_ID = process.env.BEDROCK_MODEL_ID || "apac.amazon.nova-lite-v1:0";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));
const bedrock = new BedrockRuntimeClient({ region: REGION });

// ---------------------------------------------------------------------------
// Warehouse network (main fulfilment hubs) with coordinates
// ---------------------------------------------------------------------------
const WAREHOUSES = [
  { id: "BLR", city: "Bengaluru", pincode: "560001", lat: 12.9716, lng: 77.5946 },
  { id: "MUM", city: "Mumbai",    pincode: "400001", lat: 19.0760, lng: 72.8777 },
  { id: "DEL", city: "Delhi",     pincode: "110001", lat: 28.6139, lng: 77.2090 },
  { id: "HYD", city: "Hyderabad", pincode: "500001", lat: 17.3850, lng: 78.4867 },
  { id: "MAA", city: "Chennai",   pincode: "600001", lat: 13.0827, lng: 80.2707 },
  { id: "PNQ", city: "Pune",      pincode: "411001", lat: 18.5204, lng: 73.8567 },
];

// Approximate lat/long centroids by Indian PIN code prefix.
// 3-digit prefixes (cities) take priority; 2-digit prefixes cover the region.
const PIN3_COORDS = {
  "560": [12.9716, 77.5946], // Bengaluru
  "400": [19.0760, 72.8777], // Mumbai
  "110": [28.6139, 77.2090], // Delhi
  "500": [17.3850, 78.4867], // Hyderabad
  "600": [13.0827, 80.2707], // Chennai
  "411": [18.5204, 73.8567], // Pune
  "700": [22.5726, 88.3639], // Kolkata
  "380": [23.0225, 72.5714], // Ahmedabad
  "302": [26.9124, 75.7873], // Jaipur
  "226": [26.8467, 80.9462], // Lucknow
};
const PIN2_COORDS = {
  "11": [28.6139, 77.2090], "12": [28.4595, 77.0266], "13": [30.7333, 76.7794],
  "14": [30.9010, 75.8573], "15": [31.6340, 74.8723], "20": [27.1767, 78.0081],
  "21": [27.8974, 78.0880], "22": [25.4358, 81.8463], "26": [26.8467, 80.9462],
  "30": [26.9124, 75.7873], "34": [24.5854, 73.7125], "36": [23.0225, 72.5714],
  "38": [23.0225, 72.5714], "39": [22.3072, 73.1812], "40": [19.0760, 72.8777],
  "41": [18.5204, 73.8567], "42": [19.9975, 73.7898], "44": [21.1458, 79.0882],
  "45": [22.7196, 75.8577], "46": [23.2599, 77.4126], "50": [17.3850, 78.4867],
  "51": [17.6868, 83.2185], "52": [16.5062, 80.6480], "53": [17.6868, 83.2185],
  "56": [12.9716, 77.5946], "57": [15.3647, 75.1240], "58": [12.9141, 74.8560],
  "59": [13.3409, 74.7421], "60": [13.0827, 80.2707], "62": [11.0168, 76.9558],
  "64": [10.7905, 78.7047], "67": [9.9312, 76.2673],  "68": [8.5241, 76.9366],
  "70": [22.5726, 88.3639], "71": [22.5726, 88.3639], "75": [20.2961, 85.8245],
  "78": [26.1445, 91.7362], "80": [25.5941, 85.1376], "82": [23.3441, 85.3096],
};
// Fallback: geographic centre of India
const DEFAULT_COORDS = [22.3511, 78.6677];

/** Approximates lat/long for an Indian PIN code. */
function pincodeToLatLng(pincode) {
  const pin = (pincode || "").toString().replace(/\D/g, "");
  if (pin.length >= 3 && PIN3_COORDS[pin.slice(0, 3)]) return PIN3_COORDS[pin.slice(0, 3)];
  if (pin.length >= 2 && PIN2_COORDS[pin.slice(0, 2)]) return PIN2_COORDS[pin.slice(0, 2)];
  return DEFAULT_COORDS;
}

/** Great-circle distance (km) between two lat/long points. */
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth radius in km
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Finds the nearest warehouse to a PIN code. */
function nearestWarehouse(pincode) {
  const [lat, lng] = pincodeToLatLng(pincode);
  let best = null;
  for (const wh of WAREHOUSES) {
    const km = haversineKm(lat, lng, wh.lat, wh.lng);
    if (!best || km < best.distanceKm) {
      best = { id: wh.id, city: wh.city, pincode: wh.pincode, distanceKm: km };
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Routing decision
// ---------------------------------------------------------------------------
const REASONABLE_DISTANCE_KM = 600;

/**
 * Combines sortingQueue + condition + value + distance into a recommended route
 * and a final disposition bucket. Returns { recommendedRoute, finalDisposition }.
 */
function decideRoute(r) {
  const condition = r.condition;
  const conditionScore = Number(r.conditionScore);
  const normalizedPrice = Number(r.normalizedPrice) || 0;
  const resaleValue = Number(r.estimatedResaleValue) || 0;
  const distanceKm = r.distanceKm;

  const isLikeNewOrGood = condition === "Like New" || condition === "Good";
  const resaleAtLeastHalf = normalizedPrice > 0 && resaleValue >= 0.5 * normalizedPrice;
  const veryLowValue = normalizedPrice > 0 && resaleValue < 0.15 * normalizedPrice;
  const distanceReasonable = distanceKm == null || distanceKm <= REASONABLE_DISTANCE_KM;

  // HARD RULE: Damaged items always go to Recycle — no resale pathway.
  if (condition === "Damaged") {
    return {
      recommendedRoute: "Recycle / parts harvesting at nearest warehouse",
      finalDisposition: "Recycle",
    };
  }

  // --- recommendedRoute ---
  let recommendedRoute;
  if (r.sortingQueue === "LOGISTICS_OPTIMIZATION_QUEUE") {
    // Returned Amazon order
    if (isLikeNewOrGood && resaleAtLeastHalf) {
      recommendedRoute = "Resell via Amazon (open box)";
    } else {
      recommendedRoute = "Send to nearest warehouse for refurbishment / liquidation";
    }
  } else if (r.sortingQueue === "CONSUMER_TRADE_IN_QUEUE") {
    // Unused at home
    if (isLikeNewOrGood) {
      recommendedRoute = "Consumer trade-in (gift card / credits)";
    } else if (condition === "Used" && distanceReasonable && !veryLowValue) {
      recommendedRoute = "Local marketplace / C2C resale via nearest warehouse";
    } else {
      // Used with very low value or unreasonable distance → Recycle
      recommendedRoute = "Recycle / parts harvesting at nearest warehouse";
    }
  } else {
    // Unknown queue — fall back on condition.
    recommendedRoute = isLikeNewOrGood
      ? "Resell via Amazon (open box)"
      : "Send to nearest warehouse for refurbishment / liquidation";
  }

  // --- finalDisposition (A+/B+ -> Resell, B/C -> Refurbish, D -> Recycle) ---
  let finalDisposition;
  if (condition === "Like New" || (condition === "Good" && conditionScore >= 0.8)) {
    finalDisposition = "Resell";
  } else if (condition === "Good" || (condition === "Used" && !veryLowValue && distanceReasonable)) {
    finalDisposition = "Refurbish";
  } else {
    // Used with very low value / bad distance, or any other case
    finalDisposition = "Recycle";
  }

  return { recommendedRoute, finalDisposition };
}

/**
 * Asks the Bedrock vision/text model for a one-sentence, human-friendly
 * explanation of why the chosen disposition is the best next life for the item.
 * Returns the sentence, or a sensible fallback on failure.
 */
async function explainRoute(r) {
  const money = (v) => (v == null ? "unknown" : `Rs.${Math.round(Number(v))}`);
  const promptText =
    `You are explaining a recommerce routing decision to a warehouse operator.\n` +
    `Product: ${r.productName || "item"} (category: ${r.category || "unknown"}).\n` +
    `Condition: ${r.condition || "unknown"} (score ${r.conditionScore ?? "n/a"}).\n` +
    `Fair like-new price: ${money(r.normalizedPrice)}; estimated resale value: ${money(r.estimatedResaleValue)}.\n` +
    `Distance to nearest warehouse: ${r.distanceKm == null ? "unknown" : r.distanceKm + " km"}.\n` +
    `Chosen disposition: ${r.finalDisposition}.\n\n` +
    `In ONE short sentence, explain why ${r.finalDisposition} is the best next life for this product, ` +
    `considering its condition, value, and distance. Respond with only the sentence, no preamble.`;

  const payload = {
    messages: [{ role: "user", content: [{ text: promptText }] }],
    inferenceConfig: { maxTokens: 120, temperature: 0.2, topP: 0.9 },
  };

  try {
    const resp = await bedrock.send(
      new InvokeModelCommand({
        modelId: MODEL_ID,
        contentType: "application/json",
        accept: "application/json",
        body: JSON.stringify(payload),
      })
    );
    const decoded = JSON.parse(Buffer.from(resp.body).toString("utf-8"));
    const text = (decoded?.output?.message?.content?.[0]?.text || "").trim();
    if (text) return text.replace(/^["']|["']$/g, "");
  } catch (e) {
    console.error(`Route explanation failed: ${e.message}`);
  }

  // Fallback if the model is unavailable
  return `${r.finalDisposition} is recommended based on the item's ${r.condition || "assessed"} condition and estimated resale value.`;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify(body),
  };
}

// ---------------------------------------------------------------------------
// handler — Lambda entry point
// ---------------------------------------------------------------------------
export const handler = async (event) => {
  let body;
  try {
    body = typeof event.body === "string" ? JSON.parse(event.body) : (event.body || event);
  } catch (e) {
    return response(400, { error: "Invalid JSON body." });
  }

  const evaluationId = body.evaluationId;
  if (!evaluationId || typeof evaluationId !== "string") {
    return response(400, { error: "evaluationId is required." });
  }

  // 1. Fetch the evaluation record
  let item;
  try {
    const result = await ddb.send(
      new GetCommand({ TableName: EVALUATIONS_TABLE, Key: { evaluationId } })
    );
    item = result.Item;
  } catch (e) {
    return response(500, { error: "Failed to read evaluation.", detail: e.message });
  }
  if (!item) {
    return response(404, { error: "Evaluation not found." });
  }

  // 2. Read the fields needed for the routing decision
  const routeInput = {
    evaluationId,
    sortingQueue: item.sortingQueue ?? null,
    priority: item.priority ?? null,
    condition: item.condition ?? null,
    conditionScore: item.conditionScore ?? null,
    normalizedPrice: item.normalizedPrice ?? null,
    estimatedResaleValue: item.estimatedResaleValue ?? null,
    pincode: item.currentPincode ?? null,
    category: item.category ?? null,
    productName: item.productName ?? null,
  };

  // 3. Compute the nearest warehouse + distance from the user's pincode
  const wh = nearestWarehouse(routeInput.pincode);
  routeInput.nearestWarehouseId = wh ? wh.id : null;
  routeInput.nearestWarehouseCity = wh ? wh.city : null;
  routeInput.distanceKm = wh ? Math.round(wh.distanceKm) : null;

  // 4. Decide the recommended route + final disposition
  const { recommendedRoute, finalDisposition } = decideRoute(routeInput);
  routeInput.recommendedRoute = recommendedRoute;
  routeInput.finalDisposition = finalDisposition;

  // 5. Ask the LLM for a human-friendly explanation
  const routeReason = await explainRoute(routeInput);
  routeInput.routeReason = routeReason;

  // 6. Persist the routing decision back to the evaluation record
  try {
    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression:
          "SET nearestWarehouseId = :w, distanceKm = :d, recommendedRoute = :rr, finalDisposition = :fd, routeReason = :rsn",
        ExpressionAttributeValues: {
          ":w": routeInput.nearestWarehouseId,
          ":d": routeInput.distanceKm,
          ":rr": recommendedRoute,
          ":fd": finalDisposition,
          ":rsn": routeReason,
        },
      })
    );
  } catch (e) {
    return response(500, { error: "Failed to save routing decision.", detail: e.message });
  }

  // 7. Respond with the routing decision
  return response(200, {
    evaluationId,
    recommendedRoute,
    finalDisposition,
    routeReason,
    distanceKm: routeInput.distanceKm,
    nearestWarehouseId: routeInput.nearestWarehouseId,
    sortingQueue: routeInput.sortingQueue,
    priority: routeInput.priority,
  });
};

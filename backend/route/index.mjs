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
import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";

// ---------------------------------------------------------------------------
// Configuration & shared clients
// ---------------------------------------------------------------------------
const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
// Best available model that works without the Anthropic use-case form.
// Switch to "global.anthropic.claude-opus-4-6-v1" once Anthropic access is
// granted in the Bedrock console.
const MODEL_ID = process.env.BEDROCK_MODEL_ID || "apac.amazon.nova-pro-v1:0";

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
// Routing decision — economics-based (net-profit) router
// ---------------------------------------------------------------------------
const REASONABLE_DISTANCE_KM = 600;

// A still-usable item (Used/Good) whose resale value is at or below this
// ceiling isn't worth the reverse-logistics cost of listing it, so the router
// recommends donating it to a local partner channel instead of squeezing a
// marginal resale profit. Kept in sync with kDonateResaleCeilingInr on the
// frontend (lib/data/route_helpers.dart).
const DONATE_RESALE_CEILING = 1000;

// A clean, valuable customer return is worth sending back to the origin/seller
// warehouse for restock/credit rather than reselling it locally. Any warehouse
// customer return in good condition whose resale value is at or above this
// floor is routed to ReturnToOrigin (still operator-overridable). Low-value
// returns fall through to the resell/donate/recycle ladder.
const RETURN_TO_ORIGIN_VALUE_FLOOR = Number(
  process.env.RETURN_TO_ORIGIN_VALUE_FLOOR || 3000
);

/**
 * Scores a single allowed route. Higher is better.
 *   routeScore = net-value score + condition + confidence + route fit - cost burden
 */
function scoreRoute({ netValue, conditionScore, confidence, routeFit, costBurden }) {
  const normalizedNetScore = Math.max(0, Math.min(netValue / 5000, 1));
  const costPenalty = Math.max(0, Math.min(costBurden, 1));
  return (
    normalizedNetScore * 0.45 +
    conditionScore * 0.25 +
    confidence * 0.15 +
    routeFit * 0.15 -
    costPenalty * 0.20
  );
}

/**
 * Eligibility decides which routes are allowed; scoring ranks the allowed
 * routes; net-value guardrails prevent uneconomical refurbishing.
 * Returns "Resell" | "Refurbish" | "Recycle".
 */
function decideRouteDynamic({
  condition,
  conditionScore,
  confidence = 1,
  normalizedPrice,
  estimatedResaleValue = 0,
  priceMultiplier,
  postRefurbMultiplier,
  repairable,
  refurbishmentNeeded, // none | cleaning | minor_repair | major_repair
  visibleIssues = [],
  pickupCost,
  qcCost,
  cleaningCost,
  listingCost,
  deliveryCost,
  platformRiskBuffer,
  repairCost,
  refurbHandlingCost,
  refurbRiskBuffer,
  sortingCost,
  recyclingTransportCost,
  recycleRecoveryValue,
  // Origin-return inputs (warehouse-only path).
  isWarehouseFlow = false,
  sourceType, // "customer_return" | "consumer_trade_in" | ...
  originWarehouseAvailable = false,
  sellerAcceptsReturn = false,
  originRecoveryValue = 0,
  originTransportCost = 0,
  localHandlingCost = 0,
  originRestockingFee = 0,
  delayRiskBuffer = 0,
  minimumProfitThreshold = 300,
}) {
  const asIsResaleValue = normalizedPrice * priceMultiplier;
  const postRefurbResaleValue = normalizedPrice * postRefurbMultiplier;

  const directResellCost =
    pickupCost + qcCost + cleaningCost + listingCost + deliveryCost + platformRiskBuffer;
  const refurbishCost =
    pickupCost + qcCost + repairCost + refurbHandlingCost + listingCost + deliveryCost + refurbRiskBuffer;
  const recycleCost = pickupCost + sortingCost + recyclingTransportCost;

  const directResellNet = asIsResaleValue - directResellCost;
  const refurbishNet = postRefurbResaleValue - refurbishCost;
  const recycleNet = recycleRecoveryValue - recycleCost;
  const valueUplift = postRefurbResaleValue - asIsResaleValue;

  const hasSevereDamage = condition === "Damaged" && repairable !== true;
  const hasDirectResaleBlockers = visibleIssues.some((issue) =>
    /crack|shatter|broken|torn|hole|missing|detached|exposed wiring|major dent|unsafe/i.test(issue)
  );

  // -------------------------------------------------------------------------
  // ReturnToOrigin (warehouse-only): a clean, VALUABLE customer return is worth
  // sending back to the origin/seller warehouse for restock/credit instead of
  // reselling it locally. Driven primarily by item value — high-value returns
  // go back to origin; low-value ones fall through to the resell/donate/recycle
  // ladder. Still guarded so we never return the item at a net loss.
  // -------------------------------------------------------------------------
  const originReturnNet =
    originRecoveryValue -
    originTransportCost -
    localHandlingCost -
    originRestockingFee -
    delayRiskBuffer;

  const returnValue =
    estimatedResaleValue > 0 ? estimatedResaleValue : asIsResaleValue;

  const returnToOriginEligible =
    isWarehouseFlow &&
    sourceType === "customer_return" &&
    originWarehouseAvailable === true &&
    sellerAcceptsReturn === true &&
    (condition === "Like New" || condition === "Good") &&
    conditionScore >= 0.7 &&
    confidence >= 0.65 &&
    refurbishmentNeeded !== "major_repair" &&
    !hasDirectResaleBlockers &&
    returnValue >= RETURN_TO_ORIGIN_VALUE_FLOOR &&
    originReturnNet >= 0;

  if (returnToOriginEligible) return "ReturnToOrigin";

  // -------------------------------------------------------------------------
  // Donate (circular-ladder option): a still-usable item (Used/Good) whose
  // resale value is too low to justify listing is better donated than resold
  // for a marginal profit. Checked before the resell/refurbish/recycle scoring
  // so donation is recommended automatically for these low-value items.
  // -------------------------------------------------------------------------
  const resaleForDonate =
    estimatedResaleValue > 0 ? estimatedResaleValue : asIsResaleValue;
  const donateEligible =
    (condition === "Used" || condition === "Good") &&
    conditionScore >= 0.45 &&
    !hasSevereDamage &&
    !hasDirectResaleBlockers &&
    resaleForDonate <= DONATE_RESALE_CEILING;

  if (donateEligible) return "Donate";

  const directEligible =
    !hasSevereDamage &&
    !hasDirectResaleBlockers &&
    conditionScore >= 0.45 &&
    directResellNet >= minimumProfitThreshold;

  const refurbishEligible =
    repairable === true &&
    refurbishmentNeeded !== "none" &&
    repairCost <= postRefurbResaleValue * 0.25 &&
    valueUplift >= refurbishCost * 1.2 &&
    refurbishNet >= minimumProfitThreshold;

  const recycleEligible = true;

  const directScore = directEligible
    ? scoreRoute({
        netValue: directResellNet,
        conditionScore,
        confidence,
        routeFit: condition === "Like New" || condition === "Good" ? 1 : 0.75,
        costBurden: directResellCost / Math.max(asIsResaleValue, 1),
      })
    : -Infinity;

  const refurbishScore = refurbishEligible
    ? scoreRoute({
        netValue: refurbishNet,
        conditionScore: Math.min(conditionScore + 0.2, 1),
        confidence,
        routeFit: refurbishmentNeeded === "minor_repair" ? 0.9 : 0.65,
        costBurden: refurbishCost / Math.max(postRefurbResaleValue, 1),
      })
    : -Infinity;

  const recycleScore = recycleEligible
    ? scoreRoute({
        netValue: recycleNet,
        conditionScore: condition === "Damaged" ? 0.8 : 0.35,
        confidence,
        routeFit: hasSevereDamage ? 1 : 0.4,
        costBurden: recycleCost / Math.max(recycleRecoveryValue, 1),
      })
    : -Infinity;

  // Refurbish must beat direct resale meaningfully.
  const refurbishBeatsDirect =
    refurbishScore > directScore && refurbishNet >= directResellNet * 1.15;

  if (refurbishEligible && refurbishBeatsDirect) return "Refurbish";
  if (directScore >= refurbishScore && directScore >= recycleScore) return "Resell";
  return "Recycle";
}

// ---------------------------------------------------------------------------
// Cost model + input assembler
// ---------------------------------------------------------------------------
// Realistic INR defaults for the reverse-logistics cost breakdown. Fixed costs
// are flat; pickup/delivery/recycle-transport scale with distance. Repair and
// risk buffers scale with the item's value. Tune these as real ops data lands.
const COST = {
  qcCost: 50,
  cleaningCost: 40,
  listingCost: 30,
  refurbHandlingCost: 60,
  sortingCost: 20,
  pickupBase: 80,
  pickupPerKm: 1.2,
  deliveryBase: 60,
  deliveryPerKm: 1.0,
  recycleTransportBase: 30,
  recycleTransportPerKm: 0.5,
  platformRiskRate: 0.05, // 5% of as-is resale value
  refurbRiskRate: 0.08,   // 8% of post-refurb resale value
  recycleRecoveryRate: 0.05, // scrap/parts value ~5% of normalized price
  // Origin-return economics (warehouse-only path).
  originRecoveryRate: 0.90,        // origin warehouse credits ~90% of like-new price for clean returns
  originTransportBase: 100,
  originTransportPerKm: 1.5,       // a bit more than local pickup — origin distance is uncertain
  originRestockingRate: 0.05,      // 5% of recovery value
  delayRiskRate: 0.05,             // 5% of recovery value (rejection/delay buffer)
};

// How much value a refurbished unit can recover (fraction of normalizedPrice),
// and what level of work each condition needs. `mult: null` means "no
// refurbishment is meaningful for this condition" (Like-New is already at
// peak value); the calculator falls back to priceMultiplier so the refurb
// path doesn't get spurious value uplift.
const REFURB_PROFILE = {
  "Like New": { mult: null, needed: "none", repairable: false },
  "Good":     { mult: 0.85, needed: "cleaning", repairable: true },
  "Used":     { mult: 0.75, needed: "minor_repair", repairable: true },
  "Damaged":  { mult: 0.6,  needed: "major_repair", repairable: null },
};

const STRUCTURAL_BLOCKER =
  /crack|shatter|broken|torn|hole|missing|detached|exposed wiring|major dent|unsafe/i;

/** Derives the full economic input set from an evaluation record. */
function buildEconomics(r) {
  const condition = r.condition || "Used";
  const conditionScore = Number(r.conditionScore);
  const confidence = r.conditionConfidence == null ? 1 : Number(r.conditionConfidence);
  const normalizedPrice = Number(r.normalizedPrice) || 0;
  const distanceKm = Number(r.distanceKm) || 0;
  const visibleIssues = Array.isArray(r.visibleIssues) ? r.visibleIssues : [];

  // As-is multiplier: prefer the stored priceMultiplier, else derive from resale value.
  let priceMultiplier = Number(r.priceMultiplier);
  if (Number.isNaN(priceMultiplier) || priceMultiplier <= 0) {
    const resale = Number(r.estimatedResaleValue) || 0;
    priceMultiplier = normalizedPrice > 0 ? resale / normalizedPrice : 0.5;
  }

  const profile = REFURB_PROFILE[condition] || REFURB_PROFILE["Used"];
  // For Like-New (mult=null) refurbishment is a no-op; keep postRefurb at the
  // current as-is multiplier so the refurb path doesn't inflate.
  const postRefurbMultiplier = profile.mult == null
      ? priceMultiplier
      : Math.max(profile.mult, priceMultiplier);

  // Damaged is repairable only when there are no structural blockers.
  const hasBlocker = visibleIssues.some((i) => STRUCTURAL_BLOCKER.test(String(i)));
  const repairable = condition === "Damaged" ? !hasBlocker : profile.repairable === true;
  const refurbishmentNeeded = profile.needed;

  // Repair cost scales with the work level and the item's value.
  const repairRate =
    refurbishmentNeeded === "major_repair" ? 0.18 :
    refurbishmentNeeded === "minor_repair" ? 0.08 :
    refurbishmentNeeded === "cleaning" ? 0.02 : 0;
  const repairCost = Math.round(normalizedPrice * repairRate);

  // -------------------------------------------------------------------------
  // ReturnToOrigin inputs (warehouse-only path)
  // -------------------------------------------------------------------------
  // The origin warehouse recovers the item at its ACTUAL condition value, not
  // a fraction of the like-new reference price. Using estimatedResaleValue as
  // the base means a genuinely Like-New item gets a high recovery value even
  // if normalizedPrice was underestimated by the LLM/catalog fallback.
  const asIsResaleValue = normalizedPrice * priceMultiplier;
  const originBaseValue = Math.max(asIsResaleValue, normalizedPrice * COST.originRecoveryRate);
  // A clean item (condition Like New / Good) commands a higher recovery rate
  // from origin since they can resell it themselves.
  const isHighQuality = condition === "Like New" || condition === "Good";
  const recoveryRate = isHighQuality ? COST.originRecoveryRate : COST.originRecoveryRate * 0.7;
  const originRecoveryValue = Math.round(asIsResaleValue * recoveryRate);

  const isWarehouseFlow = r.userRole === "warehouse";
  const sourceType =
    r.reason === "Returned Amazon order" || r.sortingQueue === "LOGISTICS_OPTIMIZATION_QUEUE"
      ? "customer_return"
      : "consumer_trade_in";
  const originWarehouseAvailable =
    !!r.nearestWarehouseId && r.nearestWarehouseId.length > 0;
  const sellerAcceptsReturn = true;

  const originTransportCost = Math.round(
    COST.originTransportBase + COST.originTransportPerKm * distanceKm
  );
  const localHandlingCost = COST.qcCost + COST.sortingCost;
  const originRestockingFee = Math.round(originRecoveryValue * COST.originRestockingRate);
  const delayRiskBuffer = Math.round(originRecoveryValue * COST.delayRiskRate);

  const postRefurbResaleValue = normalizedPrice * postRefurbMultiplier;

  return {
    condition,
    conditionScore: Number.isNaN(conditionScore) ? 0.5 : conditionScore,
    confidence: Number.isNaN(confidence) ? 1 : confidence,
    normalizedPrice,
    estimatedResaleValue: Number(r.estimatedResaleValue) || 0,
    priceMultiplier,
    postRefurbMultiplier,
    repairable,
    refurbishmentNeeded,
    visibleIssues,
    pickupCost: Math.round(COST.pickupBase + COST.pickupPerKm * distanceKm),
    qcCost: COST.qcCost,
    cleaningCost: COST.cleaningCost,
    listingCost: COST.listingCost,
    deliveryCost: Math.round(COST.deliveryBase + COST.deliveryPerKm * distanceKm),
    platformRiskBuffer: Math.round(asIsResaleValue * COST.platformRiskRate),
    repairCost,
    refurbHandlingCost: COST.refurbHandlingCost,
    refurbRiskBuffer: Math.round(postRefurbResaleValue * COST.refurbRiskRate),
    sortingCost: COST.sortingCost,
    recyclingTransportCost: Math.round(COST.recycleTransportBase + COST.recycleTransportPerKm * distanceKm),
    recycleRecoveryValue: Math.round(normalizedPrice * COST.recycleRecoveryRate),
    // Origin-return inputs
    isWarehouseFlow,
    sourceType,
    originWarehouseAvailable,
    sellerAcceptsReturn,
    originRecoveryValue,
    originTransportCost,
    localHandlingCost,
    originRestockingFee,
    delayRiskBuffer,
  };
}

/** Maps a final disposition + queue into the operator-facing route label. */
function recommendedRouteFor(disposition, sortingQueue) {
  if (disposition === "ReturnToOrigin") return "Return to origin warehouse";
  if (disposition === "Donate") return "Donate to local partner channel";
  if (disposition === "Recycle") return "Recycle / parts harvesting at nearest warehouse";
  if (disposition === "Refurbish") return "Send to nearest warehouse for refurbishment";
  // Resell
  if (sortingQueue === "LOGISTICS_OPTIMIZATION_QUEUE") return "Resell via Amazon (open box)";
  if (sortingQueue === "CONSUMER_TRADE_IN_QUEUE") return "List on local marketplace / consumer resale";
  return "Resell via Amazon (open box)";
}

/**
 * Entry point used by the handler. Keeps the { recommendedRoute,
 * finalDisposition } contract while delegating the decision to the
 * economics-based router.
 */
function decideRoute(r) {
  const economics = buildEconomics(r);
  const finalDisposition = decideRouteDynamic(economics);
  return {
    recommendedRoute: recommendedRouteFor(finalDisposition, r.sortingQueue),
    finalDisposition,
  };
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
    `The backend has already made the final routing decision using deterministic rules. ` +
    `You must NOT change, question, or override the chosen disposition. Only explain it clearly.\n\n` +
    `Product: ${r.productName || "item"} (category: ${r.category || "unknown"}).\n` +
    `Condition: ${r.condition || "unknown"} (score ${r.conditionScore ?? "n/a"}).\n` +
    `Fair like-new price: ${money(r.normalizedPrice)}.\n` +
    `Estimated resale value: ${money(r.estimatedResaleValue)}.\n` +
    `Distance to nearest warehouse: ${r.distanceKm == null ? "unknown" : r.distanceKm + " km"}.\n` +
    `Chosen disposition: ${r.finalDisposition}.\n\n` +
    `Write ONE short sentence explaining why ${r.finalDisposition} is appropriate, ` +
    `considering condition, resale value, and distance.\n` +
    `Rules:\n` +
    `- Do not mention a different route.\n` +
    `- Do not add uncertainty unless the inputs indicate uncertainty.\n` +
    `- Do not use markdown.\n` +
    `- Do not add preamble.\n` +
    `- Respond with only one sentence.`;

  try {
    const resp = await bedrock.send(
      new ConverseCommand({
        modelId: MODEL_ID,
        messages: [{ role: "user", content: [{ text: promptText }] }],
        inferenceConfig: { maxTokens: 120, temperature: 0.2, topP: 0.9 },
      })
    );
    const text = (resp?.output?.message?.content?.[0]?.text || "").trim();
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
    conditionConfidence: item.conditionConfidence ?? null,
    priceMultiplier: item.priceMultiplier ?? null,
    visibleIssues: Array.isArray(item.visibleIssues) ? item.visibleIssues : [],
    normalizedPrice: item.normalizedPrice ?? null,
    estimatedResaleValue: item.estimatedResaleValue ?? null,
    pincode: item.currentPincode ?? null,
    category: item.category ?? null,
    productName: item.productName ?? null,
    userRole: item.userRole ?? null,
    reason: item.reason ?? null,
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

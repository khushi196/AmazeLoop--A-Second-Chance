/**
 * /grade Lambda
 *
 * Receives an item grading request and routes it through the Evaluation Gateway,
 * which decides whether the user supplied an Order ID (ORD-xxx) or a numeric price.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand, QueryCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { randomUUID } from "crypto";

// ---------------------------------------------------------------------------
// Configuration & shared clients
// ---------------------------------------------------------------------------
const REGION = process.env.AWS_REGION || "ap-south-1";
const CATALOG_TABLE = process.env.CATALOG_TABLE || "ProductsCatalog";
const CATALOG_ORDER_INDEX = process.env.CATALOG_ORDER_INDEX || "orderId-index";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
// Best available multimodal model that works without the Anthropic use-case
// form. Switch to "global.anthropic.claude-opus-4-6-v1" once Anthropic access
// is granted in the Bedrock console.
const MODEL_ID = process.env.BEDROCK_MODEL_ID || "apac.amazon.nova-pro-v1:0";

const ddbClient = new DynamoDBClient({ region: REGION });
const ddb = DynamoDBDocumentClient.from(ddbClient);
const bedrock = new BedrockRuntimeClient({ region: REGION });
const s3 = new S3Client({ region: REGION });

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Standard JSON response helper.
 */
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

/**
 * Derives the sorting queue and priority from the return reason and mutates
 * the EvaluationInput in place.
 *
 *  - "Returned Amazon order" -> LOGISTICS_OPTIMIZATION_QUEUE / HIGH
 *  - "Unused at home"        -> CONSUMER_TRADE_IN_QUEUE / NORMAL
 *
 * @param {object} evaluationInput  must contain a `reason` field
 * @returns {object} the same object with sortingQueue + priority set
 */
function applySortingRules(evaluationInput) {
  const reason = evaluationInput.reason;

  if (reason === "Returned Amazon order") {
    evaluationInput.sortingQueue = "LOGISTICS_OPTIMIZATION_QUEUE";
    evaluationInput.priority = "HIGH";
  } else if (reason === "Unused at home") {
    evaluationInput.sortingQueue = "CONSUMER_TRADE_IN_QUEUE";
    evaluationInput.priority = "NORMAL";
  } else {
    // Unknown/absent reason — leave queue unassigned with a default priority.
    evaluationInput.sortingQueue = null;
    evaluationInput.priority = "NORMAL";
  }

  return evaluationInput;
}

// ---------------------------------------------------------------------------
// LLM price estimator (fallback when catalog has no matching items)
// ---------------------------------------------------------------------------

/** Parse S3 virtual-hosted URL into { Bucket, Name }. */
function parseS3Url(url) {
  if (!url) return null;
  try {
    const u = new URL(url);
    const vh = u.hostname.match(/^(.+)\.s3[.-][^.]*\.amazonaws\.com$/);
    if (vh) return { Bucket: vh[1], Name: decodeURIComponent(u.pathname.replace(/^\//, "")) };
  } catch (_) { return null; }
  return null;
}

/** Fetch the first photo from S3 and return { bytes, format } or null. */
async function fetchFirstPhoto(photoUrls) {
  if (!Array.isArray(photoUrls) || photoUrls.length === 0) return null;
  const ref = parseS3Url(photoUrls[0]);
  if (!ref) return null;
  try {
    const obj = await s3.send(new GetObjectCommand({ Bucket: ref.Bucket, Key: ref.Name }));
    const bytes = await obj.Body.transformToByteArray();
    const ext = ref.Name.toLowerCase();
    const format = ext.endsWith(".png") ? "png" : ext.endsWith(".webp") ? "webp" : "jpeg";
    return { bytes, format };
  } catch (e) {
    console.error(`Grade LLM: failed to fetch photo: ${e.message}`);
    return null;
  }
}

/**
 * Asks the vision LLM to estimate a fair like-new market price for a product.
 * When a photo is available it is passed to the model for visual identification.
 * Falls back to a text-only prompt if the photo cannot be loaded.
 */
async function estimatePriceWithLLM({ productName, category, reportedPrice, catalogSamples, photoUrls }) {
  const samplesText = catalogSamples.length > 0
    ? `Reference products from our catalog:\n` +
      catalogSamples.map(s => `- ${s.title} (${s.category}): Rs.${s.originalPrice}`).join("\n")
    : "No catalog reference products available.";

  // Load a photo first so the prompt can truthfully say whether one is present.
  const photo = await fetchFirstPhoto(photoUrls);

  const promptText =
    `You are a STRICT product pricing expert for an Indian recommerce resale platform. ` +
    `Your task is to estimate the fair LIKE-NEW reference price in INR for the exact product model or closest identifiable model. ` +
    `Do NOT grade condition. Do NOT decide routing.\n\n` +
    `${photo ? "Look at the product photo provided and use visual evidence to identify the product." : "No photo is available, so rely only on text and catalog references."}\n` +
    `Product name entered by user: "${productName || "unknown"}".\n` +
    `Category: "${category || "unknown"}".\n` +
    `User entered price: Rs.${reportedPrice}.\n\n` +
    `${samplesText}\n\n` +
    `STRICT MODEL-MATCHING RULES:\n` +
    `1. Price the exact or closest identifiable model, not the broad product type.\n` +
    `2. A broad category match is weak evidence. For example, do NOT price all shoes similarly: one shoe may be Rs.600 and another may be Rs.25,000.\n` +
    `3. Prefer evidence in this order:\n` +
    `   - exact same brand + model/series + variant/specs\n` +
    `   - same brand + close model/series/tier\n` +
    `   - same visible quality tier\n` +
    `   - broad category only as last resort\n` +
    `4. If the exact model is unclear, do NOT invent a premium model. Use a conservative estimate and lower confidence. ` +
    `However, if the user text clearly contains a well-known brand + model/series, such as "Dell XPS 13", "iPhone 13", "Sony WH-1000XM4", "Nike Air Force 1", or "Adidas Ultraboost", ` +
    `treat that as at least a "strong" model match even without a photo, unless the category or catalog evidence contradicts it. ` +
    `Do not downgrade a clear brand+model text match to "category_only" just because no photo is available.\n` +
    `5. User-entered price is weak evidence. Keep it only if it matches the identified model and realistic Indian market pricing.\n` +
    `6. Ignore catalog references that only share the category but differ in brand/model/tier.\n` +
    `7. Premium/luxury pricing is allowed only when brand/model evidence clearly supports it.\n\n` +
    `modelMatchLevel definitions:\n` +
    `- "exact": same brand + exact model/series + variant/specs are clearly known from photo, text, or catalog.\n` +
    `- "strong": brand + model/series are clearly known, but variant/specs/year/storage/size are uncertain.\n` +
    `- "partial": brand or product line is known, but exact model is uncertain.\n` +
    `- "category_only": only broad product type is known, such as "shoe", "laptop", "phone", or "bag".\n` +
    `- "unclear": product identity is too ambiguous to price reliably.\n\n` +
    `HARD PRICING GUARD: If modelMatchLevel is "exact" or "strong", price according to the realistic market tier for that model. ` +
    `Do not force a budget/category-average estimate merely because the input is text-only.\n\n` +
    `Indian pricing guidance:\n` +
    `- Budget footwear/clothing/accessories: usually Rs.300-3000.\n` +
    `- Mid-range branded items: usually Rs.3000-10000.\n` +
    `- Premium/special-edition items: usually Rs.10000-25000 only with strong model evidence.\n` +
    `- Electronics/appliances must be priced by exact model, generation, storage/specs, and tier.\n\n` +
    `Return ONLY valid JSON. No markdown. No extra text.\n` +
    `{"estimatedPrice": <integer in INR>,"identifiedProduct": "<brand + model/series + variant if known, or unclear>","modelMatchLevel": "<exact|strong|partial|category_only|unclear>","confidence": <0-1>,"reasoning": "<one sentence explaining the model evidence and why this like-new price is realistic>"}`;

  const content = [];
  if (photo) {
    content.push({ image: { format: photo.format, source: { bytes: photo.bytes } } });
  }
  content.push({ text: promptText });

  try {
    const resp = await bedrock.send(new ConverseCommand({
      modelId: MODEL_ID,
      messages: [{ role: "user", content }],
      inferenceConfig: { maxTokens: 250, temperature: 0.15, topP: 0.1 },
    }));
    const raw = resp?.output?.message?.content?.[0]?.text ?? "";
    const match = raw.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(match ? match[0] : raw);
    const price = Number(parsed.estimatedPrice);
    if (Number.isNaN(price) || price <= 0) return null;
    const identifiedProduct = (parsed.identifiedProduct || "").toString();
    const modelMatchLevel = (parsed.modelMatchLevel || "").toString();
    let confidence = Number(parsed.confidence);
    confidence = Number.isNaN(confidence) ? null : Math.max(0, Math.min(1, confidence));
    console.log(
      `LLM price estimate: Rs.${price} [match=${modelMatchLevel || "n/a"}, conf=${confidence ?? "n/a"}] ` +
      `${identifiedProduct || "unclear"} — ${parsed.reasoning || ""}`
    );
    return {
      estimatedPrice: Math.round(price / 10) * 10,
      reasoning: parsed.reasoning || "",
      identifiedProduct,
      modelMatchLevel,
      confidence,
    };
  } catch (e) {
    console.error(`LLM price estimation failed: ${e.message}`);
    return null;
  }
}

// ---------------------------------------------------------------------------
// saveEvaluationInput — persistence
// ---------------------------------------------------------------------------

/**
 * Persists an EvaluationInput to the Evaluations table.
 *
 * Generates an evaluationId (EVAL-<uuid>) and a createdAt timestamp, attaches them
 * to the object, writes it, and returns the enriched object.
 *
 * @param {object} evaluationInput
 * @returns {Promise<object>} the same object with evaluationId + createdAt set
 */
async function saveEvaluationInput(evaluationInput) {
  const evaluationId = `EVAL-${randomUUID()}`;
  const createdAt = new Date().toISOString();

  const item = {
    ...evaluationInput,
    evaluationId,
    createdAt,
  };

  // Drop undefined AND null values so DynamoDB GSIs (which require String keys) don't reject the item.
  const cleaned = {};
  for (const [key, value] of Object.entries(item)) {
    if (value !== undefined && value !== null) cleaned[key] = value;
  }

  await ddb.send(
    new PutCommand({
      TableName: EVALUATIONS_TABLE,
      Item: cleaned,
    })
  );

  return cleaned;
}

// ---------------------------------------------------------------------------
// evaluationGateway — routing decision (orderId vs price)
// ---------------------------------------------------------------------------

/**
 * Evaluation Gateway.
 *
 * Inspects `orderOrPrice` and decides how to handle the request:
 *  - Non-empty string starting with "ORD-"  -> treat as orderId  -> handleOrderIdCase
 *  - Otherwise parseable as a number         -> treat as price    -> handlePriceCase
 *  - Otherwise                               -> 400 validation error
 */
async function evaluationGateway(orderOrPrice, payload, authContext = {}) {
  const raw = typeof orderOrPrice === "string" ? orderOrPrice.trim() : orderOrPrice;

  // Case 1: Order ID
  if (typeof raw === "string" && raw.length > 0 && raw.startsWith("ORD-")) {
    return handleOrderIdCase(raw, payload, authContext);
  }

  // Case 2: Numeric price
  const reportedPrice = Number(raw);
  if (raw !== "" && raw !== null && raw !== undefined && !Number.isNaN(reportedPrice) && reportedPrice > 0) {
    return handlePriceCase(reportedPrice, payload, authContext);
  }
  // Case 3: Invalid input
  return response(400, {
    error: "Please enter a valid order ID (ORD-xxx) or a positive numeric price.",
  });
}

// ---------------------------------------------------------------------------
// handleOrderIdCase — catalog lookup path
// ---------------------------------------------------------------------------

/**
 * Handles requests where the user supplied an Order ID.
 *
 * Looks up the matching product in ProductsCatalog by orderId, extracts its
 * catalog attributes, and builds an EvaluationInput object for the caller.
 *
 * @param {string} orderId      e.g. "ORD-101"
 * @param {object} payload      full request body (category, reason, productName, currentPincode, ...)
 * @param {object} authContext  { userId, userRole }
 */
async function handleOrderIdCase(orderId, payload, authContext = {}) {
  // Look up the product by orderId using the dedicated GSI (efficient + correct).
  let item;
  try {
    const result = await ddb.send(
      new QueryCommand({
        TableName: CATALOG_TABLE,
        IndexName: CATALOG_ORDER_INDEX,
        KeyConditionExpression: "orderId = :oid",
        ExpressionAttributeValues: { ":oid": orderId },
        Limit: 1,
      })
    );
    item = result.Items && result.Items.length > 0 ? result.Items[0] : null;
  } catch (e) {
    return response(500, { error: "Failed to query catalog.", detail: e.message });
  }

  if (!item) {
    return response(404, { error: "Order ID not found in catalog" });
  }

  // Extract catalog attributes
  const originalPrice = item.originalPrice;
  const catalogCategory = item.category;
  const objectType = item.objectType;
  const brand = item.brand;
  const color = item.color;
  const warehouseLocation = item.warehouseLocation;

  // For the Order ID case, the catalog price is authoritative
  const reportedPrice = originalPrice;
  const normalizedPrice = originalPrice;

  // Build the EvaluationInput object returned to the caller
  const evaluationInput = {
    source: "orderId",
    orderId,
    productId: item.productId,
    // Pricing
    reportedPrice,
    normalizedPrice,
    originalPrice,
    avgPrice: null,
    currency: item.currency || "INR",
    // Catalog-derived attributes
    category: catalogCategory,
    objectType,
    brand,
    color,
    warehouseLocation,
    // User-supplied form fields (fall back to catalog where relevant)
    productName: payload.productName || item.title,
    userCategory: payload.category,
    reason: payload.reason,
    currentPincode: payload.currentPincode || payload.locationPincode,
    photoUrls: payload.photoUrls || payload.fileKeys || [],
    // Auth context
    userId: authContext.userId || null,
    userRole: authContext.userRole || null,
  };

  // Assign sorting queue + priority based on the return reason
  applySortingRules(evaluationInput);

  let saved;
  try {
    saved = await saveEvaluationInput(evaluationInput);
  } catch (e) {
    return response(500, { error: "Failed to save evaluation." });
  }
  return response(200, { evaluationInput: saved });
}

// ---------------------------------------------------------------------------
// handlePriceCase — price normalization path
// ---------------------------------------------------------------------------

/**
 * Handles requests where the user supplied a numeric price.
 *
 * Finds "similar" items in ProductsCatalog (same category + objectType, and same
 * brand when available), computes their average original price, and normalizes the
 * user's reported price against an 80%–120% band around that average.
 *
 * @param {number} reportedPrice  numeric price parsed from orderOrPrice
 * @param {object} payload        full request body (category, objectType, brand, ...)
 * @param {object} authContext    { userId, userRole }
 */
async function handlePriceCase(reportedPrice, payload, authContext = {}) {
  const category = payload.category;
  const objectType = payload.objectType;
  const brand = payload.brand;

  // Find similar catalog items. Build the filter only from fields that are
  // actually present, so we never reference an undefined expression value.
  let items = [];
  try {
    const filterParts = [];
    const values = {};
    const names = {};

    if (category) {
      filterParts.push("category = :cat");
      values[":cat"] = category;
    }
    if (objectType) {
      filterParts.push("objectType = :otype");
      values[":otype"] = objectType;
    }
    if (brand) {
      filterParts.push("brand = :brand");
      values[":brand"] = brand;
    }

    const scanParams = { TableName: CATALOG_TABLE };
    if (filterParts.length > 0) {
      scanParams.FilterExpression = filterParts.join(" AND ");
      scanParams.ExpressionAttributeValues = values;
      if (Object.keys(names).length > 0) scanParams.ExpressionAttributeNames = names;
    }

    const result = await ddb.send(new ScanCommand(scanParams));
    items = result.Items || [];
  } catch (e) {
    return response(500, { error: "Failed to query catalog.", detail: e.message });
  }

  let avgPrice = null;
  let normalizedPrice = reportedPrice;
  let similarCount = 0;

  if (items.length > 0) {
    // Narrow to items in a similar PRICE TIER as the reported price, so a
    // cheap item isn't averaged against premium ones in the same broad category.
    const PRICE_BAND_LOW = 0.5;   // 50% of reported
    const PRICE_BAND_HIGH = 2.0;  // 200% of reported
    const lowTier = reportedPrice * PRICE_BAND_LOW;
    const highTier = reportedPrice * PRICE_BAND_HIGH;

    let prices = items
      .map((it) => Number(it.originalPrice))
      .filter((p) => !Number.isNaN(p));

    const tierPrices = prices.filter((p) => p >= lowTier && p <= highTier);
    similarCount = tierPrices.length;

    if (tierPrices.length > 0) {
      // Enough comparable, similarly-priced items -> normalize against their average
      avgPrice = tierPrices.reduce((sum, p) => sum + p, 0) / tierPrices.length;

      const lowBound = 0.8 * avgPrice;
      const highBound = 1.2 * avgPrice;

      if (reportedPrice >= lowBound && reportedPrice <= highBound) {
        normalizedPrice = reportedPrice;
      } else {
        normalizedPrice = avgPrice;
      }
    } else {
      // No comparable items in this price tier -> use LLM to estimate a fair price.
      const samples = items
        .slice(0, 5)
        .map(it => ({ title: it.title || it.productName, category: it.category, originalPrice: Number(it.originalPrice) }))
        .filter(s => s.originalPrice > 0);

      const llmResult = await estimatePriceWithLLM({ productName: payload.productName, category, reportedPrice, catalogSamples: samples, photoUrls: payload.photoUrls });
      if (llmResult) {
        avgPrice = llmResult.estimatedPrice;
        normalizedPrice = llmResult.estimatedPrice;
        console.log(`LLM price estimate: Rs.${llmResult.estimatedPrice} — ${llmResult.reasoning}`);
      } else {
        // LLM also failed — trust the user's price as last resort.
        avgPrice = null;
        normalizedPrice = reportedPrice;
      }
    }
  }

  // Build the EvaluationInput object returned to the caller
  const evaluationInput = {
    source: "price",
    orderId: null,
    // Pricing
    reportedPrice,
    normalizedPrice,
    avgPrice,
    originalPrice: null,
    currency: payload.currency || "INR",
    similarItemCount: similarCount,
    // Attributes used for matching
    category,
    objectType,
    brand: brand || null,
    color: payload.color || null,
    // User-supplied form fields
    productName: payload.productName,
    userCategory: payload.category,
    reason: payload.reason,
    currentPincode: payload.currentPincode || payload.locationPincode,
    photoUrls: payload.photoUrls || payload.fileKeys || [],
    // Auth context
    userId: authContext.userId || null,
    userRole: authContext.userRole || null,
  };

  // Assign sorting queue + priority based on the return reason
  applySortingRules(evaluationInput);

  let saved;
  try {
    saved = await saveEvaluationInput(evaluationInput);
  } catch (e) {
    return response(500, { error: "Failed to save evaluation." });
  }
  return response(200, { evaluationInput: saved });
}

// ---------------------------------------------------------------------------
// handler — Lambda entry point
// ---------------------------------------------------------------------------

/**
 * Lambda entry point.
 */
export const handler = async (event) => {
  let body;
  try {
    body = typeof event.body === "string" ? JSON.parse(event.body) : (event.body || event);
  } catch (e) {
    return response(400, { error: "Invalid JSON body." });
  }

  // Identity comes from the Cognito JWT authorizer claims (server-trusted),
  // never the request body. Seller routes are JWT-gated at API Gateway.
  const claims =
    event?.requestContext?.authorizer?.jwt?.claims ||
    event?.requestContext?.authorizer?.claims ||
    {};
  const callerId = claims.sub;
  const callerRole = claims["custom:role"];
  if (!callerId) return response(401, { error: "Authentication required." });
  if (callerRole !== "customer" && callerRole !== "warehouse") {
    return response(403, { error: "Not authorized for seller actions." });
  }
  const authContext = { userId: callerId, userRole: callerRole };

  const orderOrPrice = body.orderOrPrice;

  // Require at least one photo — grading cannot proceed without one.
  const photos = Array.isArray(body.photoUrls) ? body.photoUrls.filter((u) => typeof u === "string" && u.trim() !== "") : [];
  if (photos.length === 0) {
    return response(400, { error: "Please upload at least one photo before grading." });
  }

  return evaluationGateway(orderOrPrice, body, authContext);
};

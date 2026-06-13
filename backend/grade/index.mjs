/**
 * /grade Lambda
 *
 * Receives an item grading request and routes it through the Evaluation Gateway,
 * which decides whether the user supplied an Order ID (ORD-xxx) or a numeric price.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand, QueryCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

// ---------------------------------------------------------------------------
// Configuration & shared clients
// ---------------------------------------------------------------------------
const REGION = process.env.AWS_REGION || "ap-south-1";
const CATALOG_TABLE = process.env.CATALOG_TABLE || "ProductsCatalog";
const CATALOG_ORDER_INDEX = process.env.CATALOG_ORDER_INDEX || "orderId-index";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";

const ddbClient = new DynamoDBClient({ region: REGION });
const ddb = DynamoDBDocumentClient.from(ddbClient);

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

  // Drop undefined values so DynamoDB accepts the item cleanly.
  const cleaned = {};
  for (const [key, value] of Object.entries(item)) {
    if (value !== undefined) cleaned[key] = value;
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
  if (raw !== "" && raw !== null && raw !== undefined && !Number.isNaN(reportedPrice)) {
    return handlePriceCase(reportedPrice, payload, authContext);
  }

  // Case 3: Invalid input
  return response(400, {
    error: "Please enter a valid order ID (ORD-xxx) or numeric price.",
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

  const saved = await saveEvaluationInput(evaluationInput);
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
      // No comparable items in this price tier -> trust the user's entered price.
      avgPrice = null;
      normalizedPrice = reportedPrice;
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

  const saved = await saveEvaluationInput(evaluationInput);
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

  // Extract auth context (from API Gateway Cognito authorizer claims, with body fallback)
  const claims = event.requestContext?.authorizer?.claims || {};
  const authContext = {
    userId: claims.sub || body.userId || null,
    userRole: claims["custom:role"] || body.userRole || null,
  };

  const orderOrPrice = body.orderOrPrice;

  // Require at least one photo — grading cannot proceed without one.
  const photos = Array.isArray(body.photoUrls) ? body.photoUrls.filter((u) => typeof u === "string" && u.trim() !== "") : [];
  if (photos.length === 0) {
    return response(400, { error: "Please upload at least one photo before grading." });
  }

  return evaluationGateway(orderOrPrice, body, authContext);
};

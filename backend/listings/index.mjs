/**
 * AmazeLoopListingsFunction  (GET /listings)
 *
 * Returns all evaluations that are publicly listable on the buyer-side
 * marketplace. An evaluation is considered "listed" when:
 *   - status === "ROUTED" (the user/operator has confirmed a disposition), AND
 *   - the effective disposition (chosenDisposition || finalDisposition) is "Resell".
 *
 * Each item is projected into a buyer-friendly listing shape — the buyer app
 * does not need to know about evaluation internals.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand } from "@aws-sdk/lib-dynamodb";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

// ---------------------------------------------------------------------------
// CORS-aware response helper
// ---------------------------------------------------------------------------
function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "*",
      "Access-Control-Allow-Methods": "GET,OPTIONS",
    },
    body: JSON.stringify(body),
  };
}

// ---------------------------------------------------------------------------
// Listing shape derivation
// ---------------------------------------------------------------------------

/** Picks the best photo URL using bestPhotoIndex, falling back to the first. */
function coverImage(item) {
  const urls = Array.isArray(item.photoUrls) ? item.photoUrls : [];
  if (urls.length === 0) return null;
  const idx = Number.isInteger(item.bestPhotoIndex) ? item.bestPhotoIndex : 0;
  if (idx >= 0 && idx < urls.length) return urls[idx];
  return urls[0];
}

/** Maps return reason + condition into a coarse buyer risk band. */
function riskBand(reason, condition) {
  // Reason-derived risk
  let reasonRisk = "MEDIUM";
  if (reason === "Unused at home") reasonRisk = "LOW";
  else if (reason === "Returned Amazon order") reasonRisk = "MEDIUM";

  // Condition-derived risk
  let conditionRisk = "MEDIUM";
  if (condition === "Like New") conditionRisk = "LOW";
  else if (condition === "Good") conditionRisk = "LOW";
  else if (condition === "Used") conditionRisk = "MEDIUM";
  else if (condition === "Damaged") conditionRisk = "HIGH";

  // Take the worse of the two so buyers see the more conservative signal.
  const order = { LOW: 0, MEDIUM: 1, HIGH: 2 };
  return order[reasonRisk] >= order[conditionRisk] ? reasonRisk : conditionRisk;
}

/** Determines whether a record should appear on the marketplace. */
export function isListable(item) {
  if (item.status !== "ROUTED") return false;
  const effective = item.chosenDisposition || item.finalDisposition;
  if (effective !== "Resell") return false;

  // Seller has pulled it from the marketplace → never listable.
  if (item.marketplaceStatus === "withdrawn") return false;

  // No buyer at all → listable.
  if (!item.buyerUserId) return true;

  // SOLD items never come back.
  if (item.purchaseStatus === "SOLD") return false;

  // RESERVED: only hide while the hold is still active. Expired holds are
  // treated as available again (the sweep Lambda also resets them, but this
  // keeps the marketplace correct even between sweeps).
  if (item.purchaseStatus === "RESERVED") {
    if (item.reservationExpiresAt &&
        new Date(item.reservationExpiresAt) < new Date()) {
      return true;
    }
    return false;
  }

  return false;
}

/** Projects an Evaluation row into the buyer-facing listing shape. */
function toListing(item) {
  const price =
    Number(item.estimatedResaleValue) > 0
      ? Number(item.estimatedResaleValue)
      : Number(item.normalizedPrice) || 0;

  return {
    listingId: item.evaluationId,
    evaluationId: item.evaluationId,
    title: item.productName || "Refurbished item",
    category: item.category || null,
    price,
    currency: item.currency || "INR",
    condition: item.condition || null,
    conditionScore: item.conditionScore ?? null,
    coverImage: coverImage(item),
    photoUrls: Array.isArray(item.photoUrls) ? item.photoUrls : [],
    sellerType: item.userRole === "warehouse" ? "WAREHOUSE" : "CUSTOMER",
    risk: riskBand(item.reason, item.condition),
    topReturnReason: item.reason || null,
    nearestWarehouseId: item.nearestWarehouseId || null,
    createdAt: item.createdAt || null,
  };
}

// ---------------------------------------------------------------------------
// handler
// ---------------------------------------------------------------------------
export const handler = async (event) => {
  // Handle the CORS preflight cleanly even if API Gateway forwards OPTIONS.
  if (event?.requestContext?.http?.method === "OPTIONS" || event?.httpMethod === "OPTIONS") {
    return response(204, {});
  }

  const params = event?.queryStringParameters || {};
  const limit = Math.min(Number(params.limit) || 50, 100);
  const offset = Math.max(Number(params.offset) || 0, 0);

  let items = [];
  try {
    // Hackathon dataset is small — a Scan is fine. Once volume grows, switch
    // to a `status-createdAt-index` GSI and Query by status === "ROUTED".
    const result = await ddb.send(
      new ScanCommand({
        TableName: EVALUATIONS_TABLE,
        FilterExpression: "#s = :routed",
        ExpressionAttributeNames: { "#s": "status" },
        ExpressionAttributeValues: { ":routed": "ROUTED" },
      })
    );
    items = result.Items || [];
  } catch (e) {
    return response(500, { error: "Failed to read evaluations.", detail: e.message });
  }

  // Build the full ordered set of listable items, then return one page.
  // Simple offset pagination keeps the createdAt-desc ordering correct across
  // pages (a raw DynamoDB cursor wouldn't, because we sort after scanning).
  const allListable = items
    .filter(isListable)
    .sort((a, b) => (b.createdAt || "").localeCompare(a.createdAt || ""));

  const page = allListable.slice(offset, offset + limit).map(toListing);
  const nextOffset = offset + limit;
  const hasMore = nextOffset < allListable.length;

  return response(200, {
    listings: page,
    total: allListable.length,
    offset,
    nextOffset: hasMore ? nextOffset : null,
    hasMore,
  });
};

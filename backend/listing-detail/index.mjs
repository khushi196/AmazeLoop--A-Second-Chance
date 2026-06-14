/**
 * AmazeLoopListingDetailFunction  (GET /listings/{id})
 *
 * Fetches a single Evaluation by id and returns the buyer-facing detail
 * payload — the same fields as /listings plus a Health Card block.
 *
 * The Health Card carries the buyer-trust signals: condition, score, the
 * one-sentence AI rationale, the routing explanation, plus a few
 * reassurance fields (warranty, owners, circular impact). Fields that are
 * not yet sourced from the backend pipeline are returned with sensible
 * placeholders and are clearly marked in the code below.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";

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
// Listing shape (mirrors /listings; kept intentionally identical)
// ---------------------------------------------------------------------------

function coverImage(item) {
  const urls = Array.isArray(item.photoUrls) ? item.photoUrls : [];
  if (urls.length === 0) return null;
  const idx = Number.isInteger(item.bestPhotoIndex) ? item.bestPhotoIndex : 0;
  if (idx >= 0 && idx < urls.length) return urls[idx];
  return urls[0];
}

function riskBand(reason, condition) {
  let reasonRisk = "MEDIUM";
  if (reason === "Unused at home") reasonRisk = "LOW";
  else if (reason === "Returned Amazon order") reasonRisk = "MEDIUM";

  let conditionRisk = "MEDIUM";
  if (condition === "Like New" || condition === "Good") conditionRisk = "LOW";
  else if (condition === "Used") conditionRisk = "MEDIUM";
  else if (condition === "Damaged") conditionRisk = "HIGH";

  const order = { LOW: 0, MEDIUM: 1, HIGH: 2 };
  return order[reasonRisk] >= order[conditionRisk] ? reasonRisk : conditionRisk;
}

function isListable(item) {
  if (item.status !== "ROUTED") return false;
  const effective = item.chosenDisposition || item.finalDisposition;
  return effective === "Resell";
}

function buildListingFields(item) {
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
    sellerType: item.userRole === "warehouse" ? "WAREHOUSE" : "CUSTOMER",
    risk: riskBand(item.reason, item.condition),
    topReturnReason: item.reason || null,
    nearestWarehouseId: item.nearestWarehouseId || null,
    createdAt: item.createdAt || null,
  };
}

// ---------------------------------------------------------------------------
// Health Card derivation
// ---------------------------------------------------------------------------

/**
 * Splits the AI's one-sentence conditionReason into a small list of issues.
 * We split on common separators (semicolons, " and ", periods between phrases)
 * and trim each fragment. If nothing splits, we return the whole sentence as
 * a single-item list. Returns [] if the reason is missing.
 */
function deriveIssues(conditionReason) {
  if (!conditionReason || typeof conditionReason !== "string") return [];
  const parts = conditionReason
    .split(/;|\s\band\b\s|\.\s+(?=[A-Z])/i)
    .map((s) => s.trim().replace(/[.;,]+$/, ""))
    .filter((s) => s.length > 0 && s.length < 160);
  return parts.length > 0 ? parts : [conditionReason.trim()];
}

/**
 * Estimates the manufacturing carbon-footprint avoided (kg CO2e) by reusing
 * the item rather than producing a new one. Coarse, category-keyed lookup —
 * good enough for the buyer card and clearly approximate.
 */
export function circularImpactKg(category) {
  const c = (category || "").toLowerCase();
  if (c.includes("phone") || c.includes("mobile")) return 55;
  if (c.includes("laptop") || c.includes("computer")) return 320;
  if (c.includes("tablet")) return 90;
  if (c.includes("watch") || c.includes("wearable")) return 20;
  if (c.includes("tv") || c.includes("television")) return 380;
  if (c.includes("appliance") || c.includes("kitchen")) return 80;
  if (c.includes("shoe") || c.includes("apparel") || c.includes("clothing")) return 8;
  return 25; // generic fallback
}

// ---------------------------------------------------------------------------
// Reverse-logistics estimates (transparent approximations, not measured)
// ---------------------------------------------------------------------------
// Reselling an item locally avoids shipping it back along its inbound leg to
// the origin/returns hub. We approximate the avoided distance as the measured
// distance to the nearest warehouse plus a constant origin-hub segment, and
// convert km to CO2e using a small-parcel road-freight factor.
const REVERSE_HUB_CONSTANT_KM = 150;  // origin warehouse -> manufacturer/returns hub
const FREIGHT_CO2_KG_PER_KM = 0.12;   // ~kg CO2e per km for a small parcel by road

/** Estimated reverse-shipping distance (km) avoided by reselling locally. */
export function reverseShippingAvoidedKm(distanceKm) {
  const d = Number(distanceKm) || 0;
  return Math.round(d + REVERSE_HUB_CONSTANT_KM);
}

/** Estimated transport CO2e (kg) saved by avoiding that reverse leg. */
export function transportCo2SavedKg(distanceKm) {
  const km = reverseShippingAvoidedKm(distanceKm);
  return Math.round(km * FREIGHT_CO2_KG_PER_KM * 10) / 10;
}

function buildHealthCard(item) {
  // Prefer the structured visibleIssues array from AI grading; fall back to
  // splitting the one-sentence conditionReason for older records.
  const issues = Array.isArray(item.visibleIssues) && item.visibleIssues.length > 0
    ? item.visibleIssues.map((s) => String(s).trim()).filter((s) => s.length > 0)
    : deriveIssues(item.conditionReason);

  const distanceKm = Number(item.distanceKm) || 0;
  // owners = the original owner (1) plus one per completed marketplace resale.
  const owners = 1 + (Number(item.resaleCount) || 0);

  return {
    condition: item.condition || null,
    conditionScore: item.conditionScore ?? null,
    conditionConfidence: item.conditionConfidence ?? null,
    issues,
    conditionReason: item.conditionReason || null,
    routeReason: item.routeReason || null,
    finalDisposition: item.chosenDisposition || item.finalDisposition || null,
    // Warranty is not sourced from a warranty registry yet, so we report it
    // honestly as "no warranty" rather than fabricating a number.
    warrantyMonthsRemaining: 0,
    // Owners is now a real counter, incremented on each marketplace BUY.
    owners,
    // Manufacturing CO2e avoided by reuse (coarse, category-keyed estimate).
    circularImpactKg: circularImpactKg(item.category),
    // Reverse-logistics estimates derived from the routing distance. Both are
    // transparent approximations and are labelled as such on the buyer card.
    reverseShippingAvoidedKm: reverseShippingAvoidedKm(distanceKm),
    co2SavedKg: transportCo2SavedKg(distanceKm),
  };
}

// ---------------------------------------------------------------------------
// handler
// ---------------------------------------------------------------------------
export const handler = async (event) => {
  if (
    event?.requestContext?.http?.method === "OPTIONS" ||
    event?.httpMethod === "OPTIONS"
  ) {
    return response(204, {});
  }

  const id =
    event?.pathParameters?.id ||
    event?.pathParameters?.listingId ||
    event?.queryStringParameters?.id;
  if (!id || typeof id !== "string") {
    return response(400, { error: "listingId path parameter is required." });
  }

  let item;
  try {
    const result = await ddb.send(
      new GetCommand({ TableName: EVALUATIONS_TABLE, Key: { evaluationId: id } })
    );
    item = result.Item;
  } catch (e) {
    return response(500, { error: "Failed to read evaluation.", detail: e.message });
  }

  if (!item) {
    return response(404, { error: "Listing not found." });
  }
  if (!isListable(item)) {
    // Don't leak unrouted/unlisted items to the buyer side.
    return response(404, { error: "Listing not available." });
  }

  const detail = {
    ...buildListingFields(item),
    images: Array.isArray(item.photoUrls) ? item.photoUrls : [],
    healthCard: buildHealthCard(item),
  };

  return response(200, detail);
};

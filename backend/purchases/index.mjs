/**
 * AmazeLoopMyPurchasesFunction  (GET /purchases)
 *
 * Returns the list of items the authenticated buyer has reserved or bought.
 * Identity is taken from the Cognito authorizer claims so a buyer can never
 * see another buyer's purchases.
 *
 * Today we Scan the Evaluations table with a filter on buyerUserId — fine
 * for the hackathon dataset. Once volume grows, add a GSI:
 *   buyerUserId-purchaseTimestamp-index   (PK: buyerUserId, SK: purchaseTimestamp)
 * and switch this to a Query for O(log n) lookups per buyer.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  ScanCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
// Optional: set this env var on the Lambda once a buyer GSI exists.
const BUYER_INDEX = process.env.BUYER_INDEX || "";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

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

/** Picks the best photo URL using bestPhotoIndex, falling back to the first. */
function coverImage(item) {
  const urls = Array.isArray(item.photoUrls) ? item.photoUrls : [];
  if (urls.length === 0) return null;
  const idx = Number.isInteger(item.bestPhotoIndex) ? item.bestPhotoIndex : 0;
  if (idx >= 0 && idx < urls.length) return urls[idx];
  return urls[0];
}

/** Projects an Evaluation row into the buyer-side purchase shape. */
function toPurchase(item) {
  const price =
    Number(item.estimatedResaleValue) > 0
      ? Number(item.estimatedResaleValue)
      : Number(item.normalizedPrice) || 0;

  return {
    evaluationId: item.evaluationId,
    title: item.productName || "Refurbished item",
    price,
    currency: item.currency || "INR",
    condition: item.condition || null,
    coverImage: coverImage(item),
    purchaseStatus: item.purchaseStatus || "RESERVED",
    purchaseTimestamp: item.purchaseTimestamp || null,
    reservationExpiresAt: item.reservationExpiresAt || null,
  };
}

export const handler = async (event) => {
  if (
    event?.requestContext?.http?.method === "OPTIONS" ||
    event?.httpMethod === "OPTIONS"
  ) {
    return response(204, {});
  }

  // Pull buyerUserId from Cognito claims (REST or HTTP API shapes).
  const restClaims = event?.requestContext?.authorizer?.claims;
  const httpClaims = event?.requestContext?.authorizer?.jwt?.claims;
  const claims = restClaims || httpClaims || {};
  // Fallback to query param only when no authorizer is configured (local/dev).
  const buyerUserId =
    claims.sub || event?.queryStringParameters?.buyerUserId;

  if (!buyerUserId) {
    return response(401, {
      error: "Missing buyer identity. Authentication required.",
    });
  }

  const limit = Math.min(
    Number(event?.queryStringParameters?.limit) || 50,
    100
  );

  // Optional status filter: SOLD (My Purchases) or RESERVED (Reserved tab).
  const statusFilter = (event?.queryStringParameters?.status || "")
    .toUpperCase();

  let items = [];
  try {
    if (BUYER_INDEX) {
      // Fast path: buyerUserId GSI exists, sorted by purchaseTimestamp desc.
      const result = await ddb.send(
        new QueryCommand({
          TableName: EVALUATIONS_TABLE,
          IndexName: BUYER_INDEX,
          KeyConditionExpression: "buyerUserId = :b",
          ExpressionAttributeValues: { ":b": buyerUserId },
          ScanIndexForward: false,
          Limit: limit,
        })
      );
      items = result.Items || [];
    } else {
      // Hackathon path: Scan with a filter expression.
      const result = await ddb.send(
        new ScanCommand({
          TableName: EVALUATIONS_TABLE,
          FilterExpression: "buyerUserId = :b",
          ExpressionAttributeValues: { ":b": buyerUserId },
        })
      );
      items = result.Items || [];
    }
  } catch (e) {
    return response(500, {
      error: "Failed to load purchases.",
      detail: e.message,
    });
  }

  const nowIso = new Date().toISOString();

  const purchases = items
    .filter((it) => {
      if (!statusFilter) return true;
      if (it.purchaseStatus !== statusFilter) return false;
      // For RESERVED, hide holds that have already expired — the sweep will
      // release them back to the marketplace.
      if (
        statusFilter === "RESERVED" &&
        it.reservationExpiresAt &&
        it.reservationExpiresAt < nowIso
      ) {
        return false;
      }
      return true;
    })
    .sort((a, b) =>
      (b.purchaseTimestamp || "").localeCompare(a.purchaseTimestamp || "")
    )
    .slice(0, limit)
    .map(toPurchase);

  return response(200, { purchases });
};

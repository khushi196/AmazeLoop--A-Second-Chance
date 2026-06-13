/**
 * AmazeLoopPurchaseFunction  (POST /purchase)
 *
 * Buyer-side reservation/purchase flow. Marks an evaluation as reserved by
 * the authenticated buyer so it disappears from the marketplace and
 * appears in that buyer's "My Purchases" list.
 *
 * Identity is taken from the Cognito authorizer claims (sub) so the buyer
 * cannot impersonate another user via the request body. Falls back to a
 * `buyerUserId` body field only when no authorizer is attached, which
 * keeps local testing simple but should be removed once the authorizer
 * is enforced in production.
 *
 * Concurrency safety: the UpdateItem uses a conditional expression so
 * two buyers tapping "Buy" simultaneously can't both win — the second
 * write fails with ConditionalCheckFailedException and we return 409.
 *
 * Request:  { "evaluationId": "EVAL-..." }
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "*",
      "Access-Control-Allow-Methods": "POST,OPTIONS",
    },
    body: JSON.stringify(body),
  };
}

export const handler = async (event) => {
  // CORS preflight (in case API Gateway forwards OPTIONS to the integration)
  if (
    event?.requestContext?.http?.method === "OPTIONS" ||
    event?.httpMethod === "OPTIONS"
  ) {
    return response(204, {});
  }

  // Parse body
  let body;
  try {
    body =
      typeof event.body === "string"
        ? JSON.parse(event.body)
        : event.body || event;
  } catch (e) {
    return response(400, { error: "Invalid JSON body." });
  }

  const evaluationId = body.evaluationId;
  if (!evaluationId || typeof evaluationId !== "string") {
    return response(400, { error: "evaluationId is required." });
  }

  // Pull buyerUserId from the Cognito authorizer (REST or HTTP API shapes),
  // falling back to the request body only when no authorizer is configured.
  const restClaims = event?.requestContext?.authorizer?.claims;
  const httpClaims = event?.requestContext?.authorizer?.jwt?.claims;
  const claims = restClaims || httpClaims || {};
  const buyerUserId = claims.sub || body.buyerUserId;

  if (!buyerUserId) {
    return response(401, { error: "Missing buyer identity. Authentication required." });
  }

  // 1. Fetch the evaluation so we can validate it's actually purchasable
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

  // 2. Validation rules
  const effectiveDisposition = item.chosenDisposition || item.finalDisposition;
  if (item.status !== "ROUTED" || effectiveDisposition !== "Resell") {
    return response(400, { error: "This item is not available for purchase." });
  }
  if (item.buyerUserId) {
    if (item.buyerUserId === buyerUserId) {
      // Idempotent: same buyer re-tapping returns the existing reservation.
      return response(200, {
        evaluationId,
        buyerUserId,
        purchaseStatus: item.purchaseStatus || "RESERVED",
        purchaseTimestamp: item.purchaseTimestamp || null,
        alreadyReserved: true,
      });
    }
    return response(409, { error: "This item has already been reserved." });
  }

  // 3. Conditional update — only succeed if no other buyer has claimed it.
  const purchaseTimestamp = new Date().toISOString();
  try {
    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression:
          "SET buyerUserId = :b, purchaseStatus = :ps, purchaseTimestamp = :t",
        ConditionExpression: "attribute_not_exists(buyerUserId)",
        ExpressionAttributeValues: {
          ":b": buyerUserId,
          ":ps": "RESERVED",
          ":t": purchaseTimestamp,
        },
      })
    );
  } catch (e) {
    if (e.name === "ConditionalCheckFailedException") {
      return response(409, { error: "This item has just been reserved by another buyer." });
    }
    return response(500, { error: "Failed to reserve item.", detail: e.message });
  }

  return response(200, {
    evaluationId,
    buyerUserId,
    purchaseStatus: "RESERVED",
    purchaseTimestamp,
  });
};

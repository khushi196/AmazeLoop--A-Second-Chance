/**
 * AmazeLoopEvaluationsListFunction  (GET /evaluations?userId=...&limit=20)
 *
 * Returns the most recent evaluations for a userId (sorted by createdAt desc).
 * Supports optional warehouseId parameter for warehouse/seller views.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand, ScanCommand } from "@aws-sdk/lib-dynamodb";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
const USER_INDEX = "userId-createdAt-index";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

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

export const handler = async (event) => {
  const params = event.queryStringParameters || {};
  const warehouseId = params.warehouseId;
  const limit = Math.min(Number(params.limit) || 20, 50);

  // Prefer userId from Cognito authorizer claims if present (prevents IDOR),
  // otherwise fall back to the query param (API Gateway has no authorizer yet).
  const claims = event.requestContext?.authorizer?.claims || {};
  const userId = claims.sub || params.userId;

  if (!userId && !warehouseId) {
    return response(400, { error: "userId or warehouseId query parameter is required." });
  }

  let items = [];

  if (userId) {
    // Query via the userId GSI, sorted by createdAt descending
    try {
      const result = await ddb.send(
        new QueryCommand({
          TableName: EVALUATIONS_TABLE,
          IndexName: USER_INDEX,
          KeyConditionExpression: "userId = :uid",
          ExpressionAttributeValues: { ":uid": userId },
          ScanIndexForward: false, // newest first
          Limit: limit,
        })
      );
      items = result.Items || [];
    } catch (e) {
      return response(500, { error: "Failed to query evaluations.", detail: e.message });
    }
  } else if (warehouseId) {
    // Warehouse view: scan with filter (no GSI on warehouse yet)
    try {
      const result = await ddb.send(
        new ScanCommand({
          TableName: EVALUATIONS_TABLE,
          FilterExpression: "nearestWarehouseId = :wid",
          ExpressionAttributeValues: { ":wid": warehouseId },
        })
      );
      items = (result.Items || [])
        .sort((a, b) => (b.createdAt || "").localeCompare(a.createdAt || ""))
        .slice(0, limit);
    } catch (e) {
      return response(500, { error: "Failed to query evaluations.", detail: e.message });
    }
  }

  // Project the fields the frontend needs
  const evaluations = items.map((it) => ({
    evaluationId: it.evaluationId,
    createdAt: it.createdAt,
    productName: it.productName,
    category: it.category,
    condition: it.condition,
    conditionReason: it.conditionReason,
    finalDisposition: it.finalDisposition,
    chosenDisposition: it.chosenDisposition,
    recommendedRoute: it.recommendedRoute,
    estimatedResaleValue: it.estimatedResaleValue,
    nearestWarehouseId: it.nearestWarehouseId,
    status: it.status,
    purchaseStatus: it.purchaseStatus ?? null,
    buyerUserId: it.buyerUserId ?? null,
    photoUrls: it.photoUrls,
    bestPhotoIndex: it.bestPhotoIndex,
  }));

  return response(200, { evaluations });
};

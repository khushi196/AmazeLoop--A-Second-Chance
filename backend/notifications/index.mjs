/**
 * AmazeLoopNotificationsFunction  (GET /notifications)
 *
 * Returns the authenticated user's in-app notifications, newest first.
 * Identity comes from the Cognito authorizer claims (sub).
 *
 * Notifications are written by:
 *   - the Purchase Lambda (on BUY / RESERVE), and
 *   - the Reservation Sweep Lambda (on expiry).
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";

const REGION = process.env.AWS_REGION || "ap-south-1";
const NOTIFICATIONS_TABLE =
  process.env.NOTIFICATIONS_TABLE || "AmazeLoopNotifications";

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

export const handler = async (event) => {
  if (
    event?.requestContext?.http?.method === "OPTIONS" ||
    event?.httpMethod === "OPTIONS"
  ) {
    return response(204, {});
  }

  const restClaims = event?.requestContext?.authorizer?.claims;
  const httpClaims = event?.requestContext?.authorizer?.jwt?.claims;
  const claims = restClaims || httpClaims || {};
  const userId = claims.sub || event?.queryStringParameters?.userId;
  if (!userId) {
    return response(401, { error: "Authentication required." });
  }

  const limit = Math.min(Number(event?.queryStringParameters?.limit) || 50, 100);

  let items = [];
  try {
    const result = await ddb.send(
      new QueryCommand({
        TableName: NOTIFICATIONS_TABLE,
        KeyConditionExpression: "userId = :u",
        ExpressionAttributeValues: { ":u": userId },
        ScanIndexForward: false, // newest first (createdAt is the sort key)
        Limit: limit,
      })
    );
    items = result.Items || [];
  } catch (e) {
    return response(500, { error: "Failed to load notifications.", detail: e.message });
  }

  const notifications = items.map((it) => ({
    notificationId: it.notificationId,
    type: it.type,
    title: it.title,
    body: it.body,
    evaluationId: it.evaluationId || null,
    read: it.read === true,
    createdAt: it.createdAt,
  }));

  const unreadCount = notifications.filter((n) => !n.read).length;

  return response(200, { notifications, unreadCount });
};

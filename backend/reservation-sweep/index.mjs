/**
 * AmazeLoopReservationSweepFunction  (scheduled, EventBridge)
 *
 * Runs on a timer. Finds reservations whose 24h hold has expired, releases
 * them back to the marketplace (clears buyerUserId / purchaseStatus /
 * reservationExpiresAt), and writes an expiry notification to the buyer who
 * let the hold lapse.
 *
 * This is the proactive counterpart to the lazy expiry checks in the
 * /listings and /purchases Lambdas — it guarantees items return to the
 * marketplace and buyers get notified even if nobody opens the app.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  ScanCommand,
  UpdateCommand,
  PutCommand,
} from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
const NOTIFICATIONS_TABLE =
  process.env.NOTIFICATIONS_TABLE || "AmazeLoopNotifications";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

export const handler = async () => {
  const nowIso = new Date().toISOString();

  // Find expired RESERVED holds.
  let expired = [];
  try {
    const result = await ddb.send(
      new ScanCommand({
        TableName: EVALUATIONS_TABLE,
        FilterExpression:
          "purchaseStatus = :r AND attribute_exists(reservationExpiresAt) AND reservationExpiresAt < :now",
        ExpressionAttributeValues: { ":r": "RESERVED", ":now": nowIso },
      })
    );
    expired = result.Items || [];
  } catch (e) {
    console.error(`sweep scan failed: ${e.message}`);
    return { released: 0, error: e.message };
  }

  let released = 0;
  for (const item of expired) {
    const evaluationId = item.evaluationId;
    const buyerUserId = item.buyerUserId;
    const title = item.productName || "your reserved item";

    // Release the hold — conditional so we don't stomp a concurrent BUY.
    try {
      await ddb.send(
        new UpdateCommand({
          TableName: EVALUATIONS_TABLE,
          Key: { evaluationId },
          UpdateExpression:
            "REMOVE buyerUserId, purchaseStatus, purchaseTimestamp, reservationExpiresAt",
          ConditionExpression:
            "purchaseStatus = :r AND reservationExpiresAt < :now",
          ExpressionAttributeValues: { ":r": "RESERVED", ":now": nowIso },
        })
      );
      released += 1;
    } catch (e) {
      if (e.name !== "ConditionalCheckFailedException") {
        console.error(`release failed for ${evaluationId}: ${e.message}`);
      }
      continue; // someone bought it in the meantime, or it changed — skip
    }

    // Notify the buyer who let it lapse.
    if (buyerUserId) {
      try {
        await ddb.send(
          new PutCommand({
            TableName: NOTIFICATIONS_TABLE,
            Item: {
              userId: buyerUserId,
              createdAt: new Date().toISOString(),
              notificationId: `NOTIF-${randomUUID()}`,
              type: "RESERVATION_EXPIRED",
              title: "Reservation expired",
              body: `Your reservation for "${title}" expired and it's back on the marketplace.`,
              evaluationId,
              read: false,
            },
          })
        );
      } catch (e) {
        console.error(`expiry notify failed for ${buyerUserId}: ${e.message}`);
      }
    }

    // Notify the seller too — their item is listed again.
    const sellerUserId = item.userId;
    if (sellerUserId && sellerUserId !== buyerUserId) {
      try {
        await ddb.send(
          new PutCommand({
            TableName: NOTIFICATIONS_TABLE,
            Item: {
              userId: sellerUserId,
              createdAt: new Date(Date.now() + 1).toISOString(), // +1ms so it sorts after the buyer's
              notificationId: `NOTIF-${randomUUID()}`,
              type: "LISTING_RELISTED",
              title: "Your item is listed again",
              body: `The reservation on your "${title}" expired, so it's back on the marketplace.`,
              evaluationId,
              read: false,
            },
          })
        );
      } catch (e) {
        console.error(`seller relist notify failed for ${sellerUserId}: ${e.message}`);
      }
    }
  }

  console.log(`sweep released ${released} reservation(s).`);
  return { released };
};

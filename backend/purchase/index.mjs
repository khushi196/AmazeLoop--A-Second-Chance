/**
 * AmazeLoopPurchaseFunction  (POST /purchase)
 *
 * Buyer-side reserve / buy flow. Two actions:
 *   - RESERVE: holds the item for 24h (purchaseStatus = RESERVED,
 *     reservationExpiresAt = now + 24h). It leaves the marketplace and
 *     appears in the buyer's "Reserved" tab.
 *   - BUY: completes the purchase (purchaseStatus = SOLD). It leaves the
 *     marketplace permanently and appears in "My Purchases". A buyer can
 *     BUY a fresh item directly, or convert their own active reservation.
 *
 * Identity comes from the Cognito authorizer claims (sub) so a buyer cannot
 * impersonate another user via the body.
 *
 * Concurrency safety: writes use a conditional expression so two buyers
 * can't both claim the same available item.
 *
 * Request:  { "evaluationId": "EVAL-...", "action": "RESERVE" | "BUY" }
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  UpdateCommand,
  PutCommand,
} from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
const NOTIFICATIONS_TABLE = process.env.NOTIFICATIONS_TABLE || "AmazeLoopNotifications";
const RESERVATION_HOURS = Number(process.env.RESERVATION_HOURS || 24);

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

/** Best-effort notification write — never fails the purchase if this errors. */
async function notify(userId, type, title, bodyText, evaluationId) {
  try {
    await ddb.send(
      new PutCommand({
        TableName: NOTIFICATIONS_TABLE,
        Item: {
          userId,
          createdAt: new Date().toISOString(),
          notificationId: `NOTIF-${randomUUID()}`,
          type,
          title,
          body: bodyText,
          evaluationId: evaluationId || null,
          read: false,
        },
      })
    );
  } catch (e) {
    console.error(`notify failed: ${e.message}`);
  }
}

export const handler = async (event) => {
  if (
    event?.requestContext?.http?.method === "OPTIONS" ||
    event?.httpMethod === "OPTIONS"
  ) {
    return response(204, {});
  }

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

  const action = (body.action || "RESERVE").toUpperCase();
  if (action !== "RESERVE" && action !== "BUY" && action !== "CANCEL") {
    return response(400, { error: "action must be RESERVE, BUY, or CANCEL." });
  }

  const restClaims = event?.requestContext?.authorizer?.claims;
  const httpClaims = event?.requestContext?.authorizer?.jwt?.claims;
  const claims = restClaims || httpClaims || {};
  const buyerUserId = claims.sub || body.buyerUserId;
  if (!buyerUserId) {
    return response(401, { error: "Missing buyer identity. Authentication required." });
  }

  // 1. Fetch the evaluation
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

  const effectiveDisposition = item.chosenDisposition || item.finalDisposition;
  if (item.status !== "ROUTED" || effectiveDisposition !== "Resell") {
    return response(400, { error: "This item is not available." });
  }

  const now = new Date();
  const nowIso = now.toISOString();
  const title = item.productName || "your item";

  // -------------------------------------------------------------------------
  // CANCEL — the buyer releases their own reservation back to the marketplace.
  // Clears the buyer fields so the item is listable again; the seller's
  // history then shows it as "Listed - not bought".
  // -------------------------------------------------------------------------
  if (action === "CANCEL") {
    if (item.purchaseStatus !== "RESERVED" || item.buyerUserId !== buyerUserId) {
      return response(409, {
        error: "You don't have an active reservation on this item.",
      });
    }
    try {
      await ddb.send(
        new UpdateCommand({
          TableName: EVALUATIONS_TABLE,
          Key: { evaluationId },
          UpdateExpression:
            "REMOVE buyerUserId, purchaseStatus, purchaseTimestamp, reservationExpiresAt",
          ConditionExpression: "buyerUserId = :b AND purchaseStatus = :r",
          ExpressionAttributeValues: { ":b": buyerUserId, ":r": "RESERVED" },
        })
      );
    } catch (e) {
      if (e.name === "ConditionalCheckFailedException") {
        return response(409, { error: "This reservation is no longer active." });
      }
      return response(500, {
        error: "Failed to cancel reservation.",
        detail: e.message,
      });
    }

    // Notify the seller that their item is back on the marketplace.
    if (item.userId && item.userId !== buyerUserId) {
      await notify(
        item.userId,
        "LISTING_RELISTED",
        "Your item is listed again",
        `The reservation on your "${title}" was cancelled, so it's back on the marketplace.`,
        evaluationId
      );
    }

    return response(200, {
      evaluationId,
      purchaseStatus: "AVAILABLE",
      released: true,
    });
  }

  // Determine current ownership, treating an expired reservation as free.
  const reservedByOther =
    item.buyerUserId && item.buyerUserId !== buyerUserId;
  const reservationExpired =
    item.purchaseStatus === "RESERVED" &&
    item.reservationExpiresAt &&
    new Date(item.reservationExpiresAt) < now;
  const alreadySold = item.purchaseStatus === "SOLD";

  if (alreadySold) {
    if (item.buyerUserId === buyerUserId) {
      return response(200, {
        evaluationId,
        buyerUserId,
        purchaseStatus: "SOLD",
        alreadyOwned: true,
      });
    }
    return response(409, { error: "This item has already been sold." });
  }
  if (reservedByOther && !reservationExpired) {
    return response(409, { error: "This item is currently reserved by another buyer." });
  }

  const ownActiveReservation =
    item.buyerUserId === buyerUserId &&
    item.purchaseStatus === "RESERVED" &&
    !reservationExpired;

  // -------------------------------------------------------------------------
  // BUY
  // -------------------------------------------------------------------------
  if (action === "BUY") {
    try {
      await ddb.send(
        new UpdateCommand({
          TableName: EVALUATIONS_TABLE,
          Key: { evaluationId },
          UpdateExpression:
            "SET buyerUserId = :b, purchaseStatus = :ps, purchaseTimestamp = :t REMOVE reservationExpiresAt ADD resaleCount :one",
          // Succeed if the item is free, OR already reserved by this buyer.
          ConditionExpression:
            "attribute_not_exists(buyerUserId) OR buyerUserId = :b OR purchaseStatus <> :sold",
          ExpressionAttributeValues: {
            ":b": buyerUserId,
            ":ps": "SOLD",
            ":t": nowIso,
            ":sold": "SOLD",
            ":one": 1,
          },
        })
      );
    } catch (e) {
      if (e.name === "ConditionalCheckFailedException") {
        return response(409, { error: "This item is no longer available." });
      }
      return response(500, { error: "Failed to complete purchase.", detail: e.message });
    }

    await notify(
      buyerUserId,
      "PURCHASE",
      "Purchase confirmed",
      `Your purchase of "${title}" is confirmed.`,
      evaluationId
    );

    // Notify the seller too — but only if we're not the seller ourselves.
    if (item.userId && item.userId !== buyerUserId) {
      await notify(
        item.userId,
        "ITEM_SOLD",
        "Your item was bought",
        `Your listed "${title}" has been bought.`,
        evaluationId
      );
    }

    return response(200, {
      evaluationId,
      buyerUserId,
      purchaseStatus: "SOLD",
      purchaseTimestamp: nowIso,
      converted: ownActiveReservation,
    });
  }

  // -------------------------------------------------------------------------
  // RESERVE
  // -------------------------------------------------------------------------
  if (ownActiveReservation) {
    // Idempotent: re-reserving your own active hold just returns it.
    return response(200, {
      evaluationId,
      buyerUserId,
      purchaseStatus: "RESERVED",
      purchaseTimestamp: item.purchaseTimestamp || null,
      reservationExpiresAt: item.reservationExpiresAt,
      alreadyReserved: true,
    });
  }

  const expiresAt = new Date(
    now.getTime() + RESERVATION_HOURS * 60 * 60 * 1000
  ).toISOString();

  try {
    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression:
          "SET buyerUserId = :b, purchaseStatus = :ps, purchaseTimestamp = :t, reservationExpiresAt = :exp",
        // Free item, or our own (possibly expired) reservation.
        ConditionExpression:
          "attribute_not_exists(buyerUserId) OR buyerUserId = :b OR reservationExpiresAt < :now",
        ExpressionAttributeValues: {
          ":b": buyerUserId,
          ":ps": "RESERVED",
          ":t": nowIso,
          ":exp": expiresAt,
          ":now": nowIso,
        },
      })
    );
  } catch (e) {
    if (e.name === "ConditionalCheckFailedException") {
      return response(409, { error: "This item has just been reserved by another buyer." });
    }
    return response(500, { error: "Failed to reserve item.", detail: e.message });
  }

  await notify(
    buyerUserId,
    "RESERVATION",
    "Item reserved",
    `You reserved "${title}". It's held for ${RESERVATION_HOURS}h — buy it before it expires.`,
    evaluationId
  );

  // Notify the seller that someone is holding their item — only if we're
  // not the seller ourselves.
  if (item.userId && item.userId !== buyerUserId) {
    await notify(
      item.userId,
      "ITEM_RESERVED",
      "Your item was reserved",
      `A buyer reserved your listed "${title}". They have ${RESERVATION_HOURS}h to complete the purchase.`,
      evaluationId
    );
  }

  return response(200, {
    evaluationId,
    buyerUserId,
    purchaseStatus: "RESERVED",
    purchaseTimestamp: nowIso,
    reservationExpiresAt: expiresAt,
  });
};

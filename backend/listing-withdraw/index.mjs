/**
 * AmazeLoopListingWithdrawFunction  (POST /listings/withdraw)
 *
 * Lets a SELLER remove their own listed item from the marketplace.
 *
 * Rules:
 *   - Only the owning seller (item.userId) may withdraw.
 *   - A SOLD item can never be withdrawn (the sale is final).
 *   - An item that is currently RESERVED by a buyer can still be withdrawn:
 *       the reservation is cleared (which frees one of that buyer's 5 slots,
 *       since the slot count only counts active RESERVED holds), and the
 *       buyer is notified that the seller removed the item.
 *   - Withdrawing sets marketplaceStatus = "withdrawn", so the item leaves the
 *     marketplace immediately (the listings + listing-detail + purchase
 *     Lambdas all treat "withdrawn" as not available).
 *
 * Concurrency safety: the update uses a ConditionExpression so a withdraw
 * can't clobber a purchase that lands at the same instant — if the item was
 * just SOLD, the seller gets a 409 instead.
 *
 * Request:  { "evaluationId": "EVAL-...", "userId"?: "..." }
 * Identity: prefer the Cognito authorizer claim (sub); fall back to body.userId
 *           to match the existing (demo-public) seller routes.
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
      "Access-Control-Allow-Methods": "POST,OPTIONS",
    },
    body: JSON.stringify(body),
  };
}

/** Best-effort notification write — never fails the withdraw if this errors. */
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

// ---------------------------------------------------------------------------
// Pure helpers (exported for unit tests; the handler reuses them so the rules
// stay in one place).
// ---------------------------------------------------------------------------

/** True when [sellerId] owns [item] — only the lister may withdraw it. */
export function isSellerOwner(item, sellerId) {
  return Boolean(item) && Boolean(sellerId) && item.userId === sellerId;
}

/**
 * True when [item] is a live marketplace listing the seller can still remove:
 * routed for Resell, not already withdrawn, and not sold.
 */
export function isWithdrawableListing(item) {
  if (!item) return false;
  if (item.status !== "ROUTED") return false;
  const effective = item.chosenDisposition || item.finalDisposition;
  if (effective !== "Resell") return false;
  if (item.marketplaceStatus === "withdrawn") return false;
  if (item.purchaseStatus === "SOLD") return false;
  return true;
}

/**
 * True when [item] still has a reservation active at [now] (a Date). A hold
 * with no expiry is treated as active; an expired hold is not.
 */
export function hasActiveReservation(item, now) {
  if (!item || item.purchaseStatus !== "RESERVED" || !item.buyerUserId) return false;
  if (!item.reservationExpiresAt) return true;
  return new Date(item.reservationExpiresAt) > now;
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

  const claims =
    event?.requestContext?.authorizer?.jwt?.claims ||
    event?.requestContext?.authorizer?.claims ||
    {};
  const sellerId = claims.sub;
  const callerRole = claims["custom:role"];
  if (!sellerId) {
    return response(401, { error: "Authentication required." });
  }
  if (callerRole !== "customer" && callerRole !== "warehouse") {
    return response(403, { error: "Not authorized for seller actions." });
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

  // 2. Only the owning seller may withdraw their listing.
  if (!isSellerOwner(item, sellerId)) {
    return response(403, { error: "You can only remove your own listings." });
  }

  // 3. Must currently be a marketplace listing (ROUTED + Resell).
  const effectiveDisposition = item.chosenDisposition || item.finalDisposition;
  if (item.status !== "ROUTED" || effectiveDisposition !== "Resell") {
    return response(400, { error: "This item is not listed on the marketplace." });
  }

  // 4. Already withdrawn → idempotent success.
  if (item.marketplaceStatus === "withdrawn") {
    return response(200, { evaluationId, withdrawn: true, releasedBuyer: false, alreadyWithdrawn: true });
  }

  // 5. A completed sale is final.
  if (item.purchaseStatus === "SOLD") {
    return response(409, { error: "This item has already been sold and can't be removed." });
  }

  const title = item.productName || "your item";
  const now = new Date();

  // Was it actively reserved by a buyer (not an expired hold)?
  const reservationActive = hasActiveReservation(item, now);
  const reservedBuyerId = reservationActive ? item.buyerUserId : null;

  // 6. Withdraw: leave the marketplace and release any reservation. The
  // ConditionExpression blocks the rare race where a BUY lands first.
  try {
    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression:
          "SET marketplaceStatus = :w REMOVE buyerUserId, purchaseStatus, purchaseTimestamp, reservationExpiresAt",
        ConditionExpression:
          "userId = :seller AND (attribute_not_exists(purchaseStatus) OR purchaseStatus <> :sold)",
        ExpressionAttributeValues: {
          ":w": "withdrawn",
          ":seller": sellerId,
          ":sold": "SOLD",
        },
      })
    );
  } catch (e) {
    if (e.name === "ConditionalCheckFailedException") {
      return response(409, {
        error: "This item was just bought, so it can no longer be removed.",
      });
    }
    return response(500, { error: "Failed to remove listing.", detail: e.message });
  }

  // 7. Tell the buyer who was holding it that the seller pulled it. Their
  // reserved slot is already freed because purchaseStatus was removed above.
  if (reservedBuyerId && reservedBuyerId !== sellerId) {
    await notify(
      reservedBuyerId,
      "LISTING_WITHDRAWN",
      "Reserved item removed by seller",
      `The seller removed "${title}" from the marketplace, so your reservation was cancelled and a reserved slot was freed.`,
      evaluationId
    );
  }

  return response(200, {
    evaluationId,
    withdrawn: true,
    releasedBuyer: Boolean(reservedBuyerId),
  });
};

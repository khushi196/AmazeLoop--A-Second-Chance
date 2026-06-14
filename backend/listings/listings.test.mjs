/**
 * Regression tests for marketplace visibility (isListable) in index.mjs.
 *
 * Guards the rule that ONLY routed, Resell, currently-available items reach the
 * buyer feed — i.e. SOLD/actively-RESERVED items and non-Resell dispositions
 * (Recycle/Donate/Refurbish/ReturnToOrigin) are never shown.
 *
 * Run:  node --test backend/listings/
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { isListable } from "./index.mjs";

const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
const past = new Date(Date.now() - 60 * 60 * 1000).toISOString();

test("routed Resell item with no buyer is listable", () => {
  assert.equal(
    isListable({ status: "ROUTED", finalDisposition: "Resell" }),
    true
  );
});

test("unrouted item is not listable", () => {
  assert.equal(
    isListable({ status: "PENDING", finalDisposition: "Resell" }),
    false
  );
});

test("non-Resell dispositions are never listable", () => {
  for (const d of ["Refurbish", "Recycle", "Donate", "ReturnToOrigin"]) {
    assert.equal(
      isListable({ status: "ROUTED", finalDisposition: d }),
      false,
      `${d} should not be listable`
    );
  }
});

test("chosenDisposition overrides finalDisposition for visibility", () => {
  // AI said Refurbish, operator chose Resell -> listable.
  assert.equal(
    isListable({
      status: "ROUTED",
      finalDisposition: "Refurbish",
      chosenDisposition: "Resell",
    }),
    true
  );
});

test("SOLD item is hidden", () => {
  assert.equal(
    isListable({
      status: "ROUTED",
      finalDisposition: "Resell",
      buyerUserId: "buyer-A",
      purchaseStatus: "SOLD",
    }),
    false
  );
});

test("actively RESERVED item is hidden", () => {
  assert.equal(
    isListable({
      status: "ROUTED",
      finalDisposition: "Resell",
      buyerUserId: "buyer-A",
      purchaseStatus: "RESERVED",
      reservationExpiresAt: future,
    }),
    false
  );
});

test("expired RESERVED item is listable again", () => {
  assert.equal(
    isListable({
      status: "ROUTED",
      finalDisposition: "Resell",
      buyerUserId: "buyer-A",
      purchaseStatus: "RESERVED",
      reservationExpiresAt: past,
    }),
    true
  );
});

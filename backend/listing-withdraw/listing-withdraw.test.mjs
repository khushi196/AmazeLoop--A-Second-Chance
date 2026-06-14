/**
 * Regression tests for the listing-withdraw pure helpers.
 *
 * These encode the seller-removal rules (ownership, withdrawable state, and
 * active-reservation detection) without mocking AWS, so they stay fast and
 * deterministic.
 *
 * Run:  node --test backend/listing-withdraw/
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  isSellerOwner,
  isWithdrawableListing,
  hasActiveReservation,
} from "./index.mjs";

const NOW = new Date("2026-06-14T12:00:00.000Z");
const FUTURE = "2026-06-15T12:00:00.000Z"; // after NOW → active
const PAST = "2026-06-13T12:00:00.000Z"; // before NOW → expired

const listed = (extra = {}) => ({
  evaluationId: "E1",
  userId: "seller-1",
  status: "ROUTED",
  finalDisposition: "Resell",
  ...extra,
});

test("owner is recognized as the seller", () => {
  assert.equal(isSellerOwner(listed(), "seller-1"), true);
});

test("non-owner cannot withdraw", () => {
  assert.equal(isSellerOwner(listed(), "someone-else"), false);
  assert.equal(isSellerOwner(null, "seller-1"), false);
  assert.equal(isSellerOwner(listed(), undefined), false);
});

test("owner can withdraw a routed Resell item that is not sold", () => {
  assert.equal(isWithdrawableListing(listed()), true);
  // chosenDisposition overrides finalDisposition and still counts as Resell.
  assert.equal(
    isWithdrawableListing(listed({ finalDisposition: "Refurbish", chosenDisposition: "Resell" })),
    true,
  );
});

test("SOLD item is not withdrawable", () => {
  assert.equal(isWithdrawableListing(listed({ purchaseStatus: "SOLD" })), false);
});

test("already withdrawn item is not withdrawable", () => {
  assert.equal(isWithdrawableListing(listed({ marketplaceStatus: "withdrawn" })), false);
});

test("non-listed states are not withdrawable", () => {
  assert.equal(isWithdrawableListing(listed({ status: "PENDING" })), false);
  assert.equal(isWithdrawableListing(listed({ finalDisposition: "Recycle" })), false);
  assert.equal(isWithdrawableListing(null), false);
});

test("active RESERVED item is recognized as having an active reservation", () => {
  const item = listed({
    purchaseStatus: "RESERVED",
    buyerUserId: "buyer-9",
    reservationExpiresAt: FUTURE,
  });
  assert.equal(hasActiveReservation(item, NOW), true);
});

test("expired RESERVED item is not treated as active", () => {
  const item = listed({
    purchaseStatus: "RESERVED",
    buyerUserId: "buyer-9",
    reservationExpiresAt: PAST,
  });
  assert.equal(hasActiveReservation(item, NOW), false);
});

test("non-reserved items have no active reservation", () => {
  assert.equal(hasActiveReservation(listed(), NOW), false);
  assert.equal(hasActiveReservation(listed({ purchaseStatus: "SOLD" }), NOW), false);
});

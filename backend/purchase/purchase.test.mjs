/**
 * Regression tests for the BUY atomic-claim rule in index.mjs.
 *
 * These assert buyConditionSatisfied(), which encodes the exact boolean of the
 * BUY ConditionExpression. They guard against regressing to the old
 * `purchaseStatus <> :sold` rule that let one buyer purchase an item actively
 * reserved by another.
 *
 * Run:  node --test backend/purchase/
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { buyConditionSatisfied } from "./index.mjs";

const NOW = "2026-06-14T12:00:00.000Z";
const FUTURE = "2026-06-15T12:00:00.000Z"; // active reservation (after NOW)
const PAST = "2026-06-13T12:00:00.000Z"; // expired reservation (before NOW)

const A = "buyer-A";
const B = "buyer-B";

test("free item can be bought", () => {
  const item = { evaluationId: "E1" }; // no buyerUserId
  assert.equal(buyConditionSatisfied(item, B, NOW), true);
});

test("buyer can buy their own active reservation", () => {
  const item = {
    buyerUserId: B,
    purchaseStatus: "RESERVED",
    reservationExpiresAt: FUTURE,
  };
  assert.equal(buyConditionSatisfied(item, B, NOW), true);
});

test("another buyer cannot buy someone else's active reservation", () => {
  const item = {
    buyerUserId: A,
    purchaseStatus: "RESERVED",
    reservationExpiresAt: FUTURE,
  };
  assert.equal(buyConditionSatisfied(item, B, NOW), false);
});

test("expired reservation can be reclaimed by another buyer", () => {
  const item = {
    buyerUserId: A,
    purchaseStatus: "RESERVED",
    reservationExpiresAt: PAST,
  };
  assert.equal(buyConditionSatisfied(item, B, NOW), true);
});

test("SOLD item cannot be bought again by another buyer", () => {
  // BUY removes reservationExpiresAt, so a SOLD record has no expiry to reclaim.
  const item = { buyerUserId: A, purchaseStatus: "SOLD" };
  assert.equal(buyConditionSatisfied(item, B, NOW), false);
});

test("owner re-buying their own SOLD item is allowed (idempotent)", () => {
  const item = { buyerUserId: B, purchaseStatus: "SOLD" };
  assert.equal(buyConditionSatisfied(item, B, NOW), true);
});

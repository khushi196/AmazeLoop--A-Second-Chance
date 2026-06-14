/**
 * Regression tests for the Health Card sustainability helpers in index.mjs.
 *
 * Guards the buyer-facing numbers: category-keyed reuse CO2, the reverse-shipping
 * distance (routing distance + constant hub leg), and the transport CO2 derived
 * from it. These must stay in sync with the Flutter sustainability helper.
 *
 * Run:  node --test backend/listing-detail/
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  circularImpactKg,
  reverseShippingAvoidedKm,
  transportCo2SavedKg,
} from "./index.mjs";

test("circularImpactKg uses category keywords with a generic fallback", () => {
  assert.equal(circularImpactKg("Mobile Phones"), 55);
  assert.equal(circularImpactKg("Laptop / Computer"), 320);
  assert.equal(circularImpactKg("Footwear / apparel"), 8);
  assert.equal(circularImpactKg("Something else"), 25); // fallback
  assert.equal(circularImpactKg(null), 25);
});

test("reverseShippingAvoidedKm = distance + 150 hub constant, rounded", () => {
  assert.equal(reverseShippingAvoidedKm(25), 175);
  assert.equal(reverseShippingAvoidedKm(0), 150);
  assert.equal(reverseShippingAvoidedKm(null), 150);
});

test("transportCo2SavedKg = reverseKm * 0.12, 1 decimal", () => {
  // (25 + 150) * 0.12 = 21.0
  assert.equal(transportCo2SavedKg(25), 21);
  // 150 * 0.12 = 18.0
  assert.equal(transportCo2SavedKg(0), 18);
});

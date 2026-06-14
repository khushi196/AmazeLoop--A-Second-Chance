/**
 * Regression tests for route-confirm disposition validation (isValidDisposition).
 *
 * Guards that only the five accepted dispositions are confirmable (so a bad
 * body can't lock an item into an unknown state), and that the supported set
 * — including Donate and ReturnToOrigin — stays accepted.
 *
 * Run:  node --test backend/route-confirm/
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { isValidDisposition } from "./index.mjs";

test("accepts the five valid dispositions", () => {
  for (const d of ["Resell", "Refurbish", "Recycle", "ReturnToOrigin", "Donate"]) {
    assert.equal(isValidDisposition(d), true, `${d} should be valid`);
  }
});

test("rejects unknown or malformed dispositions", () => {
  for (const d of ["resell", "DONATE", "Sell", "", null, undefined, "Frobnicate"]) {
    assert.equal(isValidDisposition(d), false, `${String(d)} should be invalid`);
  }
});

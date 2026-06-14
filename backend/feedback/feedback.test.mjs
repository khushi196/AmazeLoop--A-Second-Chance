/**
 * Regression tests for feedback type validation (isValidFeedbackType).
 *
 * Guards that only the two accepted mis-grade signals are stored, so a bad
 * body can't stamp an arbitrary feedbackType onto an evaluation.
 *
 * Run:  node --test backend/feedback/
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { isValidFeedbackType } from "./index.mjs";

test("accepts too_optimistic", () => {
  assert.equal(isValidFeedbackType("too_optimistic"), true);
});

test("accepts too_strict", () => {
  assert.equal(isValidFeedbackType("too_strict"), true);
});

test("rejects unknown or malformed feedback types", () => {
  for (const t of ["TOO_OPTIMISTIC", "optimistic", "wrong", "", null, undefined, 0]) {
    assert.equal(isValidFeedbackType(t), false, `${String(t)} should be invalid`);
  }
});

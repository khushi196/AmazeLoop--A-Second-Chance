/**
 * AmazeLoopFeedbackFunction  (POST /feedback)
 *
 * Allows sellers to flag an AI grading as mis-graded (too optimistic or too
 * strict). Stamps feedbackFlag=true + feedbackType on the Evaluation record.
 *
 * Request: { "evaluationId": "EVAL-...", "feedbackType": "too_optimistic" | "too_strict" }
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";

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

const VALID_TYPES = ["too_optimistic", "too_strict"];

/** True if [t] is an accepted mis-grade feedback type. Exported for tests. */
export function isValidFeedbackType(t) {
  return VALID_TYPES.includes(t);
}

export const handler = async (event) => {
  if (event?.requestContext?.http?.method === "OPTIONS" ||
      event?.httpMethod === "OPTIONS") {
    return response(204, {});
  }

  let body;
  try {
    body = typeof event.body === "string" ? JSON.parse(event.body) : (event.body || event);
  } catch (e) {
    return response(400, { error: "Invalid JSON body." });
  }

  const evaluationId = body.evaluationId;
  const feedbackType = body.feedbackType;

  if (!evaluationId || typeof evaluationId !== "string") {
    return response(400, { error: "evaluationId is required." });
  }
  if (!isValidFeedbackType(feedbackType)) {
    return response(400, { error: "feedbackType must be 'too_optimistic' or 'too_strict'." });
  }

  try {
    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression: "SET feedbackFlag = :f, feedbackType = :t",
        // Only flag an evaluation that actually exists — without this, an
        // UpdateItem would silently create a phantom record for a bad id.
        ConditionExpression: "attribute_exists(evaluationId)",
        ExpressionAttributeValues: {
          ":f": true,
          ":t": feedbackType,
        },
      })
    );
  } catch (e) {
    if (e.name === "ConditionalCheckFailedException") {
      return response(404, { error: "Evaluation not found." });
    }
    return response(500, { error: "Failed to save feedback.", detail: e.message });
  }

  return response(200, { evaluationId, feedbackFlag: true, feedbackType });
};

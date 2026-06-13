/**
 * AmazeLoopRouteConfirmFunction  (POST /route/confirm)
 *
 * Records the user's chosen disposition (which may override the AI's
 * recommendation) on the Evaluation record.
 *
 * Request:  { "evaluationId": "EVAL-...", "chosenDisposition": "Refurbish" }
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

const VALID_DISPOSITIONS = ["Resell", "Refurbish", "Recycle"];

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify(body),
  };
}

export const handler = async (event) => {
  let body;
  try {
    body = typeof event.body === "string" ? JSON.parse(event.body) : (event.body || event);
  } catch (e) {
    return response(400, { error: "Invalid JSON body." });
  }

  const evaluationId = body.evaluationId;
  const chosenDisposition = body.chosenDisposition;

  if (!evaluationId || typeof evaluationId !== "string") {
    return response(400, { error: "evaluationId is required." });
  }
  if (!VALID_DISPOSITIONS.includes(chosenDisposition)) {
    return response(400, { error: "chosenDisposition must be one of Resell, Refurbish, Recycle." });
  }

  // Read the AI's recommended disposition to detect an override
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

  const finalDisposition = item.finalDisposition ?? null;
  const isOverride = finalDisposition != null && chosenDisposition !== finalDisposition;

  // Persist the chosen disposition + override flag + routed status
  try {
    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression: "SET chosenDisposition = :cd, isOverride = :ov, #s = :st",
        ExpressionAttributeNames: { "#s": "status" },
        ExpressionAttributeValues: {
          ":cd": chosenDisposition,
          ":ov": isOverride,
          ":st": "ROUTED",
        },
      })
    );
  } catch (e) {
    return response(500, { error: "Failed to save chosen disposition.", detail: e.message });
  }

  return response(200, {
    evaluationId,
    chosenDisposition,
    finalDisposition,
    isOverride,
  });
};

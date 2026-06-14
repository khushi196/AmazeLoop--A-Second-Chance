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
import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";

const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
// Best available model that works without the Anthropic use-case form.
const MODEL_ID = process.env.BEDROCK_MODEL_ID || "apac.amazon.nova-pro-v1:0";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));
const bedrock = new BedrockRuntimeClient({ region: REGION });

const VALID_DISPOSITIONS = ["Resell", "Refurbish", "Recycle", "ReturnToOrigin", "Donate"];

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

/**
 * When the operator overrides the AI's recommended disposition, the original
 * `routeReason` (written for the AI's choice) becomes stale. This helper asks
 * the same model to write a fresh one-sentence rationale for the chosen
 * disposition, using the strict "explain, don't override" framing the route
 * Lambda already uses. Returns the sentence, or a templated fallback.
 */
async function explainChosenRoute(item, chosenDisposition) {
  const money = (v) => (v == null ? "unknown" : `Rs.${Math.round(Number(v))}`);
  const promptText =
    `You are explaining a recommerce routing decision to a warehouse operator.\n` +
    `The backend has already made the final routing decision using deterministic rules. ` +
    `You must NOT change, question, or override the chosen disposition. Only explain it clearly.\n\n` +
    `Product: ${item.productName || "item"} (category: ${item.category || "unknown"}).\n` +
    `Condition: ${item.condition || "unknown"} (score ${item.conditionScore ?? "n/a"}).\n` +
    `Fair like-new price: ${money(item.normalizedPrice)}.\n` +
    `Estimated resale value: ${money(item.estimatedResaleValue)}.\n` +
    `Distance to nearest warehouse: ${item.distanceKm == null ? "unknown" : item.distanceKm + " km"}.\n` +
    `Chosen disposition: ${chosenDisposition}.\n\n` +
    `Write ONE short sentence explaining why ${chosenDisposition} is appropriate, ` +
    `considering condition, resale value, and distance.\n` +
    `Rules:\n` +
    `- Do not mention a different route.\n` +
    `- Do not add uncertainty unless the inputs indicate uncertainty.\n` +
    `- Do not use markdown.\n` +
    `- Do not add preamble.\n` +
    `- Respond with only one sentence.`;

  try {
    const resp = await bedrock.send(
      new ConverseCommand({
        modelId: MODEL_ID,
        messages: [{ role: "user", content: [{ text: promptText }] }],
        inferenceConfig: { maxTokens: 120, temperature: 0.2, topP: 0.9 },
      })
    );
    const text = (resp?.output?.message?.content?.[0]?.text || "").trim();
    if (text) return text.replace(/^["']|["']$/g, "");
  } catch (e) {
    console.error(`Override explanation failed: ${e.message}`);
  }
  // Fallback: keep the disposition phrased simply.
  return `${chosenDisposition} chosen by operator override.`;
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
    return response(400, {
      error:
        "chosenDisposition must be one of Resell, Refurbish, Recycle, ReturnToOrigin, Donate.",
    });
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

  // If the operator overrode the AI, the original routeReason was written for
  // the AI's pick and is now stale. Regenerate a fresh one-sentence rationale
  // for the chosen disposition. Best-effort — failures fall back to template.
  let newRouteReason = null;
  if (isOverride) {
    newRouteReason = await explainChosenRoute(item, chosenDisposition);
  }

  // Persist the chosen disposition + override flag + routed status. For
  // ReturnToOrigin we additionally stamp marketplaceStatus = "not_listed"
  // so the record carries the internal-transfer signal explicitly. When an
  // override happens, also refresh routeReason so the seller's history,
  // listing detail, and Health Card all reflect the actual chosen path.
  try {
    const isInternalDisposition =
      chosenDisposition === "ReturnToOrigin" || chosenDisposition === "Donate";
    const setParts = [
      "chosenDisposition = :cd",
      "isOverride = :ov",
      "#s = :st",
    ];
    const exprValues = {
      ":cd": chosenDisposition,
      ":ov": isOverride,
      ":st": "ROUTED",
    };
    if (isInternalDisposition) {
      setParts.push("marketplaceStatus = :ms");
      exprValues[":ms"] = "not_listed";
    }
    if (newRouteReason != null) {
      setParts.push("routeReason = :rr");
      exprValues[":rr"] = newRouteReason;
    }

    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression: "SET " + setParts.join(", "),
        ExpressionAttributeNames: { "#s": "status" },
        ExpressionAttributeValues: exprValues,
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
    routeReason: newRouteReason,
  });
};

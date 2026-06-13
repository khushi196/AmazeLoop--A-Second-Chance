/**
 * AmazeLoopAiGradeFunction
 *
 * Takes an evaluationId, fetches the item's photos from S3, and uses an Amazon
 * Bedrock vision model (Amazon Nova) to assess the product's physical condition.
 * Derives a condition grade + damage score, computes an estimated resale value
 * from the normalized price, and writes the results back to the Evaluations table.
 *
 * (Replaces the earlier Rekognition DetectLabels approach, which could only
 * identify WHAT an object is — never its condition.)
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

// ---------------------------------------------------------------------------
// Configuration & shared clients
// ---------------------------------------------------------------------------
const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
const MODEL_ID = process.env.BEDROCK_MODEL_ID || "apac.amazon.nova-lite-v1:0";
const MAX_PHOTOS = 4;

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));
const s3 = new S3Client({ region: REGION });
const bedrock = new BedrockRuntimeClient({ region: REGION });

// Condition -> allowed priceMultiplier range (fraction of normalizedPrice)
const CONDITION_RANGE = {
  "Like New": [0.8, 1.0],
  "Good": [0.6, 0.8],
  "Used": [0.4, 0.6],
  "Damaged": [0.1, 0.3],
};

const VALID_CONDITIONS = ["Like New", "Good", "Used", "Damaged"];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

/** Parses an S3 URL (https virtual-hosted, path style, or s3://) into {Bucket, Name}. */
function parseS3Url(url) {
  if (typeof url !== "string" || url.length === 0) return null;
  if (url.startsWith("s3://")) {
    const rest = url.slice(5);
    const slash = rest.indexOf("/");
    if (slash === -1) return null;
    return { Bucket: rest.slice(0, slash), Name: decodeURIComponent(rest.slice(slash + 1)) };
  }
  try {
    const u = new URL(url);
    const host = u.hostname;
    const path = decodeURIComponent(u.pathname.replace(/^\//, ""));
    const vh = host.match(/^(.+)\.s3[.-][^.]*\.amazonaws\.com$/) || host.match(/^(.+)\.s3\.amazonaws\.com$/);
    if (vh) return { Bucket: vh[1], Name: path };
    if (/^s3[.-]/.test(host) || host === "s3.amazonaws.com") {
      const slash = path.indexOf("/");
      if (slash === -1) return null;
      return { Bucket: path.slice(0, slash), Name: path.slice(slash + 1) };
    }
  } catch (_) {
    return null;
  }
  return null;
}

/** Maps a file key to a Nova-supported image format string. */
function imageFormatFor(key) {
  const lower = key.toLowerCase();
  if (lower.endsWith(".png")) return "png";
  if (lower.endsWith(".webp")) return "webp";
  if (lower.endsWith(".gif")) return "gif";
  return "jpeg";
}

/** Fetches an S3 object and returns { base64, format } or null on failure. */
async function fetchImageAsBase64(url) {
  const s3ref = parseS3Url(url);
  if (!s3ref) return null;
  try {
    const obj = await s3.send(new GetObjectCommand({ Bucket: s3ref.Bucket, Key: s3ref.Name }));
    const bytes = await obj.Body.transformToByteArray();
    return {
      base64: Buffer.from(bytes).toString("base64"),
      format: imageFormatFor(s3ref.Name),
    };
  } catch (e) {
    console.error(`Failed to fetch image ${url}: ${e.message}`);
    return null;
  }
}

/**
 * Calls the Bedrock vision model (Amazon Nova) to grade the product condition
 * from photos. Returns { condition, conditionScore, priceMultiplier, conditionReason }
 * or null on failure.
 */
async function gradeWithVision({ images, productName, category }) {
  if (images.length === 0) return null;

  const promptText =
    `You are a STRICT expert product-condition grader for a recommerce (resale) platform. ` +
    `Be conservative: when in doubt, grade DOWN, not up. ` +
    `The photos show a used product${productName ? ` described as "${productName}"` : ""}` +
    `${category ? ` in the category "${category}"` : ""}. ` +
    `normalizedPrice is the fair like-new reference price for this exact model; you only decide what fraction of it this specific unit is worth.\n\n` +
    `Step 1 - decide the condition:\n` +
    `- "Like New": almost no visible wear.\n` +
    `- "Good": light wear, minor scuffs, no cracks.\n` +
    `- "Used": clearly used, noticeable wear, but no major cracks or breaks.\n` +
    `- "Damaged": ANY cracked or shattered screen, broken glass, major dents, or similar serious issues.\n\n` +
    `Step 2 - assign:\n` +
    `- conditionScore: a number between 0 and 1 (1 = perfect, <= 0.25 = very badly damaged).\n` +
    `- priceMultiplier (fraction of normalizedPrice) within these bands:\n` +
    `  Like New: 0.8-1.0   Good: 0.6-0.8   Used: 0.4-0.6   Damaged: 0.1-0.3.\n\n` +
    `HARD RULE: If you see a cracked or shattered screen, broken glass, or multiple major defects, ` +
    `you MUST choose "Damaged" and set priceMultiplier in the 0.1-0.2 range (severe reduction), closer to 0.1 for severe shattering.\n\n` +
    `Respond with ONLY a JSON object (no markdown, no extra text):\n` +
    `{"condition":"<Like New|Good|Used|Damaged>","conditionScore":<0-1>,"priceMultiplier":<fraction>,"reasoning":"<one concise sentence summarizing the main visible issues and why they justify this condition and price reduction>"}`;

  const content = images.map((img) => ({
    image: { format: img.format, source: { bytes: img.base64 } },
  }));
  content.push({ text: promptText });

  const payload = {
    messages: [{ role: "user", content }],
    inferenceConfig: { maxTokens: 300, temperature: 0, topP: 0.1, topK: 1 },
  };

  let raw;
  try {
    const resp = await bedrock.send(
      new InvokeModelCommand({
        modelId: MODEL_ID,
        contentType: "application/json",
        accept: "application/json",
        body: JSON.stringify(payload),
      })
    );
    const decoded = JSON.parse(Buffer.from(resp.body).toString("utf-8"));
    raw = decoded?.output?.message?.content?.[0]?.text ?? "";
  } catch (e) {
    console.error(`Bedrock invoke failed: ${e.message}`);
    return null;
  }

  // Extract the JSON object from the model's reply
  try {
    const match = raw.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(match ? match[0] : raw);

    let condition = parsed.condition;
    if (!VALID_CONDITIONS.includes(condition)) condition = "Used";

    let conditionScore = Number(parsed.conditionScore);
    if (Number.isNaN(conditionScore)) conditionScore = 0.5;
    conditionScore = Math.max(0, Math.min(1, conditionScore));

    let priceMultiplier = Number(parsed.priceMultiplier);
    if (Number.isNaN(priceMultiplier)) priceMultiplier = NaN; // handled by clamping later

    const conditionReason = (parsed.reasoning || parsed.reason || "").toString();
    return { condition, conditionScore, priceMultiplier, conditionReason };
  } catch (e) {
    console.error(`Failed to parse model output: ${raw}`);
    return null;
  }
}

/**
 * Computes the estimated resale value. Uses the model's priceMultiplier, but
 * clamps it into the allowed band for the chosen condition as a safety net,
 * then rounds to the nearest 10.
 */
function computeResaleValue(normalizedPrice, condition, priceMultiplier) {
  const range = CONDITION_RANGE[condition] || [0.4, 0.6];
  const [lo, hi] = range;
  let m = Number(priceMultiplier);
  if (Number.isNaN(m)) m = (lo + hi) / 2; // model gave none -> midpoint of band
  m = Math.max(lo, Math.min(hi, m)); // enforce the condition's band
  const raw = (Number(normalizedPrice) || 0) * m;
  return { estimatedResaleValue: Math.round(raw / 10) * 10, appliedMultiplier: m };
}

// ---------------------------------------------------------------------------
// handler — Lambda entry point
// ---------------------------------------------------------------------------
export const handler = async (event) => {
  let body;
  try {
    body = typeof event.body === "string" ? JSON.parse(event.body) : (event.body || event);
  } catch (e) {
    return response(400, { error: "Invalid JSON body." });
  }

  const evaluationId = body.evaluationId;
  if (!evaluationId || typeof evaluationId !== "string") {
    return response(400, { error: "evaluationId is required." });
  }

  // 1. Fetch the evaluation record
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

  const photoUrls = (Array.isArray(item.photoUrls) ? item.photoUrls : []).slice(0, MAX_PHOTOS);
  const normalizedPrice = item.normalizedPrice;

  // 2. Load the photos from S3
  const images = [];
  for (const url of photoUrls) {
    const img = await fetchImageAsBase64(url);
    if (img) images.push(img);
  }

  // 3. Grade condition with the vision model
  const graded = await gradeWithVision({
    images,
    productName: item.productName,
    category: item.category,
  });

  let condition, conditionReason, conditionScore, priceMultiplier;
  if (graded) {
    condition = graded.condition;
    conditionReason = graded.conditionReason || `Graded "${graded.condition}" from photo analysis.`;
    conditionScore = graded.conditionScore;
    priceMultiplier = graded.priceMultiplier;
  } else {
    // No usable photos or model failure — neutral default.
    condition = "Used";
    conditionReason = images.length === 0
      ? "No usable photos provided; defaulted to Used."
      : "Condition could not be determined from photos; defaulted to Used.";
    conditionScore = 0.5;
    priceMultiplier = NaN;
  }

  // 4. Estimated resale value (multiplier clamped into the condition's band)
  const { estimatedResaleValue, appliedMultiplier } =
      computeResaleValue(normalizedPrice, condition, priceMultiplier);

  // 5. Select best photo (simple: first successfully loaded image)
  const bestPhotoIndex = images.length > 0 ? 0 : null;

  // 6. Write results back to the same Evaluations record
  try {
    const updateExpr = bestPhotoIndex != null
      ? "SET #cond = :c, conditionReason = :cr, conditionScore = :cs, priceMultiplier = :pm, estimatedResaleValue = :erv, bestPhotoIndex = :bpi"
      : "SET #cond = :c, conditionReason = :cr, conditionScore = :cs, priceMultiplier = :pm, estimatedResaleValue = :erv";
    const exprVals = {
      ":c": condition,
      ":cr": conditionReason,
      ":cs": conditionScore,
      ":pm": appliedMultiplier,
      ":erv": estimatedResaleValue,
    };
    if (bestPhotoIndex != null) exprVals[":bpi"] = bestPhotoIndex;

    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression: updateExpr,
        ExpressionAttributeNames: { "#cond": "condition" },
        ExpressionAttributeValues: exprVals,
      })
    );
  } catch (e) {
    return response(500, { error: "Failed to update evaluation.", detail: e.message });
  }

  // 7. Respond
  return response(200, {
    evaluationId,
    condition,
    conditionReason,
    conditionScore,
    priceMultiplier: appliedMultiplier,
    estimatedResaleValue,
    bestPhotoIndex,
  });
};

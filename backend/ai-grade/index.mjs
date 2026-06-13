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
import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";

// ---------------------------------------------------------------------------
// Configuration & shared clients
// ---------------------------------------------------------------------------
const REGION = process.env.AWS_REGION || "ap-south-1";
const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE || "Evaluations";
// Best available multimodal model that works without the Anthropic use-case
// form. Switch to "global.anthropic.claude-opus-4-6-v1" once Anthropic access
// is granted in the Bedrock console (Model access → Anthropic use case form).
const MODEL_ID = process.env.BEDROCK_MODEL_ID || "apac.amazon.nova-pro-v1:0";
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

/** Maps a file key to a Nova-supported image format string, with a byte-level
 *  fallback so renamed files (e.g. .jpg but actually AVIF) are caught early. */
function imageFormatFor(key, firstBytes) {
  // Magic-byte detection takes priority over extension.
  if (firstBytes && firstBytes.length >= 12) {
    const h = firstBytes;
    // JPEG: FF D8 FF
    if (h[0] === 0xFF && h[1] === 0xD8 && h[2] === 0xFF) return "jpeg";
    // PNG: 89 50 4E 47
    if (h[0] === 0x89 && h[1] === 0x50 && h[2] === 0x4E && h[3] === 0x47) return "png";
    // WebP: RIFF????WEBP
    if (h[0] === 0x52 && h[1] === 0x49 && h[2] === 0x46 && h[3] === 0x46 &&
        h[8] === 0x57 && h[9] === 0x45 && h[10] === 0x42 && h[11] === 0x50) return "webp";
    // GIF87a / GIF89a
    if (h[0] === 0x47 && h[1] === 0x49 && h[2] === 0x46) return "gif";
  }
  // Extension fallback.
  const lower = key.toLowerCase();
  if (lower.endsWith(".png")) return "png";
  if (lower.endsWith(".webp")) return "webp";
  if (lower.endsWith(".gif")) return "gif";
  return "jpeg";
}

/** Fetches an S3 object and returns { bytes, format } or null on failure.
 *  Converse expects raw image bytes (Uint8Array), not base64. */
async function fetchImageBytes(url) {
  const s3ref = parseS3Url(url);
  if (!s3ref) return null;
  try {
    const obj = await s3.send(new GetObjectCommand({ Bucket: s3ref.Bucket, Key: s3ref.Name }));
    const bytes = await obj.Body.transformToByteArray();
    const format = imageFormatFor(s3ref.Name, bytes.slice(0, 12));
    if (format === null) {
      console.warn(`Unsupported image format for ${s3ref.Name} — skipping.`);
      return null;
    }
    return { bytes, format };
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
    `You are a precise visible physical-condition grader for a recommerce resale platform. ` +
    `Your only task is to inspect the provided photos and grade the visible physical condition of this specific item. ` +
    `Do NOT estimate market price. Do NOT identify premium value. Do NOT decide routing.\n\n` +
    `The photos show a product${productName ? ` described as "${productName}"` : ""}${category ? ` in the category "${category}"` : ""}.\n` +
    `normalizedPrice is the fair like-new reference price for this exact model. You only decide what fraction of normalizedPrice this visible unit is worth.\n\n` +
    `GRADING RULES — read carefully, all rules apply:\n\n` +
    `RULE A — LIKE NEW (positive signals, grade UP if present):\n` +
    `If you clearly see ANY of the following, you MUST grade "Like New" (score 0.90-1.00):\n` +
    `- Original sealed or unopened packaging with intact seals/shrink wrap.\n` +
    `- Tags, labels, or stickers clearly still attached and unremoved.\n` +
    `- Factory protective film still on screen or body.\n` +
    `- Zero visible wear, scratches, scuffs, creasing, stains, or marks.\n` +
    `- Accessories or manuals still in original bags/boxes.\n` +
    `Do NOT let "be conservative" override these clear Like-New signals. If the item looks genuinely unused, grade it "Like New".\n\n` +
    `Condition definitions (apply only after checking Rule A above):\n` +
    `- "Like New": virtually no visible wear; clean, intact, close to unused; no cracks, dents, tears, stains, scratches, missing parts, or deformation. Includes items that appear genuinely unused even without original packaging.\n` +
    `- "Good": light wear only; minor scuffs, small scratches, light creasing, or mild use; no serious damage.\n` +
    `- "Used": clearly used; noticeable wear, dirt, fading, stains, scratches, creasing, aging, or cosmetic deterioration; still intact and usable.\n` +
    `- "Damaged": any serious defect, including cracked/shattered glass, broken frame, major dents, torn fabric, holes, missing pieces, detached sole/strap/handle, exposed wiring, severe stains, deformation, or structural damage.\n\n` +
    `RULE B — DAMAGE (hard override, grade DOWN if present):\n` +
    `1. If you see cracked glass, shattered screen, broken frame, torn fabric, holes, missing parts, major dents, detached sole, exposed wiring, or structural damage, you MUST choose "Damaged".\n` +
    `2. If multiple moderate defects are visible, do NOT choose "Good"; choose "Used" or "Damaged".\n` +
    `3. Brand/model value must not improve condition. A premium product with visible damage is still Damaged.\n` +
    `4. For severe damage, choose "Damaged" and set priceMultiplier between 0.10 and 0.20.\n\n` +
    `RULE C — PHOTO QUALITY:\n` +
    `If photos are blurry, dark, incomplete, or key areas are missing, reduce confidence (set confidence <= 0.6) but do not automatically downgrade condition if what IS visible looks clean.\n\n` +
    `Assign:\n` +
    `- conditionScore: number between 0 and 1. 1 = perfect, <= 0.25 = very badly damaged.\n` +
    `- priceMultiplier: fraction of normalizedPrice within the allowed band:\n` +
    `  Like New: 0.80-1.00\n  Good: 0.60-0.80\n  Used: 0.40-0.60\n  Damaged: 0.10-0.30\n\n` +
    `Respond with ONLY a JSON object. No markdown. No extra text.\n` +
    `{"condition": "<Like New|Good|Used|Damaged>","conditionScore": <0-1>,"priceMultiplier": <fraction>,"confidence": <0-1>,"visibleIssues": ["<short visible issue>"],"reasoning": "<one concise sentence explaining what you saw and why it justifies this condition>"}`;

  const content = images.map((img) => ({
    image: { format: img.format, source: { bytes: img.bytes } },
  }));
  content.push({ text: promptText });

  let raw;
  try {
    const resp = await bedrock.send(
      new ConverseCommand({
        modelId: MODEL_ID,
        messages: [{ role: "user", content }],
        inferenceConfig: { maxTokens: 300, temperature: 0.15, topP: 0.1 },
      })
    );
    raw = resp?.output?.message?.content?.[0]?.text ?? "";
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

    let conditionConfidence = Number(parsed.confidence);
    conditionConfidence = Number.isNaN(conditionConfidence)
      ? null
      : Math.max(0, Math.min(1, conditionConfidence));

    const visibleIssues = Array.isArray(parsed.visibleIssues)
      ? parsed.visibleIssues
          .map((s) => String(s).trim())
          .filter((s) => s.length > 0 && s.length < 160)
          .slice(0, 8)
      : [];

    const conditionReason = (parsed.reasoning || parsed.reason || "").toString();
    return {
      condition,
      conditionScore,
      priceMultiplier,
      conditionReason,
      conditionConfidence,
      visibleIssues,
    };
  } catch (e) {
    console.error(`Failed to parse model output: ${raw}`);
    return null;
  }
}

/**
 * Computes the estimated resale value. Uses the model's priceMultiplier, but
 * clamps it into the allowed band for the chosen condition as a safety net,
 * then rounds to the nearest 10.
 *
 * RULE: If the item is Damaged, it goes straight to Recycle — no resale value.
 */
function computeResaleValue(normalizedPrice, condition, priceMultiplier) {
  // Damaged items have no resale value — they go to Recycle directly.
  if (condition === "Damaged") {
    return { estimatedResaleValue: 0, appliedMultiplier: 0 };
  }

  const range = CONDITION_RANGE[condition] || [0.4, 0.6];
  const [lo, hi] = range;
  let m = Number(priceMultiplier);
  if (Number.isNaN(m)) m = (lo + hi) / 2;
  m = Math.max(lo, Math.min(hi, m));
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
    const img = await fetchImageBytes(url);
    if (img) images.push(img);
  }

  // 3. Grade condition with the vision model
  const graded = await gradeWithVision({
    images,
    productName: item.productName,
    category: item.category,
  });

  let condition, conditionReason, conditionScore, priceMultiplier;
  let conditionConfidence = null;
  let visibleIssues = [];
  if (graded) {
    condition = graded.condition;
    conditionReason = graded.conditionReason || `Graded "${graded.condition}" from photo analysis.`;
    conditionScore = graded.conditionScore;
    priceMultiplier = graded.priceMultiplier;
    conditionConfidence = graded.conditionConfidence ?? null;
    visibleIssues = Array.isArray(graded.visibleIssues) ? graded.visibleIssues : [];
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
    // Build the update expression dynamically so optional fields are only
    // written when we actually have them.
    const setParts = [
      "#cond = :c",
      "conditionReason = :cr",
      "conditionScore = :cs",
      "priceMultiplier = :pm",
      "estimatedResaleValue = :erv",
      "visibleIssues = :vi",
    ];
    const exprVals = {
      ":c": condition,
      ":cr": conditionReason,
      ":cs": conditionScore,
      ":pm": appliedMultiplier,
      ":erv": estimatedResaleValue,
      ":vi": visibleIssues,
    };
    if (bestPhotoIndex != null) {
      setParts.push("bestPhotoIndex = :bpi");
      exprVals[":bpi"] = bestPhotoIndex;
    }
    if (conditionConfidence != null) {
      setParts.push("conditionConfidence = :cc");
      exprVals[":cc"] = conditionConfidence;
    }

    await ddb.send(
      new UpdateCommand({
        TableName: EVALUATIONS_TABLE,
        Key: { evaluationId },
        UpdateExpression: "SET " + setParts.join(", "),
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
    conditionConfidence,
    visibleIssues,
    priceMultiplier: appliedMultiplier,
    estimatedResaleValue,
    bestPhotoIndex,
  });
};

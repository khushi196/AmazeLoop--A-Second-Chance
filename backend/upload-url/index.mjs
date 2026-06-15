/**
 * AmazeLoopUploadUrlFunction
 *
 * Generates a presigned S3 PUT URL so the Flutter client can upload a photo
 * directly to the photos bucket. Returns both the upload URL (for the PUT) and
 * the final object URL (to store as a photoUrl on the evaluation).
 *
 * Request:  { "fileName": "front.jpg", "contentType": "image/jpeg" }
 * Response: { "uploadUrl": "...", "fileUrl": "https://<bucket>.s3.<region>.amazonaws.com/<key>" }
 */

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomUUID } from "crypto";

const REGION = process.env.AWS_REGION || "ap-south-1";
const PHOTO_BUCKET = process.env.PHOTO_BUCKET || "amazeloop-photos-191918535218";

const s3 = new S3Client({
  region: REGION,
  // Avoid auto-injected checksum params that break browser presigned PUT uploads
  requestChecksumCalculation: "WHEN_REQUIRED",
});

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

  // Require an authenticated seller (JWT authorizer claims) before issuing a
  // presigned upload URL.
  const claims =
    event?.requestContext?.authorizer?.jwt?.claims ||
    event?.requestContext?.authorizer?.claims ||
    {};
  if (!claims.sub) return response(401, { error: "Authentication required." });
  if (claims["custom:role"] !== "customer" && claims["custom:role"] !== "warehouse") {
    return response(403, { error: "Not authorized for seller actions." });
  }

  const fileName = (body.fileName || "photo.jpg").replace(/[^a-zA-Z0-9._-]/g, "_");
  const contentType = body.contentType || "image/jpeg";

  const key = `uploads/${randomUUID()}-${fileName}`;

  try {
    const command = new PutObjectCommand({
      Bucket: PHOTO_BUCKET,
      Key: key,
      ContentType: contentType,
    });

    // Presigned URL valid for 5 minutes
    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });
    const fileUrl = `https://${PHOTO_BUCKET}.s3.${REGION}.amazonaws.com/${key}`;

    return response(200, { uploadUrl, fileUrl });
  } catch (e) {
    return response(500, { error: "Failed to create upload URL.", detail: e.message });
  }
};

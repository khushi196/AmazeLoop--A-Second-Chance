#!/usr/bin/env bash
# Deploy the built Flutter web bundle (build/web) to the Amplify 'main' branch
# via Amplify manual deployment (the app is not repo-connected / auto-build).
set -eo pipefail
REGION=ap-south-1
APPID=dvgnadzqug12z
BRANCH=main
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$ROOT/build/web/index.html" ]; then
  echo "ERROR: build/web/index.html not found — run 'flutter build web --release' first" >&2
  exit 1
fi

echo "Zipping build/web ..."
( cd "$ROOT/build/web" && rm -f "$ROOT/build/web_deploy.zip" && zip -rqX "$ROOT/build/web_deploy.zip" . )

echo "Creating Amplify deployment ..."
OUT=$(aws amplify create-deployment --app-id "$APPID" --branch-name "$BRANCH" --region "$REGION")
JOB=$(printf '%s' "$OUT" | python3 -c "import sys,json;print(json.load(sys.stdin)['jobId'])")
URL=$(printf '%s' "$OUT" | python3 -c "import sys,json;print(json.load(sys.stdin)['zipUploadUrl'])")
echo "jobId: $JOB"

echo "Uploading bundle ..."
curl -s -H "Content-Type: application/zip" --upload-file "$ROOT/build/web_deploy.zip" "$URL"

echo "Starting deployment ..."
aws amplify start-deployment --app-id "$APPID" --branch-name "$BRANCH" --job-id "$JOB" --region "$REGION" \
  --query 'jobSummary.status' --output text

# Poll for completion
for i in $(seq 1 40); do
  sleep 6
  ST=$(aws amplify get-job --app-id "$APPID" --branch-name "$BRANCH" --job-id "$JOB" --region "$REGION" --query 'job.summary.status' --output text)
  echo "  status: $ST"
  case "$ST" in
    SUCCEED) echo "DEPLOY SUCCEEDED"; break ;;
    FAILED|CANCELLED) echo "DEPLOY $ST"; exit 1 ;;
  esac
done
rm -f "$ROOT/build/web_deploy.zip"
echo "Live at: https://$BRANCH.$APPID.amplifyapp.com"

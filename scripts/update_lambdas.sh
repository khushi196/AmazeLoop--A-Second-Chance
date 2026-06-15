#!/usr/bin/env bash
# Update code for the modified Lambdas. SDK-only functions, so we package just
# index.mjs + package.json (the nodejs20.x runtime provides @aws-sdk v3).
set -eo pipefail
REGION=ap-south-1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PAIRS="
feedback:AmazeLoopFeedbackFunction
route-confirm:AmazeLoopRouteConfirmFunction
purchase:AmazeLoopPurchaseFunction
listings:AmazeLoopListingsFunction
listing-detail:AmazeLoopListingDetailFunction
evaluations-list:AmazeLoopEvalListFunction
purchases:AmazeLoopMyPurchasesFunction
"

for pair in $PAIRS; do
  dir="${pair%%:*}"
  fn="${pair##*:}"
  d="$ROOT/backend/$dir"
  echo "=== $dir -> $fn ==="
  ( cd "$d" && rm -f deploy.zip && zip -q deploy.zip index.mjs package.json )
  aws lambda update-function-code \
    --function-name "$fn" \
    --zip-file "fileb://$d/deploy.zip" \
    --region "$REGION" \
    --query 'LastUpdateStatus' --output text
  rm -f "$d/deploy.zip"
done
echo "ALL UPDATES SUBMITTED"

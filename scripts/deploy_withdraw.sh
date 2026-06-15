#!/usr/bin/env bash
# Create + wire the new AmazeLoopListingWithdrawFunction (POST /listings/withdraw).
set -eo pipefail
REGION=ap-south-1
ACCT=191918535218
API=bu719hnik3
FN=AmazeLoopListingWithdrawFunction
ROLE=AmazeLoopListingWithdrawFunctionRole
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/backend/listing-withdraw"

# 1. Role (create if missing) ------------------------------------------------
if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  echo "Creating role $ROLE"
  cat > /tmp/trust.json <<'EOF'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
  aws iam create-role --role-name "$ROLE" \
    --assume-role-policy-document file:///tmp/trust.json >/dev/null
  aws iam attach-role-policy --role-name "$ROLE" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole >/dev/null
  aws iam put-role-policy --role-name "$ROLE" \
    --policy-name AmazeLoopListingWithdrawPolicy \
    --policy-document "file://$D/policy.json" >/dev/null
  echo "Waiting 12s for role propagation..."
  sleep 12
else
  echo "Role $ROLE already exists"
fi

# 2. Package + create function (create if missing, else update) --------------
( cd "$D" && rm -f deploy.zip && zip -q deploy.zip index.mjs package.json )
if aws lambda get-function --function-name "$FN" --region "$REGION" >/dev/null 2>&1; then
  echo "Function exists -> updating code"
  aws lambda update-function-code --function-name "$FN" \
    --zip-file "fileb://$D/deploy.zip" --region "$REGION" \
    --query 'LastUpdateStatus' --output text
else
  echo "Creating function $FN"
  aws lambda create-function --function-name "$FN" \
    --runtime nodejs20.x --handler index.handler \
    --role "arn:aws:iam::$ACCT:role/$ROLE" \
    --zip-file "fileb://$D/deploy.zip" \
    --timeout 15 --memory-size 256 --region "$REGION" \
    --query 'State' --output text
fi
rm -f "$D/deploy.zip"

# 3. API Gateway integration + route + invoke permission ---------------------
LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCT:function:$FN"

# Skip if the route already exists.
if aws apigatewayv2 get-routes --api-id "$API" --region "$REGION" \
     --query "Items[?RouteKey=='POST /listings/withdraw'].RouteId" --output text | grep -q .; then
  echo "Route POST /listings/withdraw already exists — skipping wiring"
else
  echo "Creating integration"
  INTEG=$(aws apigatewayv2 create-integration --api-id "$API" --region "$REGION" \
    --integration-type AWS_PROXY --integration-uri "$LAMBDA_ARN" \
    --integration-method POST --payload-format-version 2.0 \
    --query 'IntegrationId' --output text)
  echo "Integration: $INTEG"
  aws apigatewayv2 create-route --api-id "$API" --region "$REGION" \
    --route-key "POST /listings/withdraw" \
    --target "integrations/$INTEG" \
    --query 'RouteId' --output text
  echo "Adding invoke permission"
  aws lambda add-permission --function-name "$FN" --region "$REGION" \
    --statement-id apigw-withdraw-invoke --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$ACCT:$API/*/*/listings/withdraw" \
    --query 'Statement' --output text >/dev/null || true
fi

echo "WITHDRAW DEPLOY DONE"

#!/bin/bash
# Isengard-compliant deployment - NO open policies
set -e

REGION="us-east-1"
FUNCTION_NAME="sql-converter-api"
ROLE_NAME="sql-converter-lambda-role-secure"
API_NAME="sql-converter-api-secure"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Isengard-Compliant Deployment ==="
echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# 1. Create IAM role with least-privilege
echo "[1/5] Creating secure IAM role..."
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "  Role exists, continuing..."

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

# Create Bedrock invoke-only policy
BEDROCK_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/sql-converter-bedrock-invoke"
aws iam create-policy \
  --policy-name sql-converter-bedrock-invoke \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["bedrock:InvokeModel"],
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-pro-v1:0",
        "arn:aws:bedrock:us-east-1::foundation-model/us.anthropic.claude-*"
      ]
    }]
  }' 2>/dev/null || echo "  Bedrock policy exists"

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $BEDROCK_POLICY_ARN 2>/dev/null || true

echo "  Waiting for IAM propagation..."
sleep 10

# 2. Deploy Lambda function
echo "[2/5] Deploying Lambda function..."
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/$ROLE_NAME"

if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION >/dev/null 2>&1; then
    aws lambda update-function-code \
      --function-name $FUNCTION_NAME \
      --zip-file fileb://backend/lambda.zip \
      --region $REGION >/dev/null
    
    aws lambda update-function-configuration \
      --function-name $FUNCTION_NAME \
      --role $ROLE_ARN \
      --timeout 120 \
      --memory-size 512 \
      --region $REGION >/dev/null
else
    aws lambda create-function \
      --function-name $FUNCTION_NAME \
      --runtime python3.11 \
      --role $ROLE_ARN \
      --handler lambda_handler.handler \
      --zip-file fileb://backend/lambda.zip \
      --timeout 120 \
      --memory-size 512 \
      --region $REGION >/dev/null
fi

aws lambda put-function-concurrency \
  --function-name $FUNCTION_NAME \
  --reserved-concurrent-executions 10 \
  --region $REGION >/dev/null

echo "  ✓ Lambda deployed with concurrency limit"

# 3. Remove any existing open permissions
echo "[3/5] Removing open permissions..."
aws lambda remove-permission \
  --function-name $FUNCTION_NAME \
  --statement-id apigateway-invoke \
  --region $REGION 2>/dev/null || echo "  No existing permissions to remove"

# 4. Create API Gateway with specific source ARN
echo "[4/5] Creating API Gateway..."
API_ID=$(aws apigatewayv2 get-apis --region $REGION --query "Items[?Name=='$API_NAME'].ApiId" --output text)

if [ -z "$API_ID" ]; then
    API_ID=$(aws apigatewayv2 create-api \
      --name $API_NAME \
      --protocol-type HTTP \
      --region $REGION \
      --query 'ApiId' \
      --output text)
fi

# Create integration
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id $API_ID \
  --integration-type AWS_PROXY \
  --integration-uri "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}" \
  --payload-format-version 2.0 \
  --region $REGION \
  --query 'IntegrationId' \
  --output text 2>/dev/null || \
  aws apigatewayv2 get-integrations --api-id $API_ID --region $REGION --query 'Items[0].IntegrationId' --output text)

# Create routes
for route in "POST /convert" "GET /models" "GET /health"; do
  aws apigatewayv2 create-route \
    --api-id $API_ID \
    --route-key "$route" \
    --target "integrations/$INTEGRATION_ID" \
    --region $REGION 2>/dev/null || echo "  Route $route exists"
done

# Create $default stage
aws apigatewayv2 create-stage \
  --api-id $API_ID \
  --stage-name '$default' \
  --auto-deploy \
  --region $REGION 2>/dev/null || echo "  Stage exists"

API_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com"
echo "  ✓ API Gateway: $API_ENDPOINT"

# 5. Add Lambda permission ONLY for this specific API
echo "[5/5] Adding restricted Lambda permission..."
aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id apigateway-invoke-secure \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
  --region $REGION 2>/dev/null || echo "  Permission already exists"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "API Endpoint: $API_ENDPOINT"
echo ""
echo "Security features:"
echo "  ✓ No open Lambda policies"
echo "  ✓ API Gateway-specific source ARN"
echo "  ✓ Least-privilege IAM (InvokeModel only)"
echo "  ✓ Concurrency limit (10)"
echo ""
echo "Test the API:"
echo "  curl $API_ENDPOINT/health"
echo ""

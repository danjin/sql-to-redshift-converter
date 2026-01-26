#!/bin/bash
set -e

REGION="us-east-1"
FUNCTION_NAME="sql-converter-api"
ROLE_NAME="sql-converter-lambda-role"
API_NAME="sql-converter-api"
BUCKET_NAME="sql-converter-frontend-$(date +%s)"

echo "=== Deploying SQL Converter to AWS ==="

# 1. Create IAM role for Lambda
echo "Creating IAM role..."
ROLE_ARN=$(aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }' \
    --query 'Role.Arn' \
    --output text 2>/dev/null || aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

echo "✓ Role ARN: $ROLE_ARN"

# Attach policies
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess 2>/dev/null || true

echo "Waiting for IAM role to propagate..."
sleep 10

# 2. Create Lambda function
echo "Creating Lambda function..."
cd backend

aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.11 \
    --role $ROLE_ARN \
    --handler lambda_handler.handler \
    --zip-file fileb://lambda.zip \
    --timeout 60 \
    --memory-size 512 \
    --region $REGION 2>/dev/null || \
aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://lambda.zip \
    --region $REGION

echo "✓ Lambda function created/updated"

cd ..

# 3. Create API Gateway
echo "Creating API Gateway..."
API_ID=$(aws apigatewayv2 create-api \
    --name $API_NAME \
    --protocol-type HTTP \
    --target arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$FUNCTION_NAME \
    --region $REGION \
    --query 'ApiId' \
    --output text 2>/dev/null || \
aws apigatewayv2 get-apis --region $REGION --query "Items[?Name=='$API_NAME'].ApiId" --output text)

echo "✓ API ID: $API_ID"

# Add Lambda permission for API Gateway
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*" \
    --region $REGION 2>/dev/null || true

API_ENDPOINT="https://$API_ID.execute-api.$REGION.amazonaws.com"
echo "✓ API Endpoint: $API_ENDPOINT"

# 4. Deploy frontend to S3
echo "Creating S3 bucket for frontend..."
aws s3 mb s3://$BUCKET_NAME --region $REGION 2>/dev/null || true

# Update API URL in frontend
sed "s|API_GATEWAY_URL_HERE|$API_ENDPOINT|g" frontend/index.html > frontend/index_deploy.html

# Upload to S3
aws s3 cp frontend/index_deploy.html s3://$BUCKET_NAME/index.html --content-type "text/html"

# Enable static website hosting
aws s3 website s3://$BUCKET_NAME --index-document index.html

# Make bucket public
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
        \"Sid\": \"PublicReadGetObject\",
        \"Effect\": \"Allow\",
        \"Principal\": \"*\",
        \"Action\": \"s3:GetObject\",
        \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
    }]
}"

WEBSITE_URL="http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"

echo ""
echo "=== Deployment Complete ==="
echo "Frontend URL: $WEBSITE_URL"
echo "API Endpoint: $API_ENDPOINT"
echo ""
echo "Save these URLs for future reference!"

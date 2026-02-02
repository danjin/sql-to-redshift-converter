#!/bin/bash
# Secure deployment for Isengard accounts
set -e

REGION="us-east-1"
FUNCTION_NAME="sql-converter-api"
ROLE_NAME="sql-converter-lambda-role-secure"

echo "Creating secure IAM role with least-privilege permissions..."

# Create IAM role
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists"

# Attach basic Lambda execution role
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create least-privilege Bedrock policy (only InvokeModel, no admin actions)
BEDROCK_POLICY=$(aws iam create-policy \
  --policy-name sql-converter-bedrock-invoke-only \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-pro-v1:0",
        "arn:aws:bedrock:us-east-1::foundation-model/us.anthropic.claude-haiku-4-5-*",
        "arn:aws:bedrock:us-east-1::foundation-model/us.anthropic.claude-opus-4-5-*"
      ]
    }]
  }' \
  --query 'Policy.Arn' \
  --output text 2>/dev/null) || BEDROCK_POLICY="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/sql-converter-bedrock-invoke-only"

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $BEDROCK_POLICY

# Create least-privilege DynamoDB policy (only for features table)
DYNAMODB_POLICY=$(aws iam create-policy \
  --policy-name sql-converter-dynamodb-features \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/sql-converter-features"
    }]
  }' \
  --query 'Policy.Arn' \
  --output text 2>/dev/null) || DYNAMODB_POLICY="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/sql-converter-dynamodb-features"

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $DYNAMODB_POLICY

echo "Waiting for IAM role to propagate..."
sleep 10

# Build Lambda package
cd backend
zip -q lambda.zip lambda_handler.py
cd ..

# Create or update Lambda function with security best practices
ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$ROLE_NAME"

if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION >/dev/null 2>&1; then
    echo "Updating existing Lambda function..."
    aws lambda update-function-code \
      --function-name $FUNCTION_NAME \
      --zip-file fileb://backend/lambda.zip \
      --region $REGION
    
    aws lambda update-function-configuration \
      --function-name $FUNCTION_NAME \
      --role $ROLE_ARN \
      --timeout 120 \
      --memory-size 512 \
      --tracing-config Mode=Active \
      --region $REGION
    
    # Set reserved concurrency separately
    aws lambda put-function-concurrency \
      --function-name $FUNCTION_NAME \
      --reserved-concurrent-executions 10 \
      --region $REGION
else
    echo "Creating new Lambda function..."
    aws lambda create-function \
      --function-name $FUNCTION_NAME \
      --runtime python3.11 \
      --role $ROLE_ARN \
      --handler lambda_handler.handler \
      --zip-file fileb://backend/lambda.zip \
      --timeout 120 \
      --memory-size 512 \
      --tracing-config Mode=Active \
      --region $REGION
    
    # Set reserved concurrency separately
    aws lambda put-function-concurrency \
      --function-name $FUNCTION_NAME \
      --reserved-concurrent-executions 10 \
      --region $REGION
fi

echo ""
echo "✓ Secure Lambda deployment complete!"
echo ""
echo "Security features enabled:"
echo "  - Least-privilege IAM (InvokeModel only, no Bedrock admin)"
echo "  - Reserved concurrency limit (10)"
echo "  - X-Ray tracing enabled"
echo "  - Specific model ARNs only"
echo ""
echo "Next: Update API Gateway integration if needed"

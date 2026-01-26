#!/bin/bash
set -e

REGION="us-east-1"
KB_BUCKET="sql-converter-kb-docs-$(date +%s)"
KB_NAME="redshift-sql-converter-kb"
COLLECTION_NAME="redshift-docs-vector"

echo "🚀 Setting up Full RAG with Bedrock Knowledge Base..."
echo ""

# Step 1: Create S3 bucket for documentation
echo "📦 Step 1: Creating S3 bucket for documentation..."
aws s3 mb s3://$KB_BUCKET --region $REGION
echo "✅ Created bucket: $KB_BUCKET"
echo ""

# Step 2: Create OpenSearch Serverless collection
echo "🔍 Step 2: Creating OpenSearch Serverless collection..."
echo "   This will take 5-10 minutes..."

# Create encryption policy
aws opensearchserverless create-security-policy \
  --name ${COLLECTION_NAME}-encryption \
  --type encryption \
  --policy "{\"Rules\":[{\"ResourceType\":\"collection\",\"Resource\":[\"collection/${COLLECTION_NAME}\"]}],\"AWSOwnedKey\":true}" \
  --region $REGION 2>/dev/null || echo "   Encryption policy already exists"

# Create network policy
aws opensearchserverless create-security-policy \
  --name ${COLLECTION_NAME}-network \
  --type network \
  --policy "[{\"Rules\":[{\"ResourceType\":\"collection\",\"Resource\":[\"collection/${COLLECTION_NAME}\"]},{\"ResourceType\":\"dashboard\",\"Resource\":[\"collection/${COLLECTION_NAME}\"]}],\"AllowFromPublic\":true}]" \
  --region $REGION 2>/dev/null || echo "   Network policy already exists"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create data access policy
aws opensearchserverless create-access-policy \
  --name ${COLLECTION_NAME}-access \
  --type data \
  --policy "[{\"Rules\":[{\"ResourceType\":\"collection\",\"Resource\":[\"collection/${COLLECTION_NAME}\"],\"Permission\":[\"aoss:*\"]},{\"ResourceType\":\"index\",\"Resource\":[\"index/${COLLECTION_NAME}/*\"],\"Permission\":[\"aoss:*\"]}],\"Principal\":[\"arn:aws:iam::${ACCOUNT_ID}:root\"]}]" \
  --region $REGION 2>/dev/null || echo "   Access policy already exists"

# Create collection
COLLECTION_ID=$(aws opensearchserverless create-collection \
  --name $COLLECTION_NAME \
  --type VECTORSEARCH \
  --region $REGION \
  --query 'createCollectionDetail.id' \
  --output text 2>/dev/null || echo "exists")

if [ "$COLLECTION_ID" != "exists" ]; then
  echo "   Created collection: $COLLECTION_ID"
  echo "   Waiting for collection to become active..."
  sleep 60
else
  echo "   Collection already exists"
  COLLECTION_ID=$(aws opensearchserverless list-collections \
    --region $REGION \
    --query "collectionSummaries[?name=='$COLLECTION_NAME'].id" \
    --output text)
fi

echo "✅ OpenSearch Serverless collection ready"
echo ""

# Step 3: Create IAM role for Knowledge Base
echo "🔐 Step 3: Creating IAM role for Knowledge Base..."

ROLE_NAME="BedrockKnowledgeBaseRole-SQLConverter"

# Create trust policy
cat > /tmp/kb-trust-policy.json << TRUST
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "bedrock.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
TRUST

# Create role
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file:///tmp/kb-trust-policy.json \
  --region $REGION 2>/dev/null || echo "   Role already exists"

# Create permissions policy
cat > /tmp/kb-permissions.json << PERMS
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${KB_BUCKET}",
        "arn:aws:s3:::${KB_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "aoss:APIAccessAll"
      ],
      "Resource": "arn:aws:aoss:${REGION}:${ACCOUNT_ID}:collection/${COLLECTION_ID}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "arn:aws:bedrock:${REGION}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  ]
}
PERMS

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name KnowledgeBasePermissions \
  --policy-document file:///tmp/kb-permissions.json \
  --region $REGION

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "✅ Created role: $ROLE_ARN"
echo ""

# Wait for role to propagate
echo "⏳ Waiting for IAM role to propagate (30 seconds)..."
sleep 30

# Step 4: Save configuration
cat > infrastructure/kb-config.json << CONFIG
{
  "kb_bucket": "$KB_BUCKET",
  "kb_name": "$KB_NAME",
  "collection_name": "$COLLECTION_NAME",
  "collection_id": "$COLLECTION_ID",
  "role_arn": "$ROLE_ARN",
  "region": "$REGION",
  "account_id": "$ACCOUNT_ID"
}
CONFIG

echo "✅ Configuration saved to infrastructure/kb-config.json"
echo ""
echo "📝 Next steps:"
echo "   1. Run: ./infrastructure/download-docs.sh (downloads Redshift docs)"
echo "   2. Run: ./infrastructure/create-knowledge-base.sh (creates KB)"
echo "   3. Update Lambda to use Knowledge Base"
echo ""
echo "💰 Estimated monthly cost: ~$700"
echo "   - OpenSearch Serverless: ~$500"
echo "   - Bedrock KB storage: ~$200"
echo "   - S3 storage: ~$1"

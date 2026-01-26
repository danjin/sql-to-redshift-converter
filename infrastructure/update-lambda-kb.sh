#!/bin/bash
set -e

# Load configuration
if [ ! -f infrastructure/kb-config.json ]; then
  echo "❌ Error: kb-config.json not found. Run setup-knowledge-base.sh first."
  exit 1
fi

KB_ID=$(jq -r '.kb_id' infrastructure/kb-config.json)
REGION=$(jq -r '.region' infrastructure/kb-config.json)

echo "🔄 Updating Lambda to use Knowledge Base..."
echo ""

# Backup current Lambda handler
cp backend/lambda_handler.py backend/lambda_handler_hybrid.py
echo "✅ Backed up current handler to lambda_handler_hybrid.py"

# Replace with KB handler
cp backend/lambda_handler_kb.py backend/lambda_handler.py
echo "✅ Switched to Knowledge Base handler"

# Build Lambda package
echo "📦 Building Lambda package..."
cd backend
zip -q lambda.zip lambda_handler.py
cd ..

# Update Lambda function code
echo "☁️  Updating Lambda function..."
aws lambda update-function-code \
  --function-name sql-converter-api \
  --zip-file fileb://backend/lambda.zip \
  --region $REGION \
  --output text > /dev/null

# Update Lambda environment variables
echo "⚙️  Setting Knowledge Base ID..."
aws lambda update-function-configuration \
  --function-name sql-converter-api \
  --environment "Variables={KNOWLEDGE_BASE_ID=$KB_ID}" \
  --region $REGION \
  --output text > /dev/null

# Add KB permissions to Lambda role
echo "🔐 Adding Knowledge Base permissions to Lambda role..."

LAMBDA_ROLE=$(aws lambda get-function \
  --function-name sql-converter-api \
  --region $REGION \
  --query 'Configuration.Role' \
  --output text)

ROLE_NAME=$(echo $LAMBDA_ROLE | awk -F'/' '{print $NF}')

cat > /tmp/kb-lambda-policy.json << POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:Retrieve",
        "bedrock:RetrieveAndGenerate"
      ],
      "Resource": "arn:aws:bedrock:${REGION}:*:knowledge-base/${KB_ID}"
    }
  ]
}
POLICY

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name KnowledgeBaseAccess \
  --policy-document file:///tmp/kb-lambda-policy.json

echo "✅ Permissions added"

# Wait for Lambda to update
echo "⏳ Waiting for Lambda to update (10 seconds)..."
sleep 10

echo ""
echo "✅ Lambda updated to use Full RAG with Knowledge Base!"
echo ""
echo "📊 Configuration:"
echo "   Knowledge Base ID: $KB_ID"
echo "   Lambda Function: sql-converter-api"
echo "   RAG Type: Full RAG (semantic search)"
echo ""
echo "🧪 Test the API:"
echo "   curl -X POST https://YOUR-API-URL/convert \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"source_db\": \"Snowflake\", \"sql\": \"SELECT * FROM t QUALIFY row_number() OVER (ORDER BY id) = 1\", \"model\": \"amazon.nova-pro-v1:0\"}'"
echo ""
echo "💡 To switch back to Hybrid RAG:"
echo "   cp backend/lambda_handler_hybrid.py backend/lambda_handler.py"
echo "   ./infrastructure/build.sh && aws lambda update-function-code ..."

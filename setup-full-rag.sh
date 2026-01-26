#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Full RAG Setup for SQL Converter                          ║"
echo "║  Upgrade from Hybrid RAG to Knowledge Base                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  WARNING: This will cost approximately $700/month"
echo ""
echo "📊 Cost Breakdown:"
echo "   - OpenSearch Serverless: ~$500/month"
echo "   - Bedrock KB Storage: ~$200/month"
echo "   - S3 Storage: ~$1/month"
echo ""
echo "💡 Current Hybrid RAG costs: $0.26/month"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "❌ Setup cancelled"
  exit 0
fi

echo ""
echo "🚀 Starting Full RAG setup..."
echo ""

# Check prerequisites
echo "✓ Checking prerequisites..."
command -v jq >/dev/null 2>&1 || { echo "❌ jq is required but not installed. Install with: brew install jq"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed."; exit 1; }

# Step 1: Setup infrastructure
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/4: Setting up infrastructure (10-15 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./infrastructure/setup-knowledge-base.sh

# Step 2: Download documentation
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/4: Downloading Redshift documentation (2-3 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./infrastructure/download-docs.sh

# Step 3: Create Knowledge Base
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/4: Creating Knowledge Base (10-15 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./infrastructure/create-knowledge-base.sh

# Step 4: Update Lambda
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4/4: Updating Lambda function (1 minute)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./infrastructure/update-lambda-kb.sh

# Get API URL
API_URL=$(aws apigatewayv2 get-apis --region us-east-1 --query "Items[?Name=='sql-converter-api'].ApiEndpoint" --output text)

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ Full RAG Setup Complete!                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Configuration:"
KB_ID=$(jq -r '.kb_id' infrastructure/kb-config.json)
echo "   Knowledge Base ID: $KB_ID"
echo "   RAG Type: Full RAG (semantic search)"
echo "   API URL: $API_URL"
echo ""
echo "🧪 Test your setup:"
echo ""
echo "   curl -X POST $API_URL/convert \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{"
echo "       \"source_db\": \"Snowflake\","
echo "       \"sql\": \"SELECT * FROM t QUALIFY rank = 1\","
echo "       \"model\": \"amazon.nova-pro-v1:0\""
echo "     }'"
echo ""
echo "💰 Monthly Cost: ~$700"
echo ""
echo "💡 To switch back to Hybrid RAG ($0.26/month):"
echo "   cp backend/lambda_handler_hybrid.py backend/lambda_handler.py"
echo "   ./infrastructure/build.sh"
echo "   aws lambda update-function-code --function-name sql-converter-api --zip-file fileb://backend/lambda.zip"
echo ""
echo "📚 Full documentation: FULL_RAG_SETUP.md"

#!/bin/bash
set -e

# Load configuration
if [ ! -f infrastructure/kb-config.json ]; then
  echo "❌ Error: kb-config.json not found. Run setup-knowledge-base.sh first."
  exit 1
fi

KB_BUCKET=$(jq -r '.kb_bucket' infrastructure/kb-config.json)
KB_NAME=$(jq -r '.kb_name' infrastructure/kb-config.json)
COLLECTION_NAME=$(jq -r '.collection_name' infrastructure/kb-config.json)
ROLE_ARN=$(jq -r '.role_arn' infrastructure/kb-config.json)
REGION=$(jq -r '.region' infrastructure/kb-config.json)
ACCOUNT_ID=$(jq -r '.account_id' infrastructure/kb-config.json)

echo "🧠 Creating Bedrock Knowledge Base..."
echo ""

# Get OpenSearch collection endpoint
COLLECTION_ENDPOINT=$(aws opensearchserverless batch-get-collection \
  --names $COLLECTION_NAME \
  --region $REGION \
  --query 'collectionDetails[0].collectionEndpoint' \
  --output text)

echo "📍 Collection endpoint: $COLLECTION_ENDPOINT"

# Create Knowledge Base
echo "🔨 Creating Knowledge Base..."

KB_CONFIG=$(cat <<CONFIG
{
  "type": "VECTOR",
  "vectorKnowledgeBaseConfiguration": {
    "embeddingModelArn": "arn:aws:bedrock:${REGION}::foundation-model/amazon.titan-embed-text-v2:0"
  }
}
CONFIG
)

STORAGE_CONFIG=$(cat <<STORAGE
{
  "type": "OPENSEARCH_SERVERLESS",
  "opensearchServerlessConfiguration": {
    "collectionArn": "arn:aws:aoss:${REGION}:${ACCOUNT_ID}:collection/${COLLECTION_NAME}",
    "vectorIndexName": "redshift-docs-index",
    "fieldMapping": {
      "vectorField": "vector",
      "textField": "text",
      "metadataField": "metadata"
    }
  }
}
STORAGE
)

KB_ID=$(aws bedrock-agent create-knowledge-base \
  --name "$KB_NAME" \
  --role-arn "$ROLE_ARN" \
  --knowledge-base-configuration "$KB_CONFIG" \
  --storage-configuration "$STORAGE_CONFIG" \
  --region $REGION \
  --query 'knowledgeBase.knowledgeBaseId' \
  --output text 2>/dev/null || echo "exists")

if [ "$KB_ID" = "exists" ]; then
  echo "   Knowledge Base already exists, getting ID..."
  KB_ID=$(aws bedrock-agent list-knowledge-bases \
    --region $REGION \
    --query "knowledgeBaseSummaries[?name=='$KB_NAME'].knowledgeBaseId" \
    --output text)
fi

echo "✅ Knowledge Base ID: $KB_ID"

# Create Data Source
echo "📂 Creating Data Source..."

DS_CONFIG=$(cat <<DSCONFIG
{
  "type": "S3",
  "s3Configuration": {
    "bucketArn": "arn:aws:s3:::${KB_BUCKET}",
    "inclusionPrefixes": ["redshift-docs/"]
  }
}
DSCONFIG
)

DS_ID=$(aws bedrock-agent create-data-source \
  --knowledge-base-id "$KB_ID" \
  --name "redshift-documentation" \
  --data-source-configuration "$DS_CONFIG" \
  --region $REGION \
  --query 'dataSource.dataSourceId' \
  --output text 2>/dev/null || echo "exists")

if [ "$DS_ID" = "exists" ]; then
  echo "   Data Source already exists, getting ID..."
  DS_ID=$(aws bedrock-agent list-data-sources \
    --knowledge-base-id "$KB_ID" \
    --region $REGION \
    --query 'dataSourceSummaries[0].dataSourceId' \
    --output text)
fi

echo "✅ Data Source ID: $DS_ID"

# Start ingestion job
echo "🔄 Starting ingestion job (this may take 5-10 minutes)..."

INGESTION_JOB_ID=$(aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "$KB_ID" \
  --data-source-id "$DS_ID" \
  --region $REGION \
  --query 'ingestionJob.ingestionJobId' \
  --output text)

echo "   Ingestion Job ID: $INGESTION_JOB_ID"
echo "   Waiting for ingestion to complete..."

# Wait for ingestion
while true; do
  STATUS=$(aws bedrock-agent get-ingestion-job \
    --knowledge-base-id "$KB_ID" \
    --data-source-id "$DS_ID" \
    --ingestion-job-id "$INGESTION_JOB_ID" \
    --region $REGION \
    --query 'ingestionJob.status' \
    --output text)
  
  if [ "$STATUS" = "COMPLETE" ]; then
    echo "✅ Ingestion complete!"
    break
  elif [ "$STATUS" = "FAILED" ]; then
    echo "❌ Ingestion failed!"
    exit 1
  else
    echo "   Status: $STATUS (checking again in 30s...)"
    sleep 30
  fi
done

# Update config with KB ID
jq --arg kb_id "$KB_ID" --arg ds_id "$DS_ID" \
  '. + {kb_id: $kb_id, data_source_id: $ds_id}' \
  infrastructure/kb-config.json > infrastructure/kb-config.tmp.json
mv infrastructure/kb-config.tmp.json infrastructure/kb-config.json

echo ""
echo "✅ Knowledge Base setup complete!"
echo ""
echo "📊 Summary:"
echo "   Knowledge Base ID: $KB_ID"
echo "   Data Source ID: $DS_ID"
echo "   S3 Bucket: s3://$KB_BUCKET"
echo "   Collection: $COLLECTION_NAME"
echo ""
echo "📝 Next step: Update Lambda to use Knowledge Base"
echo "   Run: ./infrastructure/update-lambda-kb.sh"

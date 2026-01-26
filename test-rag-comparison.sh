#!/bin/bash

API_URL="https://iq1letmtxa.execute-api.us-east-1.amazonaws.com"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  RAG Comparison Test                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check current RAG type
echo "🔍 Checking current RAG type..."
RAG_TYPE=$(curl -s $API_URL/health | jq -r '.rag_type // "Hybrid RAG"')
echo "   Current: $RAG_TYPE"
echo ""

# Test cases
declare -a TEST_CASES=(
  "Snowflake|SELECT * FROM sales QUALIFY ROW_NUMBER() OVER (ORDER BY amount DESC) = 1"
  "Snowflake|MERGE INTO customers c USING updates u ON c.id = u.id WHEN MATCHED THEN UPDATE SET c.name = u.name"
  "Oracle|SELECT * FROM (SELECT t.*, ROWNUM rn FROM table t) WHERE rn = 1"
  "BigQuery|SELECT ARRAY_AGG(name) FROM users"
  "Teradata|SEL * FROM table QUALIFY rank = 1"
)

echo "🧪 Running test cases..."
echo ""

for i in "${!TEST_CASES[@]}"; do
  IFS='|' read -r db sql <<< "${TEST_CASES[$i]}"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Test $((i+1)): $db"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Input SQL:"
  echo "  $sql"
  echo ""
  
  # Call API
  RESPONSE=$(curl -s -X POST $API_URL/convert \
    -H "Content-Type: application/json" \
    -d "{\"source_db\": \"$db\", \"sql\": \"$sql\", \"model\": \"amazon.nova-pro-v1:0\"}")
  
  # Extract result
  REDSHIFT_SQL=$(echo $RESPONSE | jq -r '.redshift_sql')
  MODEL=$(echo $RESPONSE | jq -r '.model_used')
  RAG=$(echo $RESPONSE | jq -r '.rag_type // "Hybrid RAG"')
  
  echo "Output SQL:"
  echo "  $REDSHIFT_SQL"
  echo ""
  echo "Model: $MODEL | RAG: $RAG"
  echo ""
done

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Test Complete                                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "💡 To compare with Full RAG:"
echo "   1. Run: ./setup-full-rag.sh"
echo "   2. Run: ./test-rag-comparison.sh"
echo "   3. Compare results"

#!/bin/bash
# Direct Lambda invocation for large SQL (bypasses API Gateway 30s timeout)
# Usage: ./convert-large-sql.sh input.sql output.sql [source_db] [model]

INPUT_FILE="${1:-input.sql}"
OUTPUT_FILE="${2:-output.sql}"
SOURCE_DB="${3:-BigQuery}"
MODEL="${4:-nova-pro}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

echo "Converting $INPUT_FILE..."
echo "Source DB: $SOURCE_DB"
echo "Model: $MODEL"
echo ""

# Read SQL and escape for JSON
SQL_CONTENT=$(cat "$INPUT_FILE" | jq -Rs .)

# Create payload
PAYLOAD=$(cat <<EOF
{
  "source_db": "$SOURCE_DB",
  "sql": $SQL_CONTENT,
  "include_explanation": false,
  "model": "$MODEL"
}
EOF
)

# Invoke Lambda directly (120s timeout, bypasses API Gateway)
aws lambda invoke \
  --function-name sql-converter-api \
  --payload "$PAYLOAD" \
  --region us-east-1 \
  --cli-read-timeout 120 \
  response.json > /dev/null

# Extract converted SQL
if [ -f response.json ]; then
    if jq -e '.errorMessage' response.json > /dev/null 2>&1; then
        echo "Error:"
        jq -r '.errorMessage' response.json
        rm response.json
        exit 1
    else
        jq -r '.redshift_sql' response.json > "$OUTPUT_FILE"
        echo "✓ Conversion complete: $OUTPUT_FILE"
        echo ""
        echo "Model used: $(jq -r '.model_used' response.json)"
        rm response.json
    fi
else
    echo "Error: Lambda invocation failed"
    exit 1
fi

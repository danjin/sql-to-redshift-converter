#!/bin/bash
# SQL Converter - Feature Refresh CLI
# Usage: ./refresh-features.sh [command]

REGION="us-east-1"
FUNCTION_NAME="sql-converter-refresh-features"
TABLE_NAME="sql-converter-features"

case "$1" in
  refresh|update)
    echo "🔄 Triggering feature refresh..."
    aws lambda invoke \
      --function-name $FUNCTION_NAME \
      --region $REGION \
      /tmp/refresh-output.json >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
      echo "✅ Refresh completed!"
      cat /tmp/refresh-output.json | python3 -m json.tool 2>/dev/null || cat /tmp/refresh-output.json
    else
      echo "❌ Refresh failed"
      exit 1
    fi
    ;;
    
  status|check)
    echo "📊 Checking feature cache status..."
    UPDATED=$(aws dynamodb get-item \
      --table-name $TABLE_NAME \
      --key '{"feature_key": {"S": "redshift_features"}}' \
      --region $REGION \
      --query 'Item.updated_at.S' \
      --output text 2>/dev/null)
    
    if [ -n "$UPDATED" ]; then
      echo "Last updated: $UPDATED"
      echo ""
      echo "Cached features:"
      aws dynamodb get-item \
        --table-name $TABLE_NAME \
        --key '{"feature_key": {"S": "redshift_features"}}' \
        --region $REGION \
        --query 'Item.features.L[*].S' \
        --output table
    else
      echo "❌ No cached features found. Run: $0 refresh"
    fi
    ;;
    
  list|features)
    echo "📋 Current Redshift features:"
    aws dynamodb get-item \
      --table-name $TABLE_NAME \
      --key '{"feature_key": {"S": "redshift_features"}}' \
      --region $REGION \
      --query 'Item.features.L[*].S' \
      --output text | tr '\t' '\n' | nl
    ;;
    
  logs)
    echo "📜 Recent refresh logs:"
    aws logs tail /aws/lambda/$FUNCTION_NAME \
      --since 7d \
      --region $REGION \
      --format short | tail -20
    ;;
    
  schedule)
    echo "⏰ Refresh schedule:"
    aws events describe-rule \
      --name sql-converter-weekly-refresh \
      --region $REGION \
      --query '{Schedule: ScheduleExpression, State: State}' \
      --output table
    ;;
    
  help|*)
    cat << EOF
SQL Converter - Feature Refresh CLI

Usage: $0 [command]

Commands:
  refresh, update    Trigger immediate feature refresh
  status, check      Check cache status and last update time
  list, features     List all cached features
  logs               View recent refresh logs
  schedule           Show refresh schedule
  help               Show this help message

Examples:
  $0 refresh         # Refresh features now
  $0 status          # Check when last refreshed
  $0 list            # Show all features
  $0 logs            # View logs

EOF
    ;;
esac

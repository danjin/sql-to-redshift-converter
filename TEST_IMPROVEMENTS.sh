#!/bin/bash

API="https://iq1letmtxa.execute-api.us-east-1.amazonaws.com"

echo "=========================================="
echo "Testing SQL Converter Improvements"
echo "=========================================="
echo ""

echo "1. Testing /models endpoint..."
echo "GET $API/models"
echo ""
curl -s "$API/models" | python3 -m json.tool
echo ""
echo ""

echo "2. Testing Nova Pro model..."
echo "POST $API/convert (model: nova-pro)"
echo ""
curl -s -X POST "$API/convert" \
  -H "Content-Type: application/json" \
  -d '{
    "source_db": "Snowflake",
    "sql": "SELECT col::STRING FROM table",
    "model": "nova-pro"
  }' | python3 -m json.tool
echo ""
echo ""

echo "3. Testing Claude 3.5 Sonnet with explanation..."
echo "POST $API/convert (model: claude-sonnet)"
echo ""
curl -s -X POST "$API/convert" \
  -H "Content-Type: application/json" \
  -d '{
    "source_db": "BigQuery",
    "sql": "SELECT ARRAY_AGG(name) FROM `table`",
    "model": "claude-sonnet",
    "include_explanation": true
  }' | python3 -m json.tool
echo ""
echo ""

echo "=========================================="
echo "All tests completed!"
echo "=========================================="

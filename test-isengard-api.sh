#!/bin/bash
# Quick test script for Isengard-compliant deployment

API_ENDPOINT="https://wl2hf311kg.execute-api.us-east-1.amazonaws.com"

echo "=== Testing SQL Converter API ==="
echo ""

echo "1. Health Check:"
curl -s $API_ENDPOINT/health | python3 -m json.tool
echo ""

echo "2. Available Models:"
curl -s $API_ENDPOINT/models | python3 -m json.tool | head -20
echo ""

echo "3. SQL Conversion Test (Oracle to Redshift):"
curl -X POST $API_ENDPOINT/convert \
  -H "Content-Type: application/json" \
  -d '{
    "source_db": "Oracle",
    "sql": "SELECT * FROM DUAL WHERE ROWNUM = 1",
    "model": "nova-pro"
  }' 2>/dev/null | python3 -m json.tool
echo ""

echo "✓ All tests complete!"

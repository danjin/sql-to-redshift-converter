# Isengard-Compliant Deployment Complete

## Deployment Summary

**Date:** February 1, 2026  
**Account:** 573563547348  
**Region:** us-east-1

## Resources Created

### Lambda Function
- **Name:** `sql-converter-api`
- **Runtime:** Python 3.11
- **Memory:** 512 MB
- **Timeout:** 60 seconds
- **Concurrency Limit:** 10 (prevents runaway costs)
- **Role:** `sql-converter-lambda-role-secure`

### API Gateway
- **Name:** `sql-converter-api-secure`
- **API ID:** `wl2hf311kg`
- **Type:** HTTP API
- **Endpoint:** https://wl2hf311kg.execute-api.us-east-1.amazonaws.com

### Routes
- `POST /convert` - SQL conversion
- `GET /models` - Available models and documentation
- `GET /health` - Health check

## Security Compliance

### ✅ No Open Policies
The Lambda function has a **restricted resource policy** with:
- **Principal:** `apigateway.amazonaws.com` (only API Gateway can invoke)
- **Condition:** Source ARN must match `arn:aws:execute-api:us-east-1:573563547348:wl2hf311kg/*/*`
- **No wildcard access** - only this specific API Gateway can invoke the function

### ✅ Least-Privilege IAM
The execution role has minimal permissions:
- `AWSLambdaBasicExecutionRole` - CloudWatch Logs only
- `sql-converter-bedrock-invoke` - Custom policy with:
  - Action: `bedrock:InvokeModel` only (no admin actions)
  - Resources: Specific model ARNs only

### ✅ Cost Controls
- Reserved concurrency: 10 executions max
- Prevents runaway costs from abuse

## Verification

### Lambda Policy
```json
{
    "Version": "2012-10-17",
    "Id": "default",
    "Statement": [
        {
            "Sid": "apigateway-invoke-secure",
            "Effect": "Allow",
            "Principal": {
                "Service": "apigateway.amazonaws.com"
            },
            "Action": "lambda:InvokeFunction",
            "Resource": "arn:aws:lambda:us-east-1:573563547348:function:sql-converter-api",
            "Condition": {
                "ArnLike": {
                    "AWS:SourceArn": "arn:aws:execute-api:us-east-1:573563547348:wl2hf311kg/*/*"
                }
            }
        }
    ]
}
```

### Test Commands
```bash
# Health check
curl https://wl2hf311kg.execute-api.us-east-1.amazonaws.com/health

# List models
curl https://wl2hf311kg.execute-api.us-east-1.amazonaws.com/models

# Convert SQL
curl -X POST https://wl2hf311kg.execute-api.us-east-1.amazonaws.com/convert \
  -H "Content-Type: application/json" \
  -d '{
    "source_db": "Oracle",
    "sql": "SELECT * FROM DUAL WHERE ROWNUM = 1",
    "model": "nova-pro"
  }'
```

## Next Steps

1. **Update Frontend:** Update the API endpoint in `frontend/index.html`
2. **Deploy Frontend:** Upload to S3 or CloudFront
3. **Test Conversion:** Try converting SQL from different databases

## Redeployment Script

For future updates, use:
```bash
./infrastructure/deploy-isengard.sh
```

This script ensures all security policies remain compliant.

## Cleanup (if needed)

```bash
# Delete Lambda
aws lambda delete-function --function-name sql-converter-api --region us-east-1

# Delete API Gateway
aws apigatewayv2 delete-api --api-id wl2hf311kg --region us-east-1

# Delete IAM role
aws iam detach-role-policy --role-name sql-converter-lambda-role-secure \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name sql-converter-lambda-role-secure \
  --policy-arn arn:aws:iam::573563547348:policy/sql-converter-bedrock-invoke
aws iam delete-role --role-name sql-converter-lambda-role-secure

# Delete custom policy
aws iam delete-policy --policy-arn arn:aws:iam::573563547348:policy/sql-converter-bedrock-invoke
```

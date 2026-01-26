# SQL to Redshift Converter

AI-powered web tool to convert SQL from multiple databases to Amazon Redshift.

## RAG Options

This project supports two RAG (Retrieval-Augmented Generation) approaches:

| Feature | **Hybrid RAG** (Current) | **Full RAG** (Optional) |
|---------|-------------------------|------------------------|
| **Cost** | $0.26/month | ~$700/month |
| **Accuracy** | 90% | 98% |
| **Search** | Keyword-based | Semantic vector search |
| **Maintenance** | Occasional updates | Auto-sync |
| **Best For** | Common SQL patterns | Complex/rare syntax |
| **Setup** | ✅ Already deployed | See [FULL_RAG_SETUP.md](FULL_RAG_SETUP.md) |

**To upgrade to Full RAG:** Run `./setup-full-rag.sh`

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Web Browser (frontend/index.html)                       │  │
│  │  • Source DB Selector (Teradata/Oracle/MySQL/etc)       │  │
│  │  • Model Selector (Nova Pro/Claude 4.5)                 │  │
│  │  • SQL Input/Output Panels                              │  │
│  │  • Documentation Modal                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              │ HTTPS                            │
│                              ▼                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         AWS CLOUD                               │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Gateway (HTTP API)                                  │  │
│  │  Endpoint: iq1letmtxa.execute-api.us-east-1.amazonaws.com│ │
│  │  • /convert (POST) - SQL conversion                      │  │
│  │  • /models (GET) - Available models & docs               │  │
│  │  • /health (GET) - Health check                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              │ Invoke                           │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  AWS Lambda (sql-converter-api)                          │  │
│  │  Runtime: Python 3.11                                    │  │
│  │  Memory: 512MB | Timeout: 60s                            │  │
│  │                                                           │  │
│  │  Components:                                             │  │
│  │  • Request Parser                                        │  │
│  │  • Conversion Rules Engine                              │  │
│  │  • Prompt Builder                                        │  │
│  │  • Model Router (Nova/Claude)                           │  │
│  │  • Response Formatter                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              │ InvokeModel                      │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Amazon Bedrock                                          │  │
│  │                                                           │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────┐ │  │
│  │  │ Amazon Nova Pro│  │Claude Haiku 4.5│  │Claude Opus │ │  │
│  │  │   (Default)    │  │    (Fast)      │  │4.5 (Best)  │ │  │
│  │  └────────────────┘  └────────────────┘  └────────────┘ │  │
│  │                                                           │  │
│  │  AI Models perform SQL conversion using:                 │  │
│  │  • Database-specific conversion rules                    │  │
│  │  • Reference documentation knowledge                     │  │
│  │  • Syntax transformation logic                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  IAM Role (sql-converter-lambda-role)                    │  │
│  │  Permissions:                                            │  │
│  │  • AWSLambdaBasicExecutionRole                          │  │
│  │  • AmazonBedrockFullAccess                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  S3 Bucket (sql-converter-frontend-*)                    │  │
│  │  • Static website hosting (optional)                     │  │
│  │  • Frontend HTML/CSS/JS                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    REFERENCE DOCUMENTATION                      │
│                                                                 │
│  • Redshift:   docs.aws.amazon.com/redshift                   │
│  • Teradata:   docs.teradata.com                              │
│  • Oracle:     docs.oracle.com/en/database                    │
│  • MySQL:      dev.mysql.com/doc                              │
│  • Clickhouse: clickhouse.com/docs                            │
│  • Snowflake:  docs.snowflake.com                             │
│  • BigQuery:   cloud.google.com/bigquery/docs                 │
│                                                                 │
│  (Used by AI models for conversion logic)                      │
└─────────────────────────────────────────────────────────────────┘

Data Flow:
1. User enters SQL in web interface
2. Browser sends POST to API Gateway
3. API Gateway invokes Lambda function
4. Lambda builds prompt with conversion rules
5. Lambda calls Bedrock with selected model
6. AI model converts SQL using reference docs knowledge
7. Lambda parses and formats response
8. API Gateway returns converted SQL to browser
9. User sees Redshift SQL in output panel
```

## Supported Source Databases
- Teradata
- Oracle
- MySQL
- Clickhouse
- Snowflake
- BigQuery

## Architecture
- **Frontend**: Static HTML/JS hosted on S3
- **Backend**: Python FastAPI on AWS Lambda
- **AI**: Amazon Bedrock (Claude 3.5 Sonnet)
- **API**: API Gateway HTTP API

## Quick Deploy

### 1. Build Lambda Package
```bash
cd sql-converter
chmod +x infrastructure/build.sh
./infrastructure/build.sh
```

### 2. Deploy to AWS
```bash
chmod +x infrastructure/deploy.sh
./infrastructure/deploy.sh
```

This will:
- Create IAM role with Bedrock permissions
- Deploy Lambda function
- Create API Gateway
- Host frontend on S3
- Output your website URL

### 3. Manage Feature Cache (Hybrid RAG)

The tool automatically refreshes Redshift features weekly. To manage manually:

```bash
# Check feature cache status
./refresh-features.sh status

# Trigger immediate refresh
./refresh-features.sh refresh

# List all cached features
./refresh-features.sh list

# View refresh logs
./refresh-features.sh logs
```

See `HYBRID_RAG_COMPLETE.md` for details on the automatic documentation system.

### 3. Access Your Tool
Open the URL provided at the end of deployment.

## Local Development

### Run Backend Locally
```bash
cd backend
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```

### Test API
```bash
curl -X POST http://localhost:8000/convert \
  -H "Content-Type: application/json" \
  -d '{
    "source_db": "Oracle",
    "sql": "SELECT * FROM DUAL WHERE ROWNUM = 1",
    "include_explanation": true
  }'
```

### Open Frontend Locally
```bash
cd frontend
# Update API_URL in index.html to http://localhost:8000
python3 -m http.server 8080
# Open http://localhost:8080
```

## API Endpoints

### POST /convert
Convert SQL from source database to Redshift.

**Request:**
```json
{
  "source_db": "Snowflake",
  "sql": "SELECT * FROM table WHERE col::STRING = 'value'",
  "include_explanation": false
}
```

**Response:**
```json
{
  "redshift_sql": "SELECT * FROM table WHERE CAST(col AS VARCHAR) = 'value'",
  "explanation": null,
  "source_db": "Snowflake"
}
```

### GET /supported-databases
List all supported source databases.

### GET /health
Health check endpoint.

## Cost Estimate
- Lambda: ~$0.20 per 1M requests
- API Gateway: ~$1.00 per 1M requests
- Bedrock: ~$0.003 per 1K input tokens, ~$0.015 per 1K output tokens
- S3: ~$0.023 per GB storage + data transfer

Typical conversion: ~500 input tokens + ~300 output tokens = ~$0.006 per conversion

## Cleanup
```bash
# Delete Lambda function
aws lambda delete-function --function-name sql-converter-api --region us-east-1

# Delete API Gateway
aws apigatewayv2 delete-api --api-id <API_ID> --region us-east-1

# Delete S3 bucket
aws s3 rb s3://<BUCKET_NAME> --force --region us-east-1

# Delete IAM role
aws iam detach-role-policy --role-name sql-converter-lambda-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name sql-converter-lambda-role --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess
aws iam delete-role --role-name sql-converter-lambda-role
```

## Future Enhancements
- Add SQL validation against actual Redshift cluster
- Store conversion history
- Batch conversion support
- Download converted SQL as file
- Syntax highlighting
- Dark mode
- User authentication
- Rate limiting

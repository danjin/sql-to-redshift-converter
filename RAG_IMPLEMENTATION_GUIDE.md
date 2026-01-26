# Guide: Adding RAG for Live Documentation

## Current Implementation ✅

**What I Just Added:**
- Web scraping of key Redshift documentation pages
- 24-hour caching to reduce latency
- Automatic feature detection from docs
- Injected into AI prompts before conversion

**How It Works:**
1. Before each conversion, fetch latest Redshift feature pages
2. Extract key information (e.g., "QUALIFY is supported")
3. Add to prompt: "LATEST REDSHIFT FEATURES (verified from docs)"
4. AI model uses this fresh info for conversion

**Limitations:**
- Only checks specific pages (QUALIFY, MERGE, etc.)
- Simple text extraction (not semantic)
- 3-second timeout per page
- In-memory cache (resets on Lambda cold start)

## Better Approach: Amazon Bedrock Knowledge Bases

### Architecture with RAG

```
User SQL Input
     ↓
Lambda Function
     ↓
1. Extract SQL keywords (QUALIFY, MERGE, etc.)
     ↓
2. Query Bedrock Knowledge Base
   "What Redshift features support window function filtering?"
     ↓
3. Retrieve relevant doc sections
   - QUALIFY clause documentation
   - Window function examples
   - Syntax reference
     ↓
4. Build enhanced prompt with retrieved docs
     ↓
5. Call Bedrock model with context
     ↓
Accurate, up-to-date conversion
```

### Implementation Steps

#### 1. Create S3 Bucket for Documentation
```bash
aws s3 mb s3://sql-converter-docs --region us-east-1
```

#### 2. Crawl and Upload Documentation
```python
# Script to crawl Redshift docs
import requests
from bs4 import BeautifulSoup

docs_to_crawl = [
    "https://docs.aws.amazon.com/redshift/latest/dg/r_QUALIFY_clause.html",
    "https://docs.aws.amazon.com/redshift/latest/dg/r_MERGE.html",
    "https://docs.aws.amazon.com/redshift/latest/dg/c_SQL_functions.html",
    # Add more pages...
]

for url in docs_to_crawl:
    response = requests.get(url)
    # Extract and save to S3
    # aws s3 cp doc.txt s3://sql-converter-docs/
```

#### 3. Create Bedrock Knowledge Base
```bash
# Via AWS Console or CLI
aws bedrock-agent create-knowledge-base \
    --name sql-converter-docs \
    --role-arn arn:aws:iam::ACCOUNT:role/BedrockKBRole \
    --knowledge-base-configuration '{
        "type": "VECTOR",
        "vectorKnowledgeBaseConfiguration": {
            "embeddingModelArn": "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
        }
    }' \
    --storage-configuration '{
        "type": "OPENSEARCH_SERVERLESS",
        "opensearchServerlessConfiguration": {
            "collectionArn": "arn:aws:aoss:us-east-1:ACCOUNT:collection/...",
            "vectorIndexName": "sql-docs",
            "fieldMapping": {
                "vectorField": "vector",
                "textField": "text",
                "metadataField": "metadata"
            }
        }
    }'
```

#### 4. Create Data Source
```bash
aws bedrock-agent create-data-source \
    --knowledge-base-id KB_ID \
    --name redshift-docs \
    --data-source-configuration '{
        "type": "S3",
        "s3Configuration": {
            "bucketArn": "arn:aws:s3:::sql-converter-docs"
        }
    }'
```

#### 5. Update Lambda Code
```python
import boto3

bedrock_agent = boto3.client('bedrock-agent-runtime', region_name='us-east-1')

def retrieve_relevant_docs(query, kb_id):
    """Retrieve relevant documentation from Knowledge Base"""
    response = bedrock_agent.retrieve(
        knowledgeBaseId=kb_id,
        retrievalQuery={'text': query},
        retrievalConfiguration={
            'vectorSearchConfiguration': {
                'numberOfResults': 3
            }
        }
    )
    
    docs = []
    for result in response['retrievalResults']:
        docs.append(result['content']['text'])
    
    return "\n\n".join(docs)

def build_prompt_with_rag(source_db, sql, kb_id):
    # Extract key SQL features
    keywords = extract_sql_keywords(sql)
    
    # Query knowledge base
    query = f"Redshift support for {', '.join(keywords)}"
    relevant_docs = retrieve_relevant_docs(query, kb_id)
    
    prompt = f"""Convert {source_db} SQL to Redshift.

RELEVANT REDSHIFT DOCUMENTATION:
{relevant_docs}

Source SQL:
{sql}

Use the documentation above to ensure accurate conversion.
"""
    return prompt
```

#### 6. Update Lambda IAM Role
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:Retrieve",
                "bedrock:RetrieveAndGenerate"
            ],
            "Resource": "arn:aws:bedrock:us-east-1:ACCOUNT:knowledge-base/*"
        }
    ]
}
```

### Cost Comparison

**Current (Web Scraping):**
- Free (just HTTP requests)
- Fast (cached)
- Limited accuracy

**RAG with Knowledge Base:**
- OpenSearch Serverless: ~$700/month (always on)
- Embeddings: ~$0.0001 per 1K tokens
- Retrieval: ~$0.0001 per query
- **Total for 10K conversions/month: ~$700-750**

**Alternative: On-Demand RAG:**
- Use web_search tool (like I have access to)
- Search for specific features on-demand
- Free or very low cost
- Slightly slower (2-3 seconds per search)

## Recommended Approach

### For Your Use Case:

**Option A: Enhanced Web Scraping (Current)** ✅
- Already implemented
- Free, fast, good enough for most cases
- Update feature list monthly

**Option B: Scheduled Documentation Updates**
- Run a weekly Lambda that:
  1. Crawls Redshift docs
  2. Extracts new features
  3. Updates conversion rules in DynamoDB
  4. Lambda reads from DynamoDB
- Cost: ~$1/month

**Option C: Full RAG (Best Quality)**
- Implement Bedrock Knowledge Base
- Always up-to-date
- Best accuracy
- Cost: ~$700/month

**Option D: Hybrid (Best Value)**
- Use web scraping for common features
- Add web_search for unknown patterns
- Update rules quarterly
- Cost: ~$5/month

## Implementation: Option D (Hybrid)

I can implement this now if you want:
1. Keep current web scraping
2. Add fallback to web search for unknown SQL patterns
3. Cache search results
4. Update conversion rules automatically

Would you like me to implement Option D?

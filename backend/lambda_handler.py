import json
import boto3
import re
import urllib.request
import urllib.error
from datetime import datetime, timedelta
from decimal import Decimal

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
features_table = dynamodb.Table('sql-converter-features')

CACHE_DURATION_HOURS = 168  # 7 days

AVAILABLE_MODELS = {
    'nova-pro': {'id': 'amazon.nova-pro-v1:0', 'name': 'Amazon Nova Pro', 'format': 'nova'},
    'claude-haiku-4.5': {'id': 'us.anthropic.claude-haiku-4-5-20251001-v1:0', 'name': 'Claude Haiku 4.5', 'format': 'anthropic'},
    'claude-opus-4.5': {'id': 'us.anthropic.claude-opus-4-5-20251101-v1:0', 'name': 'Claude Opus 4.5', 'format': 'anthropic'},
    'claude-opus-4.6': {'id': 'us.anthropic.claude-opus-4-6-v1', 'name': 'Claude Opus 4.6', 'format': 'anthropic'}
}

REFERENCE_DOCS = {
    "Redshift": "https://docs.aws.amazon.com/redshift/latest/dg/",
    "Teradata": "https://docs.teradata.com/",
    "Oracle": "https://docs.oracle.com/en/database/",
    "MySQL": "https://dev.mysql.com/doc/",
    "Clickhouse": "https://clickhouse.com/docs/",
    "Snowflake": "https://docs.snowflake.com/",
    "BigQuery": "https://cloud.google.com/bigquery/docs/"
}

# Key Redshift feature pages to check
REDSHIFT_FEATURE_PAGES = {
    "qualify": "https://docs.aws.amazon.com/redshift/latest/dg/r_QUALIFY_clause.html",
    "merge": "https://docs.aws.amazon.com/redshift/latest/dg/r_MERGE.html",
    "window_functions": "https://docs.aws.amazon.com/redshift/latest/dg/c_Window_functions.html"
}

def get_cached_features():
    """Get features from DynamoDB cache"""
    try:
        response = features_table.get_item(Key={'feature_key': 'redshift_features'})
        if 'Item' in response:
            item = response['Item']
            cached_time = datetime.fromisoformat(item['updated_at'])
            if datetime.now() - cached_time < timedelta(hours=CACHE_DURATION_HOURS):
                return item.get('features', [])
    except Exception as e:
        print(f"Cache read error: {e}")
    return None

def save_features_to_cache(features):
    """Save features to DynamoDB"""
    try:
        features_table.put_item(Item={
            'feature_key': 'redshift_features',
            'features': features,
            'updated_at': datetime.now().isoformat()
        })
    except Exception as e:
        print(f"Cache write error: {e}")

def fetch_doc_snippet(url, max_length=500):
    """Fetch documentation snippet"""
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=3) as response:
            html = response.read().decode('utf-8')
            text = re.sub(r'<[^>]+>', ' ', html)
            text = re.sub(r'\s+', ' ', text).strip()
            return text[:max_length]
    except Exception as e:
        return None

def fetch_redshift_features():
    """Fetch latest Redshift features using AI detection"""
    try:
        # Fetch documentation page
        req = urllib.request.Request(
            "https://docs.aws.amazon.com/redshift/latest/mgmt/cluster-versions.html",
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')
            text = re.sub(r'<[^>]+>', ' ', html)
            text = re.sub(r'\s+', ' ', text).strip()[:50000]  # Limit to 50K chars
            
            # Use AI to extract features
            prompt = f"""Extract all Amazon Redshift SQL features, functions, and capabilities mentioned in this documentation.

Documentation text:
{text}

Return ONLY a JSON array of feature descriptions. Each item should be a concise statement like:
"FEATURE_NAME is SUPPORTED (brief description)"

Focus on SQL syntax, functions, data types, and query capabilities.
Return 15-25 most important features.

Format: ["feature 1", "feature 2", ...]"""

            response = bedrock.invoke_model(
                modelId='amazon.nova-pro-v1:0',
                body=json.dumps({
                    "messages": [{"role": "user", "content": [{"text": prompt}]}],
                    "inferenceConfig": {"temperature": 0.1, "maxTokens": 2000}
                })
            )
            
            result = json.loads(response['body'].read())
            ai_response = result['output']['message']['content'][0]['text'].strip()
            
            # Parse JSON array from response
            features = json.loads(ai_response)
            return features if isinstance(features, list) else []
            
    except Exception as e:
        print(f"AI feature detection error: {e}")
        # Fallback to basic detection
        return [
            "QUALIFY clause is SUPPORTED (filters window function results)",
            "MERGE statement is SUPPORTED (upsert operations)",
            "SUPER data type is SUPPORTED (semi-structured data)",
            "UNNEST is SUPPORTED (converts arrays to rows)",
            "TRY_CAST is SUPPORTED (safe type conversion)",
            "GROUP BY ALL is SUPPORTED"
        ]

def get_redshift_features():
    """Get Redshift features with DynamoDB caching"""
    # Try cache first
    cached = get_cached_features()
    if cached:
        return cached
    
    # Fetch fresh data
    features = fetch_redshift_features()
    
    # Save to cache
    if features:
        save_features_to_cache(features)
    
    return features

def get_conversion_rules(source_db):
    rules = {
        "Teradata": "QUALIFY→QUALIFY (Redshift supports QUALIFY since July 2023!), COMPRESS→ENCODE, SEL→SELECT",
        "Oracle": "VARCHAR2→VARCHAR, NUMBER→DECIMAL, SYSDATE→GETDATE(), NVL→COALESCE, DECODE→CASE, ROWNUM→ROW_NUMBER(), remove DUAL, (+)→JOIN, SEQUENCE.NEXTVAL→IDENTITY",
        "MySQL": "AUTO_INCREMENT→IDENTITY, DATETIME→TIMESTAMP, TEXT→VARCHAR(65535), IFNULL→COALESCE, NOW()→GETDATE(), DATE_FORMAT→TO_CHAR, GROUP_CONCAT→LISTAGG, `→\"",
        "Clickhouse": "UInt→INTEGER/BIGINT, Float32/64→REAL/DOUBLE, String→VARCHAR, DateTime→TIMESTAMP, Array→SUPER, remove ENGINE, ORDER BY→SORTKEY, PARTITION BY→DISTKEY, arrayJoin→UNNEST, groupArray→LISTAGG",
        "Snowflake": "VARIANT/ARRAY/OBJECT→SUPER, FLATTEN→UNNEST, GET_PATH/GET→JSON_EXTRACT_PATH_TEXT, PARSE_JSON→JSON_PARSE, IFF→CASE WHEN, CURRENT_TIMESTAMP()→GETDATE(), QUALIFY→QUALIFY (Redshift supports QUALIFY!), ::→CAST, CLUSTER BY→DISTKEY",
        "BigQuery": "STRING→VARCHAR, INT64→BIGINT, FLOAT64→DOUBLE PRECISION, BOOL→BOOLEAN, ARRAY/STRUCT→SUPER, SAFE_CAST→TRY_CAST, IFNULL→COALESCE, CURRENT_DATETIME()→GETDATE(), TIMESTAMP_TRUNC→DATE_TRUNC, FORMAT_TIMESTAMP→TO_CHAR, `→\", QUALIFY→QUALIFY (Redshift supports QUALIFY!), UNNEST(array_literal)→use subquery with JSON_PARSE or VALUES, UNNEST(table.column)→UNNEST (Redshift UNNEST requires table column, not inline arrays), TABLESAMPLE SYSTEM (n PERCENT)→ORDER BY RANDOM() LIMIT (calculate n% of rows) - Redshift has no TABLESAMPLE"
    }
    return rules.get(source_db, "")

def build_prompt(source_db, sql, include_explanation):
    rules = get_conversion_rules(source_db)
    
    # Fetch latest Redshift features
    redshift_features = get_redshift_features()
    features_text = "\n".join([f"- {f}" for f in redshift_features]) if redshift_features else ""
    
    prompt = f"""Convert this {source_db} SQL to Amazon Redshift SQL.

LATEST REDSHIFT FEATURES (verified from docs):
{features_text}

Key conversions: {rules}

Source SQL ({source_db}):
```sql
{sql}
```

Requirements:
1. Convert data types to Redshift equivalents
2. Replace unsupported functions
3. Preserve original logic exactly
4. Output valid, executable Redshift SQL
5. Use latest Redshift features when available (see above)
6. IMPORTANT: If the SQL contains comments with instructions (e.g., "do not use X", "prefer Y"), follow those instructions strictly

"""
    if include_explanation:
        prompt += """Format:

CONVERTED SQL:
```sql
[SQL here]
```

EXPLANATION:
[Key changes]
"""
    else:
        prompt += "Provide ONLY the converted SQL."
    return prompt

def handler(event, context):
    try:
        # Parse request
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        source_db = body.get('source_db')
        sql = body.get('sql')
        include_explanation = body.get('include_explanation', False)
        model_key = body.get('model', 'nova-pro')
        
        # Handle OPTIONS for CORS
        if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                },
                'body': ''
            }
        
        # Handle GET /health
        if event.get('rawPath') == '/health' or event.get('path') == '/health':
            return {
                'statusCode': 200,
                'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                'body': json.dumps({'status': 'healthy'})
            }
        
        # Handle GET /supported-databases
        if event.get('rawPath') == '/supported-databases' or event.get('path') == '/supported-databases':
            return {
                'statusCode': 200,
                'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                'body': json.dumps({'databases': ['Teradata', 'Oracle', 'MySQL', 'Clickhouse', 'Snowflake', 'BigQuery']})
            }
        
        # Handle GET /models
        if event.get('rawPath') == '/models' or event.get('path') == '/models':
            return {
                'statusCode': 200,
                'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                'body': json.dumps({
                    'models': [{'key': k, 'name': v['name']} for k, v in AVAILABLE_MODELS.items()],
                    'reference_docs': REFERENCE_DOCS
                })
            }
        
        # Handle POST /refresh
        if event.get('rawPath') == '/refresh' or event.get('path') == '/refresh':
            try:
                # Trigger refresh by fetching fresh features
                features = fetch_redshift_features()
                if features:
                    save_features_to_cache(features)
                    return {
                        'statusCode': 200,
                        'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                        'body': json.dumps({
                            'message': 'Features refreshed successfully',
                            'features_count': len(features),
                            'features': features
                        })
                    }
                else:
                    return {
                        'statusCode': 500,
                        'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Failed to fetch features'})
                    }
            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                    'body': json.dumps({'error': str(e)})
                }
        
        if not source_db or not sql:
            return {
                'statusCode': 400,
                'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'source_db and sql are required'})
            }
        
        # Get model config
        model_config = AVAILABLE_MODELS.get(model_key, AVAILABLE_MODELS['nova-pro'])
        
        # Build prompt and call Bedrock
        prompt = build_prompt(source_db, sql, include_explanation)
        
        # Call model based on format with streaming for faster response
        if model_config['format'] == 'nova':
            response = bedrock.invoke_model(
                modelId=model_config['id'],
                body=json.dumps({
                    "messages": [{"role": "user", "content": [{"text": prompt}]}],
                    "inferenceConfig": {"max_new_tokens": 8192, "temperature": 0.1}
                })
            )
            result = json.loads(response['body'].read())
            content = result['output']['message']['content'][0]['text']
        else:  # anthropic
            response = bedrock.invoke_model(
                modelId=model_config['id'],
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 8192,
                    "temperature": 0.1,
                    "messages": [{"role": "user", "content": prompt}]
                })
            )
            result = json.loads(response['body'].read())
            content = result['content'][0]['text']
        
        # Parse response
        if include_explanation:
            sql_match = re.search(r'```sql\n(.*?)\n```', content, re.DOTALL)
            redshift_sql = sql_match.group(1).strip() if sql_match else content
            exp_match = re.search(r'EXPLANATION:\n(.*)', content, re.DOTALL)
            explanation = exp_match.group(1).strip() if exp_match else None
        else:
            redshift_sql = re.sub(r'```sql\n|\n```|```', '', content).strip()
            explanation = None
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({
                'redshift_sql': redshift_sql,
                'explanation': explanation,
                'source_db': source_db,
                'model_used': model_config['name']
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

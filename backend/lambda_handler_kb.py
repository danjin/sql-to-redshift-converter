import json
import boto3
import os
from datetime import datetime

bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')
bedrock_agent = boto3.client('bedrock-agent-runtime', region_name='us-east-1')

KB_ID = os.environ.get('KNOWLEDGE_BASE_ID', '')

MODELS = {
    'amazon.nova-pro-v1:0': 'Amazon Nova Pro',
    'us.anthropic.claude-4-5-haiku-v1:0': 'Claude Haiku 4.5',
    'us.anthropic.claude-4-5-opus-v1:0': 'Claude Opus 4.5'
}

CONVERSION_RULES = {
    'Teradata': {
        'name': 'Teradata',
        'rules': [
            'QUALIFY clause → QUALIFY (Redshift supports QUALIFY)',
            'MERGE statement → MERGE (Redshift supports MERGE)',
            'CAST(x AS STRING) → CAST(x AS VARCHAR)',
            'SEL → SELECT',
            'BTEQ commands → Remove (not applicable)',
            'MULTISET tables → Standard tables'
        ]
    },
    'Oracle': {
        'name': 'Oracle',
        'rules': [
            'MERGE statement → MERGE (Redshift supports MERGE)',
            'ROWNUM → ROW_NUMBER() window function',
            'DUAL table → Remove (not needed)',
            'NVL() → COALESCE()',
            'SYSDATE → GETDATE() or CURRENT_DATE',
            'VARCHAR2 → VARCHAR'
        ]
    },
    'MySQL': {
        'name': 'MySQL',
        'rules': [
            'LIMIT n → LIMIT n (same syntax)',
            'IFNULL() → COALESCE()',
            'NOW() → GETDATE()',
            'CONCAT() → CONCAT() or || operator',
            'AUTO_INCREMENT → IDENTITY column',
            'TINYINT/MEDIUMINT → SMALLINT or INTEGER'
        ]
    },
    'Clickhouse': {
        'name': 'Clickhouse',
        'rules': [
            'FINAL modifier → Remove (use appropriate WHERE clause)',
            'Array functions → Use Redshift SUPER type or arrays',
            'MergeTree engines → Standard Redshift tables',
            'SAMPLE clause → Use TABLESAMPLE',
            'dictGet() → JOIN with dimension table',
            'toDateTime() → CAST AS TIMESTAMP'
        ]
    },
    'Snowflake': {
        'name': 'Snowflake',
        'rules': [
            'QUALIFY clause → QUALIFY (Redshift supports QUALIFY)',
            'MERGE statement → MERGE (Redshift supports MERGE)',
            '::STRING → CAST AS VARCHAR',
            'VARIANT type → SUPER type',
            'FLATTEN() → Use JSON functions or UNNEST',
            'OBJECT_CONSTRUCT() → JSON_BUILD_OBJECT()'
        ]
    },
    'BigQuery': {
        'name': 'BigQuery',
        'rules': [
            'QUALIFY clause → QUALIFY (Redshift supports QUALIFY)',
            'MERGE statement → MERGE (Redshift supports MERGE)',
            'STRUCT → Use SUPER type or separate columns',
            'ARRAY_AGG() → LISTAGG() or array functions',
            'UNNEST() → UNNEST() (Redshift supports UNNEST)',
            'DATE() → CAST AS DATE'
        ]
    }
}

def retrieve_from_kb(query, num_results=5):
    """Retrieve relevant documentation from Knowledge Base"""
    try:
        response = bedrock_agent.retrieve(
            knowledgeBaseId=KB_ID,
            retrievalQuery={'text': query},
            retrievalConfiguration={
                'vectorSearchConfiguration': {
                    'numberOfResults': num_results
                }
            }
        )
        
        results = []
        for result in response.get('retrievalResults', []):
            content = result.get('content', {}).get('text', '')
            if content:
                results.append(content)
        
        return results
    except Exception as e:
        print(f"KB retrieval error: {str(e)}")
        return []

def convert_sql(source_db, sql, model_id):
    """Convert SQL using Bedrock with Knowledge Base RAG"""
    
    # Get conversion rules
    rules = CONVERSION_RULES.get(source_db, {}).get('rules', [])
    rules_text = '\n'.join([f'- {rule}' for rule in rules])
    
    # Retrieve relevant documentation from Knowledge Base
    kb_context = ""
    if KB_ID:
        print(f"Retrieving from KB for: {source_db} SQL conversion")
        kb_results = retrieve_from_kb(f"Redshift SQL syntax {sql[:200]}", num_results=3)
        if kb_results:
            kb_context = "\n\nRELEVANT REDSHIFT DOCUMENTATION:\n" + "\n---\n".join(kb_results[:3])
    
    # Build prompt
    prompt = f"""You are an expert SQL converter. Convert the following {source_db} SQL to Amazon Redshift SQL.

SOURCE DATABASE: {source_db}

CONVERSION RULES:
{rules_text}

{kb_context}

INPUT SQL:
{sql}

IMPORTANT INSTRUCTIONS:
1. Return ONLY the converted Redshift SQL - no explanations, no markdown, no code blocks
2. Preserve the exact same logic and functionality
3. Use Redshift-native features when available (QUALIFY, MERGE, SUPER type, etc.)
4. If a feature is not supported in Redshift, use the closest equivalent
5. Maintain proper SQL formatting and indentation

CONVERTED REDSHIFT SQL:"""

    # Call Bedrock
    if model_id.startswith('amazon.'):
        # Nova models
        body = {
            "messages": [{"role": "user", "content": [{"text": prompt}]}],
            "inferenceConfig": {"temperature": 0.1, "maxTokens": 2000}
        }
        response = bedrock_runtime.converse(modelId=model_id, **body)
        result = response['output']['message']['content'][0]['text']
    else:
        # Claude models
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "max_tokens": 2000
        }
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=json.dumps(body)
        )
        result = json.loads(response['body'].read())['content'][0]['text']
    
    return result.strip()

def lambda_handler(event, context):
    """Main Lambda handler"""
    
    # Handle CORS preflight
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': ''
        }
    
    path = event.get('rawPath', '/')
    
    # Health check
    if path == '/health':
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({
                'status': 'healthy',
                'rag_type': 'Full RAG with Knowledge Base',
                'kb_id': KB_ID,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
    
    # List models
    if path == '/models':
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({'models': list(MODELS.keys())})
        }
    
    # List supported databases
    if path == '/supported-databases':
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({'databases': list(CONVERSION_RULES.keys())})
        }
    
    # Convert SQL
    if path == '/convert':
        try:
            body = json.loads(event.get('body', '{}'))
            source_db = body.get('source_db')
            sql = body.get('sql')
            model_id = body.get('model', 'amazon.nova-pro-v1:0')
            
            if not source_db or not sql:
                return {
                    'statusCode': 400,
                    'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                    'body': json.dumps({'error': 'Missing source_db or sql'})
                }
            
            if source_db not in CONVERSION_RULES:
                return {
                    'statusCode': 400,
                    'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                    'body': json.dumps({'error': f'Unsupported database: {source_db}'})
                }
            
            # Convert SQL
            redshift_sql = convert_sql(source_db, sql, model_id)
            
            return {
                'statusCode': 200,
                'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                'body': json.dumps({
                    'redshift_sql': redshift_sql,
                    'explanation': None,
                    'source_db': source_db,
                    'model_used': MODELS.get(model_id, model_id),
                    'rag_type': 'Full RAG'
                })
            }
            
        except Exception as e:
            return {
                'statusCode': 500,
                'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
                'body': json.dumps({'error': str(e)})
            }
    
    return {
        'statusCode': 404,
        'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
        'body': json.dumps({'error': 'Not found'})
    }

import json
import boto3
import re
import urllib.request
import secrets
from datetime import datetime
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel
from typing import Optional

app = FastAPI(title="SQL Converter API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBasic()
bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

# Set your credentials here
USERNAME = "admin"
PASSWORD = "ChangeMe123!"  # CHANGE THIS!

def verify_credentials(credentials: HTTPBasicCredentials = Depends(security)):
    correct_username = secrets.compare_digest(credentials.username, USERNAME)
    correct_password = secrets.compare_digest(credentials.password, PASSWORD)
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username

class ConversionRequest(BaseModel):
    source_db: str
    sql: str
    include_explanation: Optional[bool] = False

class ConversionResponse(BaseModel):
    redshift_sql: str
    explanation: Optional[str] = None
    source_db: str

def extract_sql_keywords(sql: str) -> list:
    keywords = []
    types = re.findall(r'\b(VARCHAR2|NUMBER|DATE|TIMESTAMP|CLOB|BLOB|INTEGER|DECIMAL|FLOAT|DOUBLE|STRING|ARRAY|STRUCT)\b', sql, re.IGNORECASE)
    keywords.extend(types)
    functions = re.findall(r'\b([A-Z_]+)\s*\(', sql)
    keywords.extend(functions)
    commands = re.findall(r'\b(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|MERGE|QUALIFY)\b', sql, re.IGNORECASE)
    keywords.extend(commands)
    return list(set(keywords))

def get_conversion_rules(source_db: str) -> str:
    rules = {
        "Teradata": """
Teradata to Redshift:
- QUALIFY → ROW_NUMBER() in subquery with WHERE
- COMPRESS → ENCODE
- VARCHAR(n) → VARCHAR(n)
- NUMBER → DECIMAL
- SEL → SELECT
- CURRENT_TIMESTAMP → GETDATE()
""",
        "Oracle": """
Oracle to Redshift:
- VARCHAR2 → VARCHAR
- NUMBER → DECIMAL
- SYSDATE → GETDATE()
- NVL → COALESCE
- DECODE → CASE WHEN
- ROWNUM → ROW_NUMBER()
- DUAL → remove FROM DUAL
- (+) → LEFT/RIGHT JOIN
- SEQUENCE.NEXTVAL → IDENTITY
""",
        "MySQL": """
MySQL to Redshift:
- AUTO_INCREMENT → IDENTITY(1,1)
- DATETIME → TIMESTAMP
- TEXT → VARCHAR(65535)
- IFNULL → COALESCE
- NOW() → GETDATE()
- DATE_FORMAT → TO_CHAR
- GROUP_CONCAT → LISTAGG
- ` → " for identifiers
""",
        "Clickhouse": """
Clickhouse to Redshift:
- UInt8/16/32/64 → INTEGER/BIGINT
- Float32/64 → REAL/DOUBLE PRECISION
- String → VARCHAR
- DateTime → TIMESTAMP
- Array(T) → SUPER type
- ENGINE = MergeTree → remove
- ORDER BY in CREATE → SORTKEY
- PARTITION BY → DISTKEY
- arrayJoin → UNNEST
- groupArray → LISTAGG
""",
        "Snowflake": """
Snowflake to Redshift:
- VARIANT → SUPER
- ARRAY → SUPER
- OBJECT → SUPER
- FLATTEN → UNNEST or lateral join
- LATERAL FLATTEN → lateral join with UNNEST
- GET_PATH, GET → JSON_EXTRACT_PATH_TEXT
- PARSE_JSON → JSON_PARSE
- TO_VARIANT → JSON_PARSE
- ARRAY_CONSTRUCT → JSON_PARSE('[...]')
- OBJECT_CONSTRUCT → JSON_PARSE('{...}')
- IFF(condition, true, false) → CASE WHEN
- DATEADD → DATEADD (similar syntax)
- DATEDIFF → DATEDIFF (similar)
- CURRENT_TIMESTAMP() → GETDATE()
- QUALIFY → ROW_NUMBER() in subquery
- $1, $2 in SELECT → Use column aliases
- :: casting → CAST() or ::
- CLUSTER BY → DISTKEY
- COPY INTO → COPY FROM S3
""",
        "BigQuery": """
BigQuery to Redshift:
- STRING → VARCHAR
- INT64 → BIGINT
- FLOAT64 → DOUBLE PRECISION
- BOOL → BOOLEAN
- BYTES → VARBYTE
- ARRAY<T> → SUPER type
- STRUCT<...> → SUPER type or separate columns
- UNNEST(array) → UNNEST (similar)
- ARRAY_AGG → LISTAGG or JSON_PARSE
- STRUCT(...) → JSON_PARSE
- SAFE_CAST → CAST with TRY_CAST
- IFNULL → COALESCE
- CURRENT_DATETIME() → GETDATE()
- TIMESTAMP_TRUNC → DATE_TRUNC
- FORMAT_TIMESTAMP → TO_CHAR
- PARSE_TIMESTAMP → TO_TIMESTAMP
- DATE_DIFF → DATEDIFF
- GENERATE_UUID() → Use external UUID generation
- ` backticks → " double quotes
- # for temp tables → # (same)
- PARTITION BY in window → PARTITION BY (same)
- QUALIFY → ROW_NUMBER() in subquery
"""
    }
    return rules.get(source_db, "")

def build_prompt(source_db: str, sql: str, include_explanation: bool) -> str:
    rules = get_conversion_rules(source_db)
    keywords = extract_sql_keywords(sql)
    
    prompt = f"""Convert this {source_db} SQL to Amazon Redshift SQL.

{rules}

Source SQL ({source_db}):
```sql
{sql}
```

Requirements:
1. Convert data types to Redshift equivalents
2. Replace unsupported functions
3. Preserve original logic exactly
4. Output valid, executable Redshift SQL

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

@app.post("/convert", response_model=ConversionResponse)
async def convert_sql(req: ConversionRequest, username: str = Depends(verify_credentials)):
    try:
        prompt = build_prompt(req.source_db, req.sql, req.include_explanation)
        
        response = bedrock.invoke_model(
            modelId='amazon.nova-pro-v1:0',
            body=json.dumps({
                "messages": [{"role": "user", "content": [{"text": prompt}]}],
                "inferenceConfig": {"maxTokens": 4096, "temperature": 0.1}
            })
        )
        
        result = json.loads(response['body'].read())
        content = result['output']['message']['content'][0]['text']
        
        if req.include_explanation:
            sql_match = re.search(r'```sql\n(.*?)\n```', content, re.DOTALL)
            redshift_sql = sql_match.group(1).strip() if sql_match else content
            exp_match = re.search(r'EXPLANATION:\n(.*)', content, re.DOTALL)
            explanation = exp_match.group(1).strip() if exp_match else None
        else:
            redshift_sql = re.sub(r'```sql\n|\n```|```', '', content).strip()
            explanation = None
        
        return ConversionResponse(
            redshift_sql=redshift_sql,
            explanation=explanation,
            source_db=req.source_db
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/supported-databases")
async def supported_databases(username: str = Depends(verify_credentials)):
    return {"databases": ["Teradata", "Oracle", "MySQL", "Clickhouse", "Snowflake", "BigQuery"]}

@app.post("/refresh")
async def refresh_features(username: str = Depends(verify_credentials)):
    try:
        REDSHIFT_DOCS = {
            "cluster_versions": "https://docs.aws.amazon.com/redshift/latest/mgmt/cluster-versions.html",
            "qualify": "https://docs.aws.amazon.com/redshift/latest/dg/r_QUALIFY_clause.html",
            "merge": "https://docs.aws.amazon.com/redshift/latest/dg/r_MERGE.html",
        }
        
        features = []
        
        req = urllib.request.Request(REDSHIFT_DOCS["cluster_versions"], headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')
            text = re.sub(r'<[^>]+>', ' ', html)
            
            if "QUALIFY" in text:
                features.append("QUALIFY clause is SUPPORTED")
            if "MERGE" in text:
                features.append("MERGE statement is SUPPORTED")
            if "SUPER" in text:
                features.append("SUPER data type is SUPPORTED")
        
        return {
            "statusCode": 200,
            "message": "Features refreshed successfully",
            "features_count": len(features),
            "features": features,
            "updated_at": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

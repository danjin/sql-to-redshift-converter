import json
import boto3
import re
import urllib.request
from datetime import datetime

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
features_table = dynamodb.Table('sql-converter-features')

REDSHIFT_DOCS = {
    "cluster_versions": "https://docs.aws.amazon.com/redshift/latest/mgmt/cluster-versions.html",
    "qualify": "https://docs.aws.amazon.com/redshift/latest/dg/r_QUALIFY_clause.html",
    "merge": "https://docs.aws.amazon.com/redshift/latest/dg/r_MERGE.html",
    "window_functions": "https://docs.aws.amazon.com/redshift/latest/dg/c_Window_functions.html",
    "super_type": "https://docs.aws.amazon.com/redshift/latest/dg/r_SUPER_type.html",
    "json_functions": "https://docs.aws.amazon.com/redshift/latest/dg/json-functions.html",
    "string_functions": "https://docs.aws.amazon.com/redshift/latest/dg/String_functions_header.html",
    "date_functions": "https://docs.aws.amazon.com/redshift/latest/dg/Date_functions_header.html",
    "aggregate_functions": "https://docs.aws.amazon.com/redshift/latest/dg/c_Aggregate_Functions.html",
    "conditional_functions": "https://docs.aws.amazon.com/redshift/latest/dg/c_conditional_expressions.html"
}

def fetch_page(url):
    """Fetch documentation page"""
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')
            text = re.sub(r'<[^>]+>', ' ', html)
            text = re.sub(r'\s+', ' ', text).strip()
            return text[:100000]  # Get 100K chars to capture all features
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return None

def extract_features():
    """Extract Redshift features from documentation"""
    features = []
    
    # Check cluster versions page for latest features
    versions_doc = fetch_page(REDSHIFT_DOCS["cluster_versions"])
    if versions_doc:
        # Check first 100K chars to capture all recent patches
        recent = versions_doc[:100000]
        
        # Look for key feature mentions
        if "QUALIFY" in recent:
            features.append("QUALIFY clause is SUPPORTED (filters window function results)")
        if "MERGE" in recent:
            features.append("MERGE statement is SUPPORTED (upsert operations)")
        if "SUPER" in recent:
            features.append("SUPER data type is SUPPORTED (semi-structured data, up to 16MB)")
        if "UNNEST" in recent or "unnest" in recent.lower():
            features.append("UNNEST is SUPPORTED (converts arrays to rows)")
        if "TRY_CAST" in recent:
            features.append("TRY_CAST is SUPPORTED (safe type conversion)")
        if "GROUP BY ALL" in recent:
            features.append("GROUP BY ALL is SUPPORTED")
        if "EXCLUDE" in recent:
            features.append("EXCLUDE keyword is SUPPORTED")
        if "PIVOT" in recent or "pivot" in recent.lower():
            features.append("PIVOT operator is SUPPORTED")
        if "INTERVAL" in recent:
            features.append("INTERVAL data type is SUPPORTED")
        if "H3_" in recent:
            features.append("H3 spatial functions are SUPPORTED")
        if "GET_NUMBER_ATTRIBUTES" in recent:
            features.append("GET_NUMBER_ATTRIBUTES function is SUPPORTED")
    
    # Fallback checks on specific pages
    if not any("QUALIFY" in f for f in features):
        qualify_doc = fetch_page(REDSHIFT_DOCS["qualify"])
        if qualify_doc and "QUALIFY" in qualify_doc:
            features.append("QUALIFY clause is SUPPORTED")
    
    if not any("MERGE" in f for f in features):
        merge_doc = fetch_page(REDSHIFT_DOCS["merge"])
        if merge_doc and "MERGE" in merge_doc:
            features.append("MERGE statement is SUPPORTED")
    
    # Check JSON functions
    json_doc = fetch_page(REDSHIFT_DOCS["json_functions"])
    if json_doc and "JSON" in json_doc:
        features.append("JSON functions are SUPPORTED (JSON_PARSE, JSON_EXTRACT_PATH_TEXT, etc.)")
    
    return features if features else ["Redshift SQL features detected"]

def handler(event, context):
    """Scheduled Lambda to refresh Redshift features"""
    print("Starting feature refresh...")
    
    # Extract features from docs
    features = extract_features()
    
    print(f"Found {len(features)} features")
    
    # Save to DynamoDB
    try:
        features_table.put_item(Item={
            'feature_key': 'redshift_features',
            'features': features,
            'updated_at': datetime.now().isoformat(),
            'source': 'scheduled_refresh'
        })
        print("Features saved to DynamoDB")
    except Exception as e:
        print(f"Error saving to DynamoDB: {e}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Features refreshed successfully',
            'features_count': len(features),
            'features': features
        })
    }

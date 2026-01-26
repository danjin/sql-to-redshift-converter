# Detecting New Redshift SQL Functions

## Current Capabilities

### ✅ What Works Now

The system can detect new functions if you:
1. **Add the documentation URL** to the refresh Lambda
2. **Redeploy** the refresh Lambda
3. **Trigger refresh** (automatic weekly or manual)

### ❌ Current Limitations

- **Not fully automatic**: Requires manual URL addition
- **No AWS What's New monitoring**: Doesn't watch AWS announcements
- **Simple text extraction**: May miss complex function descriptions
- **Pre-defined pages only**: Won't discover new doc pages automatically

## How to Add New Function Detection

### Method 1: Add Specific Function Page (Recommended)

When AWS releases a new function (e.g., `NEW_FUNCTION`):

**Step 1: Find the documentation URL**
```
https://docs.aws.amazon.com/redshift/latest/dg/r_NEW_FUNCTION.html
```

**Step 2: Edit `backend/refresh_features.py`**
```python
REDSHIFT_DOCS = {
    "qualify": "https://docs.aws.amazon.com/redshift/latest/dg/r_QUALIFY_clause.html",
    "merge": "https://docs.aws.amazon.com/redshift/latest/dg/r_MERGE.html",
    # Add new function:
    "new_function": "https://docs.aws.amazon.com/redshift/latest/dg/r_NEW_FUNCTION.html"
}

def extract_features():
    # ... existing code ...
    
    # Add new function check:
    new_func_doc = fetch_page(REDSHIFT_DOCS["new_function"])
    if new_func_doc and "NEW_FUNCTION" in new_func_doc:
        features.append("NEW_FUNCTION is SUPPORTED (description)")
    
    return features
```

**Step 3: Redeploy**
```bash
cd sql-converter/backend
zip refresh-lambda.zip refresh_features.py
aws lambda update-function-code \
  --function-name sql-converter-refresh-features \
  --zip-file fileb://refresh-lambda.zip \
  --region us-east-1
```

**Step 4: Trigger refresh**
```bash
# Via CLI
./refresh-features.sh refresh

# Or via web interface
Click "🔄 Refresh Features" button
```

### Method 2: Monitor Function Category Pages

The system now monitors these category pages:
- String functions
- Date functions
- Aggregate functions
- Conditional functions
- JSON functions
- Window functions

**These automatically extract function names!**

Example: If AWS adds `NEW_STRING_FUNC()` to the string functions page, it will be detected automatically on next refresh.

### Method 3: Watch AWS What's New (Manual)

**Subscribe to AWS What's New:**
1. Go to https://aws.amazon.com/about-aws/whats-new/
2. Filter by "Amazon Redshift"
3. Subscribe to RSS feed
4. When new function announced → Add to refresh Lambda

**Example announcement:**
```
"Amazon Redshift now supports the PIVOT operator"
→ Add PIVOT documentation URL
→ Redeploy refresh Lambda
→ Trigger refresh
```

## Automatic Detection (Future Enhancement)

### Option A: AWS What's New RSS Monitor

Add a Lambda that:
1. Monitors AWS What's New RSS feed
2. Filters for Redshift announcements
3. Extracts new feature names
4. Automatically adds to feature list

**Implementation:**
```python
import feedparser

def monitor_aws_news():
    feed = feedparser.parse('https://aws.amazon.com/about-aws/whats-new/recent/feed/')
    
    for entry in feed.entries:
        if 'redshift' in entry.title.lower():
            # Extract feature name
            # Add to feature list
            # Notify admin
```

**Cost:** ~$0.10/month (daily checks)

### Option B: Documentation Diff Monitor

Monitor the entire Redshift documentation:
1. Crawl all Redshift doc pages weekly
2. Compare with previous version
3. Detect new pages or sections
4. Extract new function names

**Cost:** ~$1/month (weekly crawls)

### Option C: Full RAG with Knowledge Base

Use Amazon Bedrock Knowledge Bases:
1. Crawl all Redshift documentation
2. Create vector embeddings
3. Semantic search for relevant functions
4. Always up-to-date with latest docs

**Cost:** ~$700/month (OpenSearch Serverless)

## Current Function Coverage

The system currently tracks:

**Clauses & Statements:**
- ✅ QUALIFY clause
- ✅ MERGE statement

**Data Types:**
- ✅ SUPER type

**Function Categories:**
- ✅ JSON functions (JSON_PARSE, JSON_EXTRACT_PATH_TEXT, etc.)
- ✅ String functions (auto-detected from category page)
- ✅ Date functions (auto-detected from category page)
- ✅ Aggregate functions (auto-detected from category page)
- ✅ Window functions (monitored)

## Real-World Example

**Scenario:** AWS announces "Redshift now supports PIVOT operator"

**Current Process:**
1. See announcement on AWS What's New
2. Find doc URL: `https://docs.aws.amazon.com/redshift/latest/dg/r_PIVOT.html`
3. Edit `refresh_features.py`:
   ```python
   "pivot": "https://docs.aws.amazon.com/redshift/latest/dg/r_PIVOT.html"
   ```
4. Add extraction:
   ```python
   pivot_doc = fetch_page(REDSHIFT_DOCS["pivot"])
   if pivot_doc and "PIVOT" in pivot_doc:
       features.append("PIVOT operator is SUPPORTED")
   ```
5. Redeploy: `zip + aws lambda update-function-code`
6. Refresh: Click button or run CLI
7. Done! Conversions now know about PIVOT

**Time:** ~5 minutes

## Recommendations

### For Most Users (Current System)
- ✅ Check AWS What's New monthly
- ✅ Add important new functions manually
- ✅ Redeploy refresh Lambda
- ✅ Cost: Free
- ✅ Effort: 5 min/month

### For High-Volume Users
- Consider Option A: RSS Monitor (~$0.10/month)
- Automatic detection of new features
- Email notifications
- Minimal maintenance

### For Enterprise
- Consider Option C: Full RAG (~$700/month)
- Always up-to-date
- Semantic understanding
- Best accuracy

## Testing New Function Detection

**Test the current system:**
```bash
# 1. Check current features
./refresh-features.sh list

# 2. Add a new function to refresh_features.py
# 3. Redeploy
cd backend
zip refresh-lambda.zip refresh_features.py
aws lambda update-function-code \
  --function-name sql-converter-refresh-features \
  --zip-file fileb://refresh-lambda.zip \
  --region us-east-1

# 4. Trigger refresh
./refresh-features.sh refresh

# 5. Verify new feature appears
./refresh-features.sh list
```

## Summary

**Can it detect new SQL functions?**
- ✅ **Yes**, if you add the documentation URL
- ✅ **Partially automatic** for function category pages
- ❌ **Not fully automatic** for brand new features

**Best approach:**
1. Subscribe to AWS What's New for Redshift
2. When new function announced → Add URL to refresh Lambda
3. Redeploy (5 minutes)
4. System automatically includes in conversions

**Future enhancement:**
- Implement RSS monitor for fully automatic detection
- Cost: ~$0.10/month
- Zero maintenance

Want me to implement the RSS monitor for automatic detection?

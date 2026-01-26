#!/bin/bash
set -e

# Load configuration
if [ ! -f infrastructure/kb-config.json ]; then
  echo "❌ Error: kb-config.json not found. Run setup-knowledge-base.sh first."
  exit 1
fi

KB_BUCKET=$(jq -r '.kb_bucket' infrastructure/kb-config.json)
REGION=$(jq -r '.region' infrastructure/kb-config.json)

echo "📚 Downloading Redshift documentation..."
echo ""

# Create temp directory
mkdir -p /tmp/redshift-docs

# Download key documentation pages
echo "📥 Downloading SQL reference documentation..."

# SQL Commands
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/c_SQL_commands.html" > /tmp/redshift-docs/sql-commands.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/r_SELECT_synopsis.html" > /tmp/redshift-docs/select.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/r_MERGE.html" > /tmp/redshift-docs/merge.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/r_QUALIFY_clause.html" > /tmp/redshift-docs/qualify.html

# SQL Functions
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/c_SQL_functions.html" > /tmp/redshift-docs/sql-functions.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/String_functions_header.html" > /tmp/redshift-docs/string-functions.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/Date_functions_header.html" > /tmp/redshift-docs/date-functions.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/Math_functions.html" > /tmp/redshift-docs/math-functions.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/window-functions.html" > /tmp/redshift-docs/window-functions.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/json-functions.html" > /tmp/redshift-docs/json-functions.html

# Data Types
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/c_Supported_data_types.html" > /tmp/redshift-docs/data-types.html
curl -s "https://docs.aws.amazon.com/redshift/latest/dg/r_SUPER_type.html" > /tmp/redshift-docs/super-type.html

# Cluster versions (latest features)
curl -s "https://docs.aws.amazon.com/redshift/latest/mgmt/cluster-versions.html" > /tmp/redshift-docs/cluster-versions.html

# Convert HTML to text for better indexing
echo "🔄 Converting HTML to text..."
for file in /tmp/redshift-docs/*.html; do
  filename=$(basename "$file" .html)
  # Extract text content (remove HTML tags)
  sed 's/<[^>]*>//g' "$file" | sed 's/&nbsp;/ /g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g' > "/tmp/redshift-docs/${filename}.txt"
done

# Upload to S3
echo "☁️  Uploading to S3..."
aws s3 sync /tmp/redshift-docs/ s3://$KB_BUCKET/redshift-docs/ --region $REGION --exclude "*.html"

# Count files
FILE_COUNT=$(ls -1 /tmp/redshift-docs/*.txt | wc -l | tr -d ' ')

echo "✅ Uploaded $FILE_COUNT documentation files to s3://$KB_BUCKET/redshift-docs/"
echo ""
echo "📝 Next step: Run ./infrastructure/create-knowledge-base.sh"

# Cleanup
rm -rf /tmp/redshift-docs

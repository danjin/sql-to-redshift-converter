#!/bin/bash
set -e

REGION="us-east-1"
BUCKET_NAME="sql-converter-frontend-1768429667"
API_ENDPOINT="https://iq1letmtxa.execute-api.us-east-1.amazonaws.com"

echo "=== Setting up CloudFront Distribution ==="

# Create CloudFront Origin Access Identity
OAI_ID=$(aws cloudfront create-cloud-front-origin-access-identity \
    --cloud-front-origin-access-identity-config \
    CallerReference=$(date +%s),Comment="SQL Converter OAI" \
    --query 'CloudFrontOriginAccessIdentity.Id' \
    --output text 2>/dev/null || echo "")

if [ -z "$OAI_ID" ]; then
    echo "Using existing OAI or creating new one..."
    OAI_ID=$(aws cloudfront list-cloud-front-origin-access-identities \
        --query 'CloudFrontOriginAccessIdentityList.Items[0].Id' \
        --output text)
fi

echo "✓ OAI ID: $OAI_ID"

# Update bucket policy to allow CloudFront
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
        \"Sid\": \"CloudFrontAccess\",
        \"Effect\": \"Allow\",
        \"Principal\": {
            \"AWS\": \"arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $OAI_ID\"
        },
        \"Action\": \"s3:GetObject\",
        \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
    }]
}"

echo "✓ Bucket policy updated"

# Create CloudFront distribution
DIST_CONFIG=$(cat <<DISTCONFIG
{
    "CallerReference": "$(date +%s)",
    "Comment": "SQL Converter Frontend",
    "Enabled": true,
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [{
            "Id": "S3-$BUCKET_NAME",
            "DomainName": "$BUCKET_NAME.s3.amazonaws.com",
            "S3OriginConfig": {
                "OriginAccessIdentity": "origin-access-identity/cloudfront/$OAI_ID"
            }
        }]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-$BUCKET_NAME",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"]
        },
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {"Forward": "none"}
        },
        "MinTTL": 0,
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        }
    }
}
DISTCONFIG
)

echo "Creating CloudFront distribution (this takes 5-10 minutes)..."
DIST_ID=$(aws cloudfront create-distribution \
    --distribution-config "$DIST_CONFIG" \
    --query 'Distribution.Id' \
    --output text 2>/dev/null || echo "")

if [ -z "$DIST_ID" ]; then
    echo "Distribution may already exist, checking..."
    DIST_ID=$(aws cloudfront list-distributions \
        --query "DistributionList.Items[?Comment=='SQL Converter Frontend'].Id" \
        --output text | head -1)
fi

DOMAIN=$(aws cloudfront get-distribution --id $DIST_ID --query 'Distribution.DomainName' --output text)

echo ""
echo "=== Deployment Complete ==="
echo "CloudFront URL: https://$DOMAIN"
echo "API Endpoint: $API_ENDPOINT"
echo ""
echo "Note: CloudFront distribution is deploying. It may take 5-10 minutes to be fully available."

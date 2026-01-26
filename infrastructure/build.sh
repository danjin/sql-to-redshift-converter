#!/bin/bash
set -e

echo "Building Lambda deployment package..."

cd backend

# Create deployment package
rm -rf package lambda.zip
mkdir -p package

# Install minimal dependencies
pip3 install boto3==1.35.0 -t package/ --quiet

# Copy application code
cp lambda_handler.py package/

# Create zip
cd package
zip -r ../lambda.zip . -q
cd ..

echo "✓ Lambda package created: backend/lambda.zip"
echo "Size: $(du -h lambda.zip | cut -f1)"

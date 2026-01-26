#!/bin/bash

# Fix EC2 security after Epoxy mitigation
# This script:
# 1. Creates a new security group with restricted access
# 2. Restarts the instance with proper security

INSTANCE_ID="i-049f4645634d3d357"
REGION="us-east-1"
VPC_ID="vpc-7396670e"

# Get your current IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your IP: $MY_IP"

# Create new security group with authentication requirement
SG_NAME="sql-converter-sg-secure"
echo "Creating secure security group..."

SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "SQL Converter with restricted access" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query 'GroupId' \
    --output text)

echo "Security Group ID: $SG_ID"

# Allow SSH from your IP only
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "${MY_IP}/32" \
    --region "$REGION"

# Allow HTTP from your IP only (or remove this for internal use only)
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr "${MY_IP}/32" \
    --region "$REGION"

echo "Security group configured. To apply:"
echo "1. Start the instance: aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION"
echo "2. Modify security group: aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --groups $SG_ID --region $REGION"
echo ""
echo "Or use the authenticated version (app_secure.py) instead"

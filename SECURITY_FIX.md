# Security Remediation for SQL Converter

## Issue
AWS Epoxy detected your EC2 instance (i-049f4645634d3d357) is publicly accessible without authentication.

## Current Status
- Instance: **STOPPED** by Epoxy mitigation
- Security Group: Changed to `epoxy-mitigations-isolated-ec2-vpc-7396670e`
- Access: **BLOCKED**

## Recommended Solutions

### Option 1: Use Serverless (RECOMMENDED)
Deploy using Lambda + API Gateway instead of EC2. This is:
- More secure (no public server)
- More cost-effective (~$0.20/month vs EC2 costs)
- Already configured in your project

```bash
cd /Users/dnjin/sql-converter
./infrastructure/deploy.sh
```

Then terminate the EC2 instance:
```bash
aws ec2 terminate-instances --instance-ids i-049f4645634d3d357 --region us-east-1
```

### Option 2: Add Authentication to EC2
If you must use EC2:

1. **Deploy the secure version:**
```bash
# Copy secure app
cp backend/app_secure.py backend/app.py

# Update credentials in app.py (lines 23-24)
# USERNAME = "your-username"
# PASSWORD = "your-strong-password"

# Redeploy to EC2 (after starting it)
```

2. **Restore instance access:**
```bash
# Start instance
aws ec2 start-instances --instance-ids i-049f4645634d3d357 --region us-east-1

# Create new security group with IP restriction
./fix-security.sh

# Apply new security group
aws ec2 modify-instance-attribute \
    --instance-id i-049f4645634d3d357 \
    --groups <NEW_SG_ID> \
    --region us-east-1
```

### Option 3: Make it Internal Only
Restrict to VPC/corporate network:
- Remove public IP
- Use VPN or AWS PrivateLink
- Access only from internal network

## Next Steps
1. Choose your preferred option above
2. Respond to the Talos ticket explaining your mitigation
3. Test the secured deployment

## Files Created
- `backend/app_secure.py` - Version with HTTP Basic Auth
- `fix-security.sh` - Script to create restricted security group

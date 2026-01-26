# EC2 Deployment Guide

## Quick Setup

### 1. Launch EC2 Instance
```bash
aws ec2 run-instances \
  --image-id ami-0c02fb55b34c3f4f5 \
  --instance-type t3.small \
  --key-name YOUR_KEY_NAME \
  --security-group-ids sg-XXXXX \
  --iam-instance-profile Name=sql-converter-ec2-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sql-converter}]' \
  --region us-east-1
```

### 2. Configure Security Group
Allow inbound traffic:
- **Port 80** (HTTP) from your team's IP range
- **Port 22** (SSH) from your IP for management

### 3. Create IAM Role
The EC2 needs permissions to call Bedrock:
```bash
# Create role
aws iam create-role \
  --role-name sql-converter-ec2-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach Bedrock policy
aws iam attach-role-policy \
  --role-name sql-converter-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess

# Attach DynamoDB policy (for feature cache)
aws iam attach-role-policy \
  --role-name sql-converter-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name sql-converter-ec2-role

aws iam add-role-to-instance-profile \
  --instance-profile-name sql-converter-ec2-role \
  --role-name sql-converter-ec2-role
```

### 4. Deploy Application
```bash
# SSH into EC2
ssh -i YOUR_KEY.pem ec2-user@YOUR_EC2_IP

# Copy and run deployment script
# (Upload deploy-ec2.sh to EC2 first)
chmod +x deploy-ec2.sh
./deploy-ec2.sh
```

### 5. Access
Open `http://YOUR_EC2_IP` in browser

## Management Commands

```bash
# Check service status
sudo systemctl status sql-converter

# View logs
sudo journalctl -u sql-converter -f

# Restart service
sudo systemctl restart sql-converter

# Update code
cd /home/ec2-user/sql-converter
git pull
sudo systemctl restart sql-converter
```

## Optional: Add HTTPS

### Using Let's Encrypt (Free)
```bash
sudo yum install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

### Using ALB (Recommended for Production)
1. Create Application Load Balancer
2. Add SSL certificate from ACM
3. Point ALB to EC2 target group (port 80)
4. Update security group to allow traffic from ALB only

## Cost Estimate
- **t3.small**: ~$15/month (24/7)
- **t3.micro**: ~$7.50/month (sufficient for small teams)
- **Data transfer**: ~$0.09/GB

## Alternative: Docker Deployment

If you prefer Docker:

```dockerfile
# Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install -r requirements.txt uvicorn
COPY backend/ .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

```bash
# On EC2
docker build -t sql-converter .
docker run -d -p 8000:8000 --name sql-converter sql-converter
```

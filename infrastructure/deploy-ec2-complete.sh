#!/bin/bash

# Complete EC2 Deployment for SQL Converter in us-east-1
set -e

REGION="us-east-1"
INSTANCE_TYPE="t3.small"
KEY_NAME="sql-converter-key"
ROLE_NAME="sql-converter-ec2-role"
SG_NAME="sql-converter-sg"

echo "🚀 Starting EC2 deployment in $REGION..."

# Get default VPC
echo "Getting VPC..."
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)
echo "Using VPC: $VPC_ID"

# Create security group
echo "Creating security group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name $SG_NAME \
  --description "SQL Converter access" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text 2>/dev/null || \
  aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=$SG_NAME" --query "SecurityGroups[0].GroupId" --output text)
echo "Security Group: $SG_ID"

# Add security group rules
echo "Configuring security group rules..."
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $REGION 2>/dev/null || echo "Port 80 rule exists"

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region $REGION 2>/dev/null || echo "Port 22 rule exists"

# Create IAM role
echo "Creating IAM role..."
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role exists"

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess 2>/dev/null || true

# Create instance profile
echo "Creating instance profile..."
aws iam create-instance-profile \
  --instance-profile-name $ROLE_NAME 2>/dev/null || echo "Instance profile exists"

aws iam add-role-to-instance-profile \
  --instance-profile-name $ROLE_NAME \
  --role-name $ROLE_NAME 2>/dev/null || echo "Role already added"

# Wait for instance profile to be ready
echo "Waiting for IAM propagation..."
sleep 10

# Create key pair if doesn't exist
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &>/dev/null; then
  echo "Creating SSH key pair..."
  aws ec2 create-key-pair \
    --key-name $KEY_NAME \
    --region $REGION \
    --query 'KeyMaterial' \
    --output text > ${KEY_NAME}.pem
  chmod 400 ${KEY_NAME}.pem
  echo "✅ Key saved to ${KEY_NAME}.pem"
else
  echo "Key pair $KEY_NAME already exists"
fi

# Get latest Amazon Linux 2023 AMI
echo "Finding latest AMI..."
AMI_ID=$(aws ec2 describe-images \
  --region $REGION \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
  --output text)
echo "Using AMI: $AMI_ID"

# Create user data script
cat > user-data.sh <<'USERDATA'
#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Installing dependencies..."
dnf update -y
dnf install -y python3.11 python3.11-pip git nginx

echo "Cloning repository..."
cd /home/ec2-user
git clone https://github.com/YOUR_USERNAME/sql-converter.git || true
cd sql-converter

echo "Setting up Python..."
cd backend
python3.11 -m pip install --user -r requirements.txt uvicorn

echo "Creating systemd service..."
cat > /etc/systemd/system/sql-converter.service <<'EOF'
[Unit]
Description=SQL Converter API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/sql-converter/backend
ExecStart=/home/ec2-user/.local/bin/uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Configuring Nginx..."
cat > /etc/nginx/conf.d/sql-converter.conf <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        root /home/ec2-user/sql-converter/frontend;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

echo "Updating frontend API URL..."
sed -i 's|const API_URL = .*|const API_URL = "/api";|' /home/ec2-user/sql-converter/frontend/index.html

echo "Starting services..."
systemctl daemon-reload
systemctl enable sql-converter
systemctl start sql-converter
systemctl enable nginx
systemctl start nginx

echo "Deployment complete!"
USERDATA

# Launch EC2 instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name=$ROLE_NAME \
  --user-data file://user-data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=sql-converter}]" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
echo "Waiting for instance to start..."

aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo ""
echo "✅ Deployment initiated!"
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "SSH Key: ${KEY_NAME}.pem"
echo ""
echo "⏳ Waiting for application to be ready (this takes ~3 minutes)..."
echo ""
echo "To check progress:"
echo "  ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP} 'tail -f /var/log/user-data.log'"
echo ""
echo "Once ready, access at:"
echo "  http://${PUBLIC_IP}"
echo ""
echo "To SSH:"
echo "  ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"

# Cleanup
rm -f user-data.sh

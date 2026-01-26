#!/bin/bash

# EC2 Deployment Script for SQL Converter
# Run this ON your EC2 instance after SSH'ing in

set -e

echo "Installing dependencies..."
sudo yum update -y
sudo yum install -y python3.11 python3.11-pip git nginx

echo "Cloning/updating repository..."
cd /home/ec2-user
if [ -d "sql-converter" ]; then
    cd sql-converter && git pull
else
    git clone <YOUR_REPO_URL> sql-converter
    cd sql-converter
fi

echo "Setting up Python environment..."
cd backend
python3.11 -m pip install --user -r requirements.txt uvicorn

echo "Configuring systemd service..."
sudo tee /etc/systemd/system/sql-converter.service > /dev/null <<EOF
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
sudo tee /etc/nginx/conf.d/sql-converter.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        root /home/ec2-user/sql-converter/frontend;
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "Updating frontend API URL..."
sed -i 's|const API_URL = .*|const API_URL = "/api";|' /home/ec2-user/sql-converter/frontend/index.html

echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable sql-converter
sudo systemctl start sql-converter
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Opening firewall..."
sudo firewall-cmd --permanent --add-service=http 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true

echo ""
echo "✅ Deployment complete!"
echo "Access at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

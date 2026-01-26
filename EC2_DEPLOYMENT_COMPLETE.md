# EC2 Deployment - Complete ✅

## Deployment Summary

Your SQL Converter is now live on EC2!

**Access URL:** http://100.31.153.136

## What Was Deployed

### Infrastructure
- **EC2 Instance:** i-049f4645634d3d357 (t3.small)
- **Region:** us-east-1
- **Security Group:** sg-03ae27009fd8882d3
- **IAM Role:** sql-converter-ec2-role (with Bedrock + DynamoDB access)
- **SSH Key:** sql-converter-key.pem

### Services Running
- **Backend API:** Python FastAPI on port 8000 (systemd service)
- **Web Server:** Nginx on port 80
- **AI Model:** Amazon Nova Pro via Bedrock

### Architecture
```
Internet → Nginx (port 80) → {
    / → Frontend (HTML/JS)
    /api/ → Backend API (port 8000) → Bedrock
}
```

## Management Commands

### SSH Access
```bash
ssh -i sql-converter-key.pem ec2-user@100.31.153.136
```

### Service Management
```bash
# Check status
sudo systemctl status sql-converter

# View logs
sudo journalctl -u sql-converter -f

# Restart
sudo systemctl restart sql-converter

# Stop/Start
sudo systemctl stop sql-converter
sudo systemctl start sql-converter
```

### Update Code
```bash
# On your local machine
cd /Users/dnjin/sql-converter
tar -czf update.tar.gz backend/app.py frontend/index.html
scp -i sql-converter-key.pem update.tar.gz ec2-user@100.31.153.136:~

# On EC2
ssh -i sql-converter-key.pem ec2-user@100.31.153.136
cd ~/sql-converter
tar -xzf ~/update.tar.gz
sudo systemctl restart sql-converter
```

### Nginx Management
```bash
# Check status
sudo systemctl status nginx

# Restart
sudo systemctl restart nginx

# View logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

## Cost Estimate

### Monthly Costs
- **EC2 t3.small:** ~$15/month (24/7)
- **Data Transfer:** ~$0.09/GB
- **Bedrock (Nova Pro):** ~$0.0008 per 1K tokens
- **Total:** ~$15-20/month for moderate usage

### Cost Optimization
To reduce costs, you can:
1. Use t3.micro instead (~$7.50/month)
2. Stop instance when not in use
3. Use Reserved Instances for 1-year commitment (40% savings)

## Security Notes

### Current Setup
- ✅ IAM role for AWS service access (no hardcoded credentials)
- ✅ Security group restricts access to ports 80 and 22
- ⚠️ HTTP only (no HTTPS)
- ⚠️ No authentication

### Recommended Improvements
1. **Add HTTPS:** Use Let's Encrypt or AWS Certificate Manager
2. **Restrict SSH:** Limit port 22 to your IP only
3. **Add Authentication:** Implement user login
4. **Use ALB:** Put Application Load Balancer in front for SSL termination

## Sharing with Team

Simply share this URL with your team:
```
http://100.31.153.136
```

They can access it from any browser without any setup.

## Troubleshooting

### API Not Working
```bash
# Check if service is running
sudo systemctl status sql-converter

# Check logs
sudo journalctl -u sql-converter -n 50

# Test API directly
curl http://localhost:8000/health
```

### Frontend Not Loading
```bash
# Check Nginx
sudo systemctl status nginx

# Check permissions
ls -la /home/ec2-user/sql-converter/frontend/

# Test locally
curl http://localhost/
```

### Bedrock Errors
```bash
# Verify IAM role
aws sts get-caller-identity

# Test Bedrock access
aws bedrock-runtime invoke-model \
  --model-id amazon.nova-pro-v1:0 \
  --body '{"messages":[{"role":"user","content":[{"text":"test"}]}],"inferenceConfig":{"maxTokens":100}}' \
  --region us-east-1 \
  output.json
```

## Cleanup (When Done)

To remove everything:
```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids i-049f4645634d3d357 --region us-east-1

# Delete security group (after instance terminates)
aws ec2 delete-security-group --group-id sg-03ae27009fd8882d3 --region us-east-1

# Delete IAM role
aws iam remove-role-from-instance-profile \
  --instance-profile-name sql-converter-ec2-role \
  --role-name sql-converter-ec2-role

aws iam delete-instance-profile --instance-profile-name sql-converter-ec2-role

aws iam detach-role-policy \
  --role-name sql-converter-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess

aws iam detach-role-policy \
  --role-name sql-converter-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

aws iam delete-role --role-name sql-converter-ec2-role

# Delete key pair
aws ec2 delete-key-pair --key-name sql-converter-key --region us-east-1
rm sql-converter-key.pem
```

## Next Steps

1. **Test the application:** Open http://100.31.153.136 in your browser
2. **Share with team:** Send them the URL
3. **Monitor usage:** Check CloudWatch metrics for the EC2 instance
4. **Add HTTPS:** Follow the guide in EC2_DEPLOYMENT.md
5. **Set up backups:** Consider taking AMI snapshots

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review logs: `sudo journalctl -u sql-converter -f`
3. Test API: `curl http://100.31.153.136/api/health`

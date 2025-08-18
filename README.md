# CourierX Mail Server

A self-configuring, production-ready mail server deployed on AWS infrastructure with automated setup and external DNS management.

## 🏗️ Architecture

CourierX uses a streamlined architecture that prioritizes reliability, security, and cost-effectiveness:

- **AWS EC2 (t3.small)**: Free Tier eligible instance running Ubuntu 22.04
- **Elastic IP**: Static IP address for consistent mail delivery
- **Cloud-Init**: Self-configuring setup script for complete automation
- **Security Group**: Minimal port exposure with firewall protection
- **S3 + DynamoDB**: Remote Terraform state with locking
- **External DNS**: Manual configuration at your DNS provider (Hostinger)

## ✨ Features

### Mail Services

- **Postfix**: SMTP server with TLS encryption
- **Dovecot**: IMAP server for mail retrieval
- **OpenDKIM**: Email authentication and signing
- **Automatic Forwarding**: Route support emails to external address

### Security

- **Fail2ban**: Intrusion prevention
- **UFW Firewall**: Host-based network security
- **SASL Authentication**: Secure SMTP authentication
- **SPF/DKIM/DMARC**: Email authentication protocols

### DevOps

- **Infrastructure as Code**: Complete Terraform automation
- **GitHub Actions**: OIDC-based secure deployment
- **Remote State**: S3 backend with DynamoDB locking
- **Self-Healing**: Cloud-init eliminates manual configuration

## 🚀 Quick Start

### Prerequisites

1. AWS account with Free Tier access
2. Domain name with external DNS provider (e.g., Hostinger)
3. GitHub repository with Actions enabled
4. SSH key pair for server access

### Setup Steps

#### 1. Create AWS Resources

```bash
# S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket your-courierx-terraform-state \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

# DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region eu-central-1
```

#### 2. Configure GitHub

Set up repository secrets:

- `AWS_ROLE_ARN`: IAM role ARN for OIDC authentication
- `DOMAIN_NAME`: Your domain (e.g., example.com)
- `SSH_PUBLIC_KEY`: Your SSH public key
- `NOREPLY_PASS`: Password for noreply@domain
- `SUPPORT_PASS`: Password for support@domain
- `FORWARD_TO`: External email for support forwarding

#### 3. Deploy Infrastructure

1. Go to GitHub Actions → "Deploy CourierX Mail Server"
2. Click "Run workflow"
3. Select environment from dropdown:
   - **staging**: For testing changes
   - **prod**: For production deployment
4. Monitor deployment logs
5. Note the server IP from outputs

#### 4. Configure DNS

Create these records in your DNS provider:

| Type | Name | Value | Priority |
|------|------|-------|----------|
| A | mail | SERVER_IP | - |
| MX | @ | mail.yourdomain.com | 10 |
| TXT | @ | "v=spf1 mx ~all" | - |
| TXT | _dmarc | "v=DMARC1; p=none; rua=mailto:admin@yourdomain.com" | - |
| TXT | mail._domainkey | [DKIM_KEY] | - |

#### 5. Retrieve DKIM Key

```bash
ssh -i your-key ubuntu@SERVER_IP
sudo cat /etc/opendkim_public_key.txt
```

## 📁 Project Structure

```code
courierx/
├── terraform/
│   ├── backend.tf          # S3 remote state configuration
│   ├── main.tf             # Core infrastructure resources
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # DNS setup instructions
│   ├── provider.tf         # AWS provider configuration
│   ├── user_data.sh        # Cloud-init setup script
│   ├── staging.tfvars      # Staging environment configuration
│   └── prod.tfvars         # Production environment configuration
├── .github/workflows/
│   └── deploy.yml          # GitHub Actions deployment
├── scripts/                # Legacy scripts (deprecated)
├── SETUP.md               # Detailed setup instructions
├── ENVIRONMENTS.md        # Environment configuration guide
├── MIGRATION_SUMMARY.md   # Architecture changes explanation
└── README.md              # This file
```

## 🔧 Configuration

### Mail Accounts

- `noreply@yourdomain.com`: Outbound mail only (SMTP auth)
- `support@yourdomain.com`: Forwards to external email

### Ports

- **22**: SSH access
- **25**: SMTP (inbound mail)
- **587**: SMTP submission (TLS)
- **993**: IMAPS (secure IMAP)

### Services

- **Postfix**: Mail transfer agent
- **Dovecot**: IMAP server
- **OpenDKIM**: DKIM signing
- **Fail2ban**: Intrusion prevention

## 🛡️ Security

### Network Security

- Custom security group with minimal ports
- UFW firewall on instance
- Fail2ban for intrusion prevention
- SSH key-based authentication only

### Email Security

- TLS encryption for SMTP
- DKIM signing for authentication
- SPF records for sender validation
- DMARC policy for domain protection

### Infrastructure Security

- OIDC authentication (no long-lived keys)
- Encrypted Terraform state
- State locking prevents conflicts
- Immutable infrastructure pattern

## 💰 Cost Optimization

### AWS Free Tier Usage

- **EC2 t3.small**: 750 hours/month (24/7 operation)
- **Elastic IP**: Free when attached
- **S3**: 5GB storage (sufficient for state)
- **DynamoDB**: 25GB storage, 25 WCU/RCU
- **Data Transfer**: 100GB/month outbound

### Monthly Cost: ~$0 (Free Tier)

## 📊 Monitoring

### Log Files

```bash
# Setup logs
sudo tail -f /var/log/courierx-setup.log

# Mail logs
sudo tail -f /var/log/mail.log

# Service status
sudo systemctl status postfix dovecot opendkim
```

### Health Checks

```bash
# Test SMTP authentication
swaks --to test@gmail.com \
      --from noreply@yourdomain.com \
      --server mail.yourdomain.com:587 \
      --auth-user noreply@yourdomain.com \
      --auth-password PASSWORD

# Check mail queue
sudo postqueue -p

# Verify DKIM
sudo opendkim-testkey -d yourdomain.com -s mail
```

## 🚨 Troubleshooting

### Common Issues

#### DNS propagation delays

- Wait up to 24 hours for global propagation
- Use multiple DNS checkers to verify

#### DKIM verification failed

- Ensure DKIM record matches exactly
- Check for extra spaces or formatting issues

#### Emails marked as spam

- Verify all DNS records are correct
- Warm up IP reputation gradually
- Check with mail-tester.com

#### Connection refused

- Verify security group allows required ports
- Check if services are running
- Ensure Elastic IP is properly attached

### Support Commands

```bash
# View setup summary
sudo cat /root/courierx-setup-summary.txt

# Check service logs
sudo journalctl -u postfix -f
sudo journalctl -u dovecot -f
sudo journalctl -u opendkim -f

# Test configuration
sudo postfix check
sudo dovecot -n
```

## 🔄 Updates and Maintenance

### Infrastructure Updates

- Modify Terraform configuration
- Run GitHub Actions workflow
- Monitor deployment logs

### Server Updates

```bash
# System updates
sudo apt update && sudo apt upgrade

# Service restarts
sudo systemctl restart postfix dovecot opendkim
```

### Backup Strategy

- Terraform state versioned in S3
- Configuration files in Git
- DKIM keys backed up during setup

## 📚 Documentation

- [`SETUP.md`](SETUP.md) - Detailed setup instructions
- [`MIGRATION_SUMMARY.md`](MIGRATION_SUMMARY.md) - Architecture improvements
- [AWS Free Tier](https://aws.amazon.com/free/) - Cost information
- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Dovecot Documentation](https://doc.dovecot.org/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes in staging environment
4. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**CourierX** - Self-configuring mail server infrastructure that just works. 📧

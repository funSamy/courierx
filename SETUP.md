# CourierX Mail Server - Setup Instructions

This document provides step-by-step instructions for setting up your CourierX mail server with the new architecture.

## Prerequisites

### 1. AWS Account Setup

- Ensure you have an AWS account
- Set up billing alerts to monitor costs
- Have AWS CLI configured locally (for initial setup)

### 2. Required AWS Resources (Free Tier)

Before deploying, create these resources manually:

#### S3 Bucket for Terraform State

```bash
aws s3api create-bucket \
  --bucket courierx-terraform-state-bucket \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket courierx-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

#### DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region eu-central-1
```

### 3. GitHub OIDC Setup

Set up OpenID Connect for secure AWS authentication:

#### Create IAM OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### Create IAM Role for GitHub Actions

Create a role with the following trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/courrierx:*"
        }
      }
    }
  ]
}
```

And attach this permission policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "*"
    }
  ]
}
```

## Configuration

### 1. Update Backend Configuration

Edit `terraform/backend.tf` and change the bucket name:

```hcl
bucket = "your-unique-terraform-state-bucket-name"
```

### 2. GitHub Secrets

Set up the following secrets in your GitHub repository:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ROLE_ARN` | ARN of the IAM role for OIDC | `arn:aws:iam::123456789012:role/GitHubAction-AssumeRole-CourierX` |
| `DOMAIN_NAME` | Your domain name | `example.com` |
| `SSH_PUBLIC_KEY` | Your SSH public key | `ssh-rsa AAAAB3NzaC1yc2E...` |
| `NOREPLY_PASS` | Password for noreply@domain | Strong password |
| `SUPPORT_PASS` | Password for support@domain | Strong password |
| `FORWARD_TO` | External email for forwarding | `admin@gmail.com` |

## Deployment

### 1. Run the GitHub Action

1. Go to your repository's Actions tab
2. Select "Deploy CourierX Mail Server"
3. Click "Run workflow"
4. Choose environment (prod/staging)
5. Monitor the deployment logs

### 2. Configure DNS Records

After deployment, use the output instructions to configure DNS records in Hostinger:

1. **A Record**: `mail.yourdomain.com` → Server IP
2. **MX Record**: `yourdomain.com` → `mail.yourdomain.com`
3. **SPF Record**: TXT record for sender validation
4. **DMARC Record**: TXT record for email authentication policy
5. **DKIM Record**: TXT record (retrieve from server after setup)

### 3. Retrieve DKIM Key

After the server finishes setup (5-10 minutes):

```bash
ssh -i your-private-key ubuntu@SERVER_IP
sudo cat /etc/opendkim_public_key.txt
```

Copy the content and create the DKIM DNS record.

## Verification

### DNS Propagation

Check DNS records:

```bash
dig MX yourdomain.com
dig TXT yourdomain.com
dig TXT mail._domainkey.yourdomain.com
dig TXT _dmarc.yourdomain.com
```

### Email Testing

1. Send a test email from `noreply@yourdomain.com`
2. Send an email to `support@yourdomain.com` (should forward)
3. Check email headers for DKIM signatures

## Monitoring and Maintenance

### Log Files

- Setup log: `/var/log/courierx-setup.log`
- Postfix logs: `/var/log/mail.log`
- Dovecot logs: `/var/log/dovecot.log`

### Service Status

```bash
sudo systemctl status postfix dovecot opendkim fail2ban
```

### SSL Certificates

The initial setup uses self-signed certificates. For production, consider:

```bash
sudo certbot certonly --standalone -d mail.yourdomain.com
```

## Troubleshooting

### Common Issues

1. **DNS not propagating**: Wait up to 24 hours, check with multiple DNS checkers
2. **DKIM verification failed**: Ensure DKIM record matches exactly (no extra spaces)
3. **Emails marked as spam**: Verify all DNS records, warm up IP reputation gradually
4. **Can't connect to server**: Check security group rules, ensure EIP is attached

### Useful Commands

```bash
# Check mail queue
sudo postqueue -p

# Test SMTP authentication
swaks --to test@gmail.com --from noreply@yourdomain.com --server mail.yourdomain.com:587 --auth-user noreply@yourdomain.com --auth-password PASSWORD

# View DKIM key
sudo cat /etc/opendkim/keys/yourdomain.com/mail.txt
```

## Security Considerations

1. **Restrict SSH access**: Update security group to allow SSH only from your IP
2. **Enable automatic updates**: Consider `unattended-upgrades`
3. **Monitor fail2ban**: Check for blocked IPs regularly
4. **Backup strategy**: Set up regular backups of configuration files

## Cost Optimization

- **Monitor usage**: Set up AWS billing alerts
- **Free Tier limits**: 750 hours/month for t3.small (sufficient for 24/7 operation)
- **Data transfer**: 100GB/month free (more than enough for personal use)
- **Storage**: Minimal storage used for configuration

## Support

For issues:

1. Check the setup logs on the server
2. Verify DNS configuration
3. Test individual components (Postfix, Dovecot, OpenDKIM)
4. Review AWS CloudTrail for infrastructure issues

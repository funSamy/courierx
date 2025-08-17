# Environment Configuration Guide

This guide explains how to configure and deploy CourierX to different environments using the new `.tfvars` file approach.

## Environment Structure

CourierX now supports clean environment separation using Terraform variable files:

```code
terraform/
├── staging.tfvars     # Staging environment configuration
├── prod.tfvars        # Production environment configuration
├── backend.tf         # Shared backend configuration
└── ...               # Other Terraform files
```

## Environment Configuration Files

### `staging.tfvars`

- Environment tags for staging identification
- Same instance type (t2.micro for Free Tier)
- Optional staging subdomain support
- Development-focused configuration

### `prod.tfvars`

- Production environment tags
- Same instance type (t2.micro for cost efficiency)
- Production-ready configuration
- Additional backup tags for operational clarity

## Deployment Workflow

### 1. Manual Trigger

When you run the GitHub Actions workflow:

1. Go to **Actions** → **Deploy CourierX Mail Server**
2. Click **Run workflow**
3. Select environment from dropdown:
   - `staging` - Uses `staging.tfvars`
   - `prod` - Uses `prod.tfvars`
4. Click **Run workflow**

### 2. Environment Selection

The workflow automatically:

- Validates the selected environment configuration file exists
- Displays the configuration being used
- Applies the appropriate `.tfvars` file with `-var-file=<environment>.tfvars`
- Tags resources with the correct environment labels

## Required GitHub Secrets

Configure these secrets in your repository settings (same for all environments):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ROLE_ARN` | OIDC IAM role ARN | `arn:aws:iam::123456789012:role/GitHubAction-AssumeRole-CourierX` |
| `DOMAIN_NAME` | Your domain name | `example.com` |
| `SSH_PUBLIC_KEY` | SSH public key for server access | `ssh-rsa AAAAB3NzaC1yc2E...` |
| `NOREPLY_PASS` | Password for noreply@domain | Strong password |
| `SUPPORT_PASS` | Password for support@domain | Strong password |
| `FORWARD_TO` | External email for support forwarding | `admin@gmail.com` |

## Environment-Specific Backend (Optional)

For complete environment isolation, you can use separate Terraform backends:

### Option 1: Shared Backend (Current)

- Single S3 bucket with different state keys
- Cost-effective and simple
- Suitable for personal projects

### Option 2: Separate Backends (Advanced)

Create environment-specific backend files:

**`terraform/backend-staging.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "courierx-terraform-state-staging"
    key            = "courierx/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock-staging"
    encrypt        = true
  }
}
```

**`terraform/backend-prod.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "courierx-terraform-state-prod"
    key            = "courierx/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock-prod"
    encrypt        = true
  }
}
```

Then modify the workflow to copy the appropriate backend file before `terraform init`:

```yaml
- name: Configure Backend for Environment
  run: |
    cp backend-${{ github.event.inputs.environment }}.tf backend.tf
  working-directory: ./terraform
```

## Resource Tagging

Each environment automatically applies appropriate tags:

### Staging Tags

```hcl
tags = {
  Project     = "CourierX"
  Environment = "Staging"
  ManagedBy   = "Terraform"
  Purpose     = "Mail Server"
}
```

### Production Tags

```hcl
tags = {
  Project     = "CourierX"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Purpose     = "Mail Server"
  Backup      = "Required"
}
```

## DNS Configuration

### Same Domain Approach (Current)

Both environments use the same domain with different server instances:

- Staging: Deploy temporarily for testing
- Production: Long-running production server

### Subdomain Approach (Optional)

Use different subdomains for each environment:

- Staging: `staging.yourdomain.com`
- Production: `yourdomain.com`

To enable subdomain approach, uncomment and modify the `domain_name` variable in the respective `.tfvars` file.

## Cost Considerations

### Free Tier Usage

- Both environments use `t2.micro` instances
- Can run one environment at a time within Free Tier
- Or alternate between environments for testing

### Resource Management

- Use staging for testing changes
- Deploy to production after validation
- Consider destroying staging after testing to save costs

## Best Practices

### Development Workflow

1. Test changes in staging first
2. Validate DNS configuration and email functionality
3. Destroy staging environment after testing
4. Deploy to production with confidence

### Configuration Management

- Keep secrets in GitHub repository secrets (never in `.tfvars`)
- Use `.tfvars` files only for non-sensitive configuration
- Document environment-specific differences

### Security

- Same security configuration for both environments
- Environment isolation through tagging and naming
- Consistent OIDC authentication

## Troubleshooting

### Missing Configuration File

If you see "Configuration file not found" error:

- Ensure both `staging.tfvars` and `prod.tfvars` exist in the `terraform/` directory
- Check the environment name matches exactly (case-sensitive)

### Backend State Conflicts

If using shared backend:

- Different environments use same state file
- Only deploy one environment at a time
- Consider separate backends for true isolation

### Environment Validation

The workflow includes validation steps that will:

- Check if the selected `.tfvars` file exists
- Display the configuration being applied
- Show environment-specific resource naming

This approach provides clean environment separation while remaining within GitHub's free tier limitations and maintaining simplicity.

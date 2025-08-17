# Production Environment Configuration
# This file contains production-specific variable overrides

# Environment-specific tags
tags = {
  Project     = "CourierX"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Purpose     = "Mail Server"
  Backup      = "Required"
}

# Instance configuration for production
# Using t2.micro to stay within Free Tier
instance_type = "t2.micro"

# Production domain (same as staging for now, but allows for separation)
# domain_name = "yourdomain.com"

# Note: Secrets (passwords, keys) should never be in .tfvars files
# They are passed via GitHub secrets and -var command line arguments

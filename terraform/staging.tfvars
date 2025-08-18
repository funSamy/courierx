# Staging Environment Configuration
# This file contains staging-specific variable overrides

# Environment-specific tags
tags = {
  Project     = "CourierX"
  Environment = "Staging"
  ManagedBy   = "Terraform"
  Purpose     = "Mail Server"
}

# Instance configuration for staging
# Using t3.small for cost efficiency in staging
instance_type = "t3.small"

# Optional: You could use a staging subdomain if desired
# domain_name = "staging.yourdomain.com"

# Note: Secrets (passwords, keys) should never be in .tfvars files
# They are passed via GitHub secrets and -var command line arguments

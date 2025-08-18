# ─────────────────────────────
# AWS Configuration
# ─────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy Courier X"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile name"
  type        = string
  default     = null
}

# ─────────────────────────────
# EC2 Instance Configuration
# ─────────────────────────────

variable "instance_type" {
  description = "EC2 instance type (use t2.micro for Free Tier)"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "SSH public key to install on the EC2 instance for administrative access"
  type        = string
}

# ─────────────────────────────
# Domain Configuration
# ─────────────────────────────

variable "domain_name" {
  description = "Primary domain name for Courier X (DNS will be configured manually)"
  type        = string
}

# ─────────────────────────────
# Mail User Configuration
# ─────────────────────────────

variable "noreply_pass" {
  description = "SMTP auth password for noreply@DOMAIN"
  type        = string
  sensitive   = true
}

variable "support_pass" {
  description = "SMTP auth password for support@DOMAIN"
  type        = string
  sensitive   = true
}

variable "forward_to" {
  description = "External email address to forward support mail to"
  type        = string
}

# ─────────────────────────────
# Tags
# ─────────────────────────────

variable "tags" {
  description = "Map of tags to apply to AWS resources"
  type        = map(string)
  default = {
    Project = "CourierX"
  }
}
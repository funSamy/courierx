# terraform/backend.tf
# Remote backend configuration for Terraform state
# 
# Before using this backend, ensure you have created:
# 1. S3 bucket: aws s3api create-bucket --bucket your-terraform-state-bucket-name --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1
# 2. DynamoDB table: aws dynamodb create-table --table-name terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 --region eu-central-1

terraform {
  backend "s3" {
    bucket         = "courierx-terraform-state-bucket" # Change this to your unique bucket name
    key            = "courierx/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

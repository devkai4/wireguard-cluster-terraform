#!/bin/bash
# scripts/setup-backend.sh

set -e

# Get the S3 bucket name from the backend outputs
BUCKET_NAME=$(cd terraform/backend && terraform output -raw s3_bucket_name)
DYNAMODB_TABLE=$(cd terraform/backend && terraform output -raw dynamodb_table_name)
REGION=$(cd terraform/backend && terraform output -raw s3_bucket_region)

# Create backend.tf files for each environment
for env in dev staging prod; do
  cat > terraform/environments/$env/backend.tf << EOFF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "${env}/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${DYNAMODB_TABLE}"
    encrypt        = true
    profile        = "vpn-project"
  }
}
EOFF
done

echo "Backend configuration files created successfully!"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "Region: $REGION"

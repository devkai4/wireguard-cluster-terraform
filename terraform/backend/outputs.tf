output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
  description = "The name of the S3 bucket for Terrfaorm state"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_state_lock.name
  description = "The name of the DynamoDB table for state locking"
}

output "s3_bucket_region" {
  value = aws_s3_bucket.terraform_state.region
  description = "The AWS region of the S3 bucket"
}
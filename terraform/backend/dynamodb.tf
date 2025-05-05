resource "aws_dynamodb_table" "terraform_state_lock" {
  name =  "vpn-cluster-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock"
    Environment = "Global"
    Project     = "VPN-Cluster"
  }
}
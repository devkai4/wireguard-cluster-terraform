terraform {
  backend "s3" {
    bucket         = "vpn-cluster-tfstate-afg1g47o"
    key            = "staging/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "vpn-cluster-tfstate-lock"
    encrypt        = true
    profile        = "vpn-project"
  }
}

terraform {
  backend "s3" {
    bucket         = "birdz-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "birdz-terraform-locks"
    encrypt        = true
  }
}

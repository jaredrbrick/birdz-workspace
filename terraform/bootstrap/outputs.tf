output "state_bucket" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "S3 bucket name for Terraform remote state"
}

output "lock_table" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table name for Terraform state locking"
}

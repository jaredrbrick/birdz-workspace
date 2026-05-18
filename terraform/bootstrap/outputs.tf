output "state_bucket" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "S3 bucket name for Terraform remote state"
}

output "lock_table" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table name for Terraform state locking"
}

output "terraform_role_arn" {
  value       = aws_iam_role.terraform.arn
  description = "Store as TF_ROLE_ARN repository secret in GitHub — used by terraform.yml workflow"
}

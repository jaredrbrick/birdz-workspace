output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.site.id
  description = "Used for cache invalidation in CI/CD (aws cloudfront create-invalidation)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.site.domain_name
  description = "*.cloudfront.net domain — CNAME target (record managed in Terraform via cloudflare_dns_record.site)"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.site.bucket
  description = "S3 bucket for aws s3 sync in CI/CD"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_deploy.arn
  description = "Store as AWS_ROLE_ARN_ENV secret in GitHub → used by deploy.yml for OIDC auth"
}

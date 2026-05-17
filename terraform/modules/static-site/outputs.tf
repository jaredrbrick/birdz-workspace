output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.site.id
  description = "Used for cache invalidation in CI/CD (aws cloudfront create-invalidation)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.site.domain_name
  description = "*.cloudfront.net domain — add as CNAME target in Cloudflare (DNS only / gray cloud)"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.site.bucket
  description = "S3 bucket for aws s3 sync in CI/CD"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_deploy.arn
  description = "Store as AWS_ROLE_ARN_ENV secret in GitHub → used by deploy.yml for OIDC auth"
}

output "certificate_validation_records" {
  value = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
  description = "CNAME records to add in Cloudflare to validate the ACM certificate"
}

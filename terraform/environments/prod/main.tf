terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "static_site" {
  source = "../../modules/static-site"

  environment = "prod"
  domain      = "birdz.3569081.xyz"
  bucket_name      = "birdz-prod-site"
  github_sub_claim = "repo:jaredrbrick/birdz-workspace:environment:prod"

  tags = {
    Project     = "birdz"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

output "cloudfront_distribution_id" {
  value = module.static_site.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  value = module.static_site.cloudfront_domain_name
}

output "s3_bucket_name" {
  value = module.static_site.s3_bucket_name
}

output "certificate_validation_records" {
  value = module.static_site.certificate_validation_records
}

output "github_actions_role_arn" {
  value = module.static_site.github_actions_role_arn
}

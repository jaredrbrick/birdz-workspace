terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "github" {
  owner = "jaredrbrick"
}

module "static_site" {
  source = "../../modules/static-site"

  environment      = "prod"
  domain           = "birdz.3569081.xyz"
  bucket_name      = "birdz-prod-site"
  github_sub_claim = "repo:jaredrbrick/birdz-workspace:environment:prod"

  tags = {
    Project     = "birdz"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

module "cognito" {
  source      = "../../modules/cognito"
  environment = "prod"
  tags = {
    Project     = "birdz"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

resource "github_actions_environment_secret" "aws_role_arn" {
  repository      = "birdz-workspace"
  environment     = "prod"
  secret_name     = "AWS_ROLE_ARN"
  plaintext_value = module.static_site.github_actions_role_arn
}

resource "github_actions_environment_secret" "cf_distribution_id" {
  repository      = "birdz-workspace"
  environment     = "prod"
  secret_name     = "CF_DISTRIBUTION_ID"
  plaintext_value = module.static_site.cloudfront_distribution_id
}

resource "github_actions_environment_secret" "cognito_user_pool_id" {
  repository      = "birdz-workspace"
  environment     = "prod"
  secret_name     = "COGNITO_USER_POOL_ID"
  plaintext_value = module.cognito.user_pool_id
}

resource "github_actions_environment_secret" "cognito_client_id" {
  repository      = "birdz-workspace"
  environment     = "prod"
  secret_name     = "COGNITO_CLIENT_ID"
  plaintext_value = module.cognito.client_id
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

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

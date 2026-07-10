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

# github provider removed: deploy config now flows through SSM Parameter
# Store (module.deploy_config); AWS_ROLE_ARN remains a manually-managed
# GitHub environment secret since the role name — and therefore its ARN —
# is static

module "static_site" {
  source = "../../modules/static-site"

  environment = "dev"
  domain      = "dev.birdz.3569081.xyz"
  bucket_name      = "birdz-dev-site"
  github_sub_claim = "repo:jaredrbrick/birdz-workspace:environment:dev"

  tags = {
    Project     = "birdz"
    Environment = "dev"
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

module "cognito" {
  source      = "../../modules/cognito"
  environment = "dev"
  tags = {
    Project     = "birdz"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

module "deploy_config" {
  source      = "../../modules/deploy-config"
  environment = "dev"
  values = {
    cf-distribution-id   = module.static_site.cloudfront_distribution_id
    cognito-user-pool-id = module.cognito.user_pool_id
    cognito-client-id    = module.cognito.client_id
  }
  tags = {
    Project     = "birdz"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Forget (do not destroy) the GitHub secrets Terraform used to manage —
# destroying them would require the expired PAT, and AWS_ROLE_ARN is
# still read by deploy.yml as the OIDC bootstrap
removed {
  from = github_actions_environment_secret.aws_role_arn
  lifecycle { destroy = false }
}

removed {
  from = github_actions_environment_secret.cf_distribution_id
  lifecycle { destroy = false }
}

removed {
  from = github_actions_environment_secret.cognito_user_pool_id
  lifecycle { destroy = false }
}

removed {
  from = github_actions_environment_secret.cognito_client_id
  lifecycle { destroy = false }
}

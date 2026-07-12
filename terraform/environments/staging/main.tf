terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Auth via CLOUDFLARE_API_TOKEN env var (GitHub secret, scoped to the
# birdzgame.com zone), exported in terraform.yml
provider "cloudflare" {}

data "cloudflare_zone" "birdzgame" {
  filter = {
    name = "birdzgame.com"
  }
}

# github provider removed: deploy config now flows through SSM Parameter
# Store (module.deploy_config); AWS_ROLE_ARN remains a manually-managed
# GitHub environment secret since the role name — and therefore its ARN —
# is static

module "static_site" {
  source = "../../modules/static-site"

  environment        = "staging"
  domain             = "staging.birdzgame.com"
  bucket_name        = "birdz-staging-site"
  cloudflare_zone_id = data.cloudflare_zone.birdzgame.zone_id
  github_sub_claim   = "repo:jaredrbrick/birdz-workspace:environment:staging"

  tags = {
    Project     = "birdz"
    Environment = "staging"
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

output "github_actions_role_arn" {
  value = module.static_site.github_actions_role_arn
}

module "cognito" {
  source      = "../../modules/cognito"
  environment = "staging"
  tags = {
    Project     = "birdz"
    Environment = "staging"
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
  environment = "staging"
  values = {
    cf-distribution-id   = module.static_site.cloudfront_distribution_id
    cognito-user-pool-id = module.cognito.user_pool_id
    cognito-client-id    = module.cognito.client_id
    identity-pool-id     = module.cognito.identity_pool_id
    game-data-table      = module.game_data.table_name
    pvp-api-url          = module.pvp_api.api_url
  }
  tags = {
    Project     = "birdz"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

module "game_data" {
  source      = "../../modules/game-data"
  environment = "staging"

  identity_pool_authenticated_role_name = module.cognito.authenticated_role_name

  tags = {
    Project     = "birdz"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

module "pvp_api" {
  source      = "../../modules/pvp-api"
  environment = "staging"

  game_data_table_name = module.game_data.table_name
  game_data_table_arn  = module.game_data.table_arn
  user_pool_id         = module.cognito.user_pool_id
  user_pool_client_id  = module.cognito.client_id
  allowed_origin       = "https://staging.birdzgame.com"

  tags = {
    Project     = "birdz"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

output "pvp_api_url" {
  value = module.pvp_api.api_url
}

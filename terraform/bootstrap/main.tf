# Run this once before initializing any environment.
# Uses local state by design — this is what creates the remote backend.
# If the local state file is lost, resources can be recovered with:
#   terraform import aws_s3_bucket.terraform_state birdz-terraform-state
#   terraform import aws_dynamodb_table.terraform_locks birdz-terraform-locks

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

resource "aws_s3_bucket" "terraform_state" {
  bucket = "birdz-terraform-state"

  tags = {
    Project   = "birdz"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "birdz-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project   = "birdz"
    ManagedBy = "terraform"
  }
}

# Broad-privilege role used by the terraform.yml workflow to apply infrastructure changes.
# Scoped to specific branches via OIDC — no long-lived credentials stored anywhere.
data "aws_iam_policy_document" "terraform_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:jaredrbrick/birdz-workspace:ref:refs/heads/main",
        "repo:jaredrbrick/birdz-workspace:ref:refs/heads/test",
        "repo:jaredrbrick/birdz-workspace:ref:refs/heads/staging",
        "repo:jaredrbrick/birdz-workspace:ref:refs/heads/prod",
      ]
    }
  }
}

resource "aws_iam_role" "terraform" {
  name               = "birdz-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.terraform_trust.json

  tags = {
    Project   = "birdz"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# GitHub Actions OIDC provider — created once per AWS account, shared by all environments.
# Allows GitHub Actions to assume IAM roles without storing long-lived credentials.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = {
    Project   = "birdz"
    ManagedBy = "terraform"
  }
}

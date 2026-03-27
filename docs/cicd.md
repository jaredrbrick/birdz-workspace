# CI/CD Architecture

## Overview

Birdz uses Terraform for infrastructure-as-code and GitHub Actions for the deployment pipeline. The React app is built with Vite and served as static files via S3 + CloudFront.

## Hosting

| Layer | Service | Purpose |
|-------|---------|---------|
| Static files | AWS S3 | Stores built app assets per environment |
| CDN + TLS | AWS CloudFront | Edge caching, HTTPS, custom domain |
| Audio files | AWS S3 (same bucket or separate) | Bird call audio served via same CloudFront distribution |

CloudFront sits in front of S3 so end users hit the nearest edge location rather than the origin bucket directly. TLS certificates are provisioned via ACM (free, auto-renewing).

## Environments

Four environments, each with its own S3 bucket and CloudFront distribution:

| Environment | Purpose |
|-------------|---------|
| `dev` | Deployed automatically on every merge to `main` |
| `test` | Promoted automatically when `dev` deploy + tests pass |
| `staging` | Promoted automatically when `test` deploy + tests pass |
| `prod` | Promoted after manual approval in GitHub Actions |

## Terraform

### State Backend

Remote state is stored in S3 with DynamoDB for state locking. This prevents concurrent `terraform apply` runs from corrupting the state file.

```
s3://birdz-terraform-state/         # state files per environment
dynamodb: birdz-terraform-locks     # lock table, one record per apply
```

All infrastructure is in `us-east-1`.

### Module Structure (planned)

```
terraform/
  backend.tf          # S3 + DynamoDB backend config
  environments/
    dev/
    test/
    staging/
    prod/
  modules/
    static-site/      # S3 bucket + CloudFront distribution
```

Each environment directory calls the `static-site` module with its own variables (bucket name, domain, etc.).

## GitHub Actions Pipeline

### Triggers

| Event | Action |
|-------|--------|
| Pull request opened/updated | Run tests only |
| Merge to `main` | Build + deploy to `dev`, then promote through environments |

### Pipeline Stages

```
merge to main
  └─ build
  └─ test
  └─ deploy → dev
        └─ integration tests pass?
              └─ deploy → test
                    └─ integration tests pass?
                          └─ deploy → staging
                                └─ manual approval
                                      └─ deploy → prod
```

### Zero Downtime Production Deploys

For a static S3+CloudFront app, zero downtime is achieved by:

1. Sync new build artifacts to the S3 bucket (`aws s3 sync`)
2. Invalidate the CloudFront cache (`aws cloudfront create-invalidation`)

The old version continues to be served from CloudFront edge caches until the invalidation completes and new files are fetched from S3. There is no period where the origin is unavailable.

### Workflow Files (planned)

```
.github/
  workflows/
    ci.yml          # PR checks: install, lint, test
    deploy.yml      # Post-merge: build, deploy, promote pipeline
```

## DNS

DNS is managed through **Cloudflare** (free tier). Each CloudFront distribution gets a CNAME record in Cloudflare pointing to its `*.cloudfront.net` domain.

**Important:** Cloudflare proxy must be set to **DNS only** (gray cloud) for these records. Enabling the Cloudflare proxy (orange cloud) would create a double-CDN situation and cause TLS conflicts between Cloudflare and ACM.

Route 53 was considered but not chosen — Cloudflare's free DNS vs Route 53's $0.50/month/zone isn't worth the cost for convenience.

### Domain

`birdz.3569081.xyz` — each environment gets a subdomain:

| Environment | Domain |
|-------------|--------|
| `dev` | `dev.birdz.3569081.xyz` |
| `test` | `test.birdz.3569081.xyz` |
| `staging` | `staging.birdz.3569081.xyz` |
| `prod` | `birdz.3569081.xyz` |

Cloudflare DNS records are managed manually (not via Terraform) since the Cloudflare provider would require an API token as an additional secret.

## AWS Region

All infrastructure: `us-east-1`. CloudFront is a global service and handles geographic distribution regardless of origin region.

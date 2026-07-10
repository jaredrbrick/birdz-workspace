variable "environment" {
  type        = string
  description = "Environment name (dev, test, staging, prod)"
}

variable "domain" {
  type        = string
  description = "Full domain name for this environment (e.g., dev.birdz.3569081.xyz)"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name for site assets"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone that hosts DNS for var.domain (site CNAME + ACM validation records)"
}

variable "github_sub_claim" {
  type        = string
  description = "GitHub Actions OIDC sub claim allowed to assume the deploy role (e.g., repo:owner/repo:ref:refs/heads/main)"
}

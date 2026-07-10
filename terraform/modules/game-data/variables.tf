variable "environment" {
  type = string
}

variable "identity_pool_authenticated_role_name" {
  description = "Name of the Cognito Identity Pool authenticated role to grant row-scoped table access. Leave null to skip the grant (e.g. before the identity pool exists)."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "environment" {
  type        = string
  description = "Environment name (dev, test, staging, prod)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources"
}

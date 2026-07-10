variable "environment" {
  type = string
}

variable "values" {
  description = "Deploy-time config values, written to SSM under /birdz/<environment>/deploy/<key>"
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_ssm_parameter" "this" {
  for_each = var.values

  name  = "/birdz/${var.environment}/deploy/${each.key}"
  type  = "String"
  value = each.value
  tags  = var.tags
}

output "parameter_names" {
  value = { for k, p in aws_ssm_parameter.this : k => p.name }
}

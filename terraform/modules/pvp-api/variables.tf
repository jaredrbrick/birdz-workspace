variable "environment" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "game_data_table_name" {
  type = string
}

variable "game_data_table_arn" {
  type = string
}

variable "user_pool_id" {
  type        = string
  description = "Cognito user pool id — the JWT authorizer's issuer"
}

variable "user_pool_client_id" {
  type        = string
  description = "Cognito app client id — the JWT authorizer's audience"
}

variable "allowed_origin" {
  type        = string
  description = "Site origin allowed to call the API (CORS)"
}

variable "tags" {
  type    = map(string)
  default = {}
}

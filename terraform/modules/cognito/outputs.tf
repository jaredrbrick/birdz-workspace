output "user_pool_id" {
  value       = aws_cognito_user_pool.main.id
  description = "Store as COGNITO_USER_POOL_ID GitHub environment secret"
}

output "client_id" {
  value       = aws_cognito_user_pool_client.web.id
  description = "Store as COGNITO_CLIENT_ID GitHub environment secret"
}

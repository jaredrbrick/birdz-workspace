output "api_url" {
  description = "Base invoke URL for the PvP HTTP API"
  value       = aws_apigatewayv2_api.pvp.api_endpoint
}

output "lambda_function_name" {
  value = aws_lambda_function.pvp.function_name
}

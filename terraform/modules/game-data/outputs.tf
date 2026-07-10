output "table_name" {
  value = aws_dynamodb_table.game_data.name
}

output "table_arn" {
  value = aws_dynamodb_table.game_data.arn
}

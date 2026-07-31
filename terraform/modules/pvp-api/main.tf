# PvP challenge API (docs/pvp-design.md): API Gateway HTTP API → one Lambda →
# the existing game-data table. JWT-authorized by the existing user pool. All
# serverless / scale-to-zero — no cost at rest.

# ── Lambda ────────────────────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/pvp-lambda-${var.environment}.zip"
}

resource "aws_iam_role" "lambda" {
  name = "birdz-${var.environment}-pvp-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# CloudWatch Logs + scoped access to the game-data table only.
data "aws_iam_policy_document" "lambda" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query",
    ]
    resources = [var.game_data_table_arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "birdz-${var.environment}-pvp-lambda"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_lambda_function" "pvp" {
  function_name    = "birdz-${var.environment}-pvp"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  architectures    = ["arm64"]
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      GAME_DATA_TABLE = var.game_data_table_name
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.pvp.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

# ── HTTP API ──────────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "pvp" {
  name          = "birdz-${var.environment}-pvp"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [var.allowed_origin]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 3600
  }

  tags = var.tags
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.pvp.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt"

  jwt_configuration {
    audience = [var.user_pool_client_id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${var.user_pool_id}"
  }
}

resource "aws_apigatewayv2_integration" "pvp" {
  api_id                 = aws_apigatewayv2_api.pvp.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.pvp.invoke_arn
  payload_format_version = "2.0"
}

locals {
  routes = [
    "POST /challenges",
    "GET /challenges/{id}",
    "POST /challenges/{id}/results",
    "GET /my-challenges",
  ]
}

resource "aws_apigatewayv2_route" "authed" {
  for_each = toset(local.routes)

  api_id             = aws_apigatewayv2_api.pvp.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.pvp.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.pvp.id
  name        = "$default"
  auto_deploy = true
  tags        = var.tags
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pvp.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pvp.execution_arn}/*/*"
}

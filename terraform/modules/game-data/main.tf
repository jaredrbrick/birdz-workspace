# Server-side persistence for game progress and user data.
#
# Single-table design: one DynamoDB table per environment, partitioned by
# user, with the sort key namespacing record types. See
# docs/persistence-design.md for the access-path recommendation
# (Cognito Identity Pool + fine-grained IAM) and the alternative considered.

resource "aws_dynamodb_table" "game_data" {
  name         = "birdz-${var.environment}-game-data"
  billing_mode = "PAY_PER_REQUEST" # no capacity planning; free tier friendly

  hash_key  = "userId"
  range_key = "recordKey"

  attribute {
    name = "userId"
    type = "S"
  }

  # recordKey namespaces record types under one user partition, e.g.
  #   PROGRESS            — current game progress (single item)
  #   SIGHTING#<birdId>   — one item per identified bird
  #   SETTINGS            — user preferences
  attribute {
    name = "recordKey"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

# Row-scoped access for the browser client: the Cognito Identity Pool's
# authenticated role may only touch items whose partition key equals the
# caller's identity ID. Applied only when the identity pool role exists.
data "aws_iam_policy_document" "row_scoped_access" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [aws_dynamodb_table.game_data.arn]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["$${cognito-identity.amazonaws.com:sub}"]
    }
  }
}

resource "aws_iam_role_policy" "row_scoped_access" {
  count = var.identity_pool_authenticated_role_name == null ? 0 : 1

  name   = "game-data-row-scoped"
  role   = var.identity_pool_authenticated_role_name
  policy = data.aws_iam_policy_document.row_scoped_access.json
}

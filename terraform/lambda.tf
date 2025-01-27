provider "aws" {
  region = "us-east-1"
}

variable "user_pool_id" {
  description = "The ID of the Cognito User Pool"
  type        = string
}

variable "client_id" {
  description = "The ID of the Cognito User Pool Client"
  type        = string
}

variable "client_secret" {
  description = "The secret of the Cognito User Pool "
  type        = string
}

data "aws_iam_role" "existing_lambda_role" {
  name = "lambda_role"
}

resource "aws_iam_role" "lambda_role" {
  count = length(data.aws_iam_role.existing_lambda_role.name) == 0 ? 1 : 0

  name = "lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "cognito_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "cognito_lambda"
  role          = length(data.aws_iam_role.existing_lambda_role.name) == 0 ? aws_iam_role.lambda_role[0].arn : data.aws_iam_role.existing_lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      USER_POOL_ID = "${var.user_pool_id}"
      CLIENT_ID    = "${var.client_id}"
      CLIENT_SECRET = "${var.client_secret}" 
    }
  }

}

resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "api_gateway"
  description = "API Gateway for Lambda function"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "api_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "my-resource"
}

resource "aws_api_gateway_method" "api_gateway_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_gateway_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_gateway_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_gateway_resource.id
  http_method             = aws_api_gateway_method.api_gateway_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.cognito_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  depends_on = [aws_api_gateway_integration.api_gateway_integration]
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "prod"
}
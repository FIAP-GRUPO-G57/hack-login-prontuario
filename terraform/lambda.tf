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

variable "lambda_role_name" {
  description = "The name of the IAM role for the Lambda function"
  type        = string
  default     = "lambda_role_${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "aws_iam_role" "lambda_role" {
  name = var.lambda_role_name
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
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      USER_POOL_ID = "${var.user_pool_id}"
      CLIENT_ID    = "${var.client_id}"
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
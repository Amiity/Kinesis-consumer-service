# IAM Role Creation

resource "aws_iam_role" "iam_for_lambda" {
  name               = "${var.appname}-consumer-role"
  assume_role_policy = jsonencode(
    yamldecode(file("${path.module}/lambda-assume-role-policy.yml")))
}

resource "aws_iam_role_policy_attachment" "kinesis_managed_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole"
  role       = aws_iam_role.iam_for_lambda.name
}

# Use an Existing Kinesis Data Stream

data "aws_kinesis_stream" "existing_kinesis_stream" {
  name = var.stream_name
}

# Create AWS Lambda

resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.appname}-consumer-${var.environment}"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "consumer-lambda-function.handler"
  runtime       = "python3.8"
  description   = "lambda function to consume binary logs from kinesis"
  filename      = "./../lambda-code/consumer-lambda-function.py"

  environment {
    variables = {
      DATA_STREAM_NAME = data.aws_kinesis_stream.existing_kinesis_stream.arn
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "event_invoke_config" {
  function_name                = aws_lambda_function.lambda_function.function_name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 0
}

# Create Lambda Event Source Mapping

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn  = data.aws_kinesis_stream.existing_kinesis_stream.arn
  function_name     = aws_lambda_function.lambda_function.arn
  starting_position = "LATEST"
}

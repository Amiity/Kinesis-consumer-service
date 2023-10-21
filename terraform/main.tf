provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

module "cdc-consumer" {
  source      = "./modules/lambda-function"
  product     = "test"
  stream_name = "test-cdc-${var.environment}-stream"
  environment = var.environment
  appname     = "cdc"
}
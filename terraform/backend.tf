apply.yml 

name: 'Plan and Apply Infrastructure'

on:
  push:
    branches:
    - main
    paths:
    - 'terraform/**'
  workflow_dispatch:

jobs:
  qa3:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-qa3'
      backendAWSKey: 'qa3.terraform.tfstate'
      environment: qa3
      runApply: true
    secrets: inherit

  qa2:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-qa2'
      backendAWSKey: 'qa2.terraform.tfstate'
      environment: qa2
      runApply: true
    secrets: inherit

  uat:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-uat'
      backendAWSKey: 'uat.terraform.tfstate'
      environment: uat
      runApply: true
    secrets: inherit

  prod:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-prod'
      backendAWSKey: 'prod.terraform.tfstate'
      environment: prod
      runApply: true
    secrets: inherit


***pr.yml


name: 'Plan Infrastructure'

on:
  push:
    paths:
    - 'terraform/**'
  workflow_dispatch:

jobs:
  qa3:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-qa3'
      backendAWSKey: 'qa3.terraform.tfstate'
      environment: qa3
    secrets: inherit

  qa2:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-qa2'
      backendAWSKey: 'qa2.terraform.tfstate'
      environment: qa2
    secrets: inherit

  uat:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-uat'
      backendAWSKey: 'uat.terraform.tfstate'
      environment: uat
    secrets: inherit

  prod:
    uses: ./.github/workflows/terraform-template.yml
    with:
      backendAWSBucketName: 'terraform-state-consumer-prod'
      backendAWSKey: 'prod.terraform.tfstate'
      environment: prod
    secrets: inherit


*****terraform- template.yml



name: 'Infrastructure Template'

on:
  workflow_call:
    inputs:
      workingDirectory:
        required: false
        type: 
        default: terraform
      backendAWSBucketName:
        required: true
        type: 
      backendAWSKey:
        required: true
        type: 
      environment:
        required: true
        type: 
      terraformVersion:
        required: false
        type: 
        default: "1.5.4"
      awsRegion:
        required: false
        type: 
        default: "us-east-1"
      runApply:
        required: false
        type: boolean
        default: false


jobs:
  plan:
    name: Plan ${{ inputs.environment }}
    runs-on: ["self-hosted", "amit-runner"]
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: configureawscredentials
        uses: aws-actions/configure-aws-credentials@v3
        with:
          role-to-assume: ${{ vars.demo_AWS_PROD_ROLE }}
          role-session-name: cdc-consumer-plan
          aws-region: us-east-1
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ inputs.terraformVersion }}
      - name: Terraform Init
        run: |
          terraform init -backend-config="bucket=${{inputs.backendAWSBucketName}}" -backend-config="key=${{inputs.backendAWSKey}}"
        working-directory: ${{inputs.workingDirectory}}
      - name: Terraform Plan
        id: plan
        run: |
          env=$(echo "${{ inputs.environment }}" | tr '[:upper:]' '[:lower:]')
          terraform plan -var-file="./environments/$env.tfvars" -out=now.tfplan
        working-directory: ${{inputs.workingDirectory}}
      - name: Configure Artifactory Credentials
        uses: amit-actions/setup-jfrog-cli@v2.3.0
        env:
          JF_ENV_1: ${{ secrets.demo_ARTIFACTORY_TOKEN }}
      - name: Store Plan
        shell: bash
        run: |
          build="$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
          env=$(echo "${{ inputs.environment }}" | tr '[:upper:]' '[:lower:]')
          artifactoryModule="test-$env-c"

          jf rt u --spec=".github/workflows/artifactoryUpload.json" --spec-vars="build=$build;artifactoryModule=$artifactoryModule" --fail-no-op=true

  apply:
    name: Apply ${{ inputs.environment }}
    needs: plan
    runs-on: [ "self-hosted", "amit-runner" ]
    environment: "${{ inputs.environment }}"
    if: ${{ inputs.runApply }}
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: Configure Artifactory Credentials
        uses: amit-actions/setup-jfrog-cli@v2.3.0
        env:
          JF_ENV_1: ${{ secrets.demo_ARTIFACTORY_TOKEN }}
      - name: Download Plan
        shell: bash
        run: |
          build="$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
          env=$(echo "${{ inputs.environment }}" | tr '[:upper:]' '[:lower:]')
          artifactoryModule="test-$env-c"
          target="${{ github.workspace }}/${{ inputs.workingDirectory }}"

          jf rt dl --spec="../.github/workflows/artifactoryDownload.json" --spec-vars="build=$build;artifactoryModule=$artifactoryModule;target=$target" --fail-no-op=true
        working-directory: ${{inputs.workingDirectory}}

      - name: configureawscredentials
        uses: aws-actions/configure-aws-credentials@v3
        with:
          role-to-assume: ${{ vars.demo_AWS_PROD_ROLE }}
          role-session-name: cdc-consumer-apply
          aws-region: us-east-1
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ inputs.terraformVersion }}
      - name: Terraform Init
        run: |
          terraform init -backend-config="bucket=${{inputs.backendAWSBucketName}}" -backend-config="key=${{inputs.backendAWSKey}}"
        working-directory: ${{inputs.workingDirectory}}
      - name: Terraform Apply
        if: ${{ inputs.runApply }}
        run: |
          terraform apply now.tfplan
        working-directory: ${{inputs.workingDirectory}}
      - name: List files in Working Directory
        run: ls
        working-directory: ${{inputs.workingDirectory}}
		
		
		
lambda-code-deploy.yml

name: 'Deploy Lambda Function Code'

on:
  push:
    branches:
    - main
    paths:
    - 'lambda-code/**'
  workflow_dispatch:

jobs:
  qa3:
    uses: ./.github/workflows/update-lambda-template.yml
    with:
      environment: qa3
      functionName: cdc-consumer-qa3
    secrets: inherit

  qa2:
    uses: ./.github/workflows/update-lambda-template.yml
    needs: qa3
    with:
      environment: qa2
      functionName: cdc-consumer-qa2
    secrets: inherit

  uat:
    uses: ./.github/workflows/update-lambda-template.yml
    needs: qa2
    with:
      environment: uat
      functionName: cdc-consumer-uat
    secrets: inherit

  prod:
    uses: ./.github/workflows/update-lambda-template.yml
    needs: uat
    with:
      environment: prod
      functionName: cdc-consumer-prod
    secrets: inherit
	
	
***lambda update template

name: 'Update Lambda functionCode Template'

on:
  workflow_call:
    inputs:
      workingDirectory:
        required: false
        type: 
        default: lambda-code
      environment:
        required: true
        type: 
      awsRegion:
        required: false
        type: 
        default: "us-east-1"
      functionName:
        required: true
        type: 

jobs:
  deploy:
    name: deploy ${{ inputs.environment }}
    runs-on: ["self-hosted", "amit-runner"]
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v2
      - name: Set up AWS CLI
        uses: aws-actions/configure-aws-credentials@v1
        with:
          role-to-assume: ${{ vars.demo_AWS_PROD_ROLE }}
          role-session-name: cdc-consumer-lambdacode
          aws-region: us-east-1
      - name: Zip Lambda Code
        run: |
          cd lambda-code
          zip -r lambda-code.zip consumer-lambda-function.py
        working-directory: ${{ github.workspace }}
      - name: Update Lambda Code
        run: |
          aws lambda update-function-code --function-name cdc-consumer-qa3 --zip-file fileb://lambda-code/lambda-code.zip --region us-east-1
		  
		  
***lambda assume role-session-name

Version: "2012-10-17"
Statement:
  - Action: sts:AssumeRole
    Effect: Allow
    Principal:
      Service: lambda.amazonaws.com


main.tfplan


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


variable.tfplan


variable "stream_name" {
  type = 
}

variable "product" {
  type = 
}

variable "environment" {
  type = 
}

variable "appname" {
  type = 
}



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

ackend.tfplan

terraform {
  backend "s3" {
    
  }
}

variable.tf

variable "aws_region" {
  default = "us-east-1"
  type    = 
}

variable "environment" {
  type = 
}


*****code



import base64


def handler(event, context):
    for record in event['Records']:
        kinesis_data = base64.b64decode(record['kinesis']['data'])
        print(f"Received log entry: {kinesis_data.decode('utf-8')}")

    return 'Logs processed successfully'




		  
		  
		  





	
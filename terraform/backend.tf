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




		  
		  
		  





	
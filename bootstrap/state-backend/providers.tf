terraform {
  required_version = ">= 1.10" #locking needs 1.10

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "af-south-1"
}

#no backend block here, because backend sends to S3, which is the thing we are creating (chicken and egg problem)
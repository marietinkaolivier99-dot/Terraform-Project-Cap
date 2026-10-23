terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
  backend "s3" {}
  # partial backend, supplied dynamically by the .tfbackend file
  # left blank on purpose so the backend can be different for each environment 
}

provider "aws" {
  region = "af-south-1"
}
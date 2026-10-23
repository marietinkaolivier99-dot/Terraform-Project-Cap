
#Change this variable so that the prefix follows the format <surname><first_initial>"
variable "prefix" {
  type        = string
  description = "distinguishing prefix for resource arguments which identifies the owner <surname><first_initial>"
  default     = "olivierm"
}

#TODO: Create another variable for the environment name.
variable "environment" {
  type        = string
  description = "Name of the environment"
}

#TODO: Create another variable for the versioning requirement
variable "enable_versioning" {
  type        = bool
  description = "Whether to enable versioning for the S3 bucket"
}

#TODO: Create a local called bucket_name which follows the format <prefix>-s3-<environment_name>
locals {
  bucket_name = "${var.prefix}-s3-${var.environment}"
}
#TODO: Use local.bucket_name in the bucket argument of the aws_s3_bucket resource.
resource "aws_s3_bucket" "my_bucket" {
  bucket        = local.bucket_name
  force_destroy = true
}



#TODO: Supply a value for the environment name variable via CLI flag -var="environment=<value>"
#clean up

#TODO: Create dev.tfvars, qa.tfvars, and prod.tfvars files with appropriate values for the environment variable.
#apply and cleanup for the different environments using the -var-file flag.
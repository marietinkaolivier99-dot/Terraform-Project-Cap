variable "prefix" {
  type = string
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Only dev, qa and prod allowed."
  }

}

locals {
  eks_cluster_name = "${var.prefix}-eks-${var.environment}"
  iam_role_name    = "${var.prefix}-eks-iam-role-${var.environment}"
}

variable "availability_zones" {
  default = ["af-south-1a", "af-south-1b", "af-south-1c"]
}

# variable "vpc_id" {
#   default = "vpc-0d0015b3beb893003"
# }
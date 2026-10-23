####################################################################
# One-time bootstrap: GitHub Actions OIDC trust into this AWS account
#
# Apply this manually, once, with your own AWS credentials:
#   cd bootstrap/github-oidc
#   terraform init
#   terraform apply -var="github_org=<your-org>" -var="github_repo=<your-repo>"
#
# This is deliberately NOT part of the main Project/ Terraform state and
# is never applied by CI: the workflow needs the role this creates to
# exist before it can authenticate to AWS at all.
####################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}

provider "aws" {
  region = "af-south-1"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-${var.github_repo}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}@346335941/${var.github_repo}@1429661768:ref:refs/heads/main",
              "repo:${var.github_org}@346335941/${var.github_repo}@1429661768:pull_request",
              "repo:${var.github_org}@346335941/${var.github_repo}@1429661768:environment:*",
            ]
          }
        }
      }
    ]
  })
}

# Scoped to what the capitec_eks / capitec_s3 modules actually provision,
# plus access to the three per-environment state buckets. Not AdministratorAccess.
resource "aws_iam_role_policy" "github_actions" {
  name = "terraform-apply"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "NetworkingAndCompute"
        Effect = "Allow"
        Action = [
          "ec2:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "EKS"
        Effect = "Allow"
        Action = [
          "eks:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMForClusterAndNodeRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole",
          "iam:CreateServiceLinkedRole",
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*eks*",
        ]
      },
      {
        Sid    = "StateBackend"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::olivier-m-s3-dev",
          "arn:aws:s3:::olivier-m-s3-dev/*",
          "arn:aws:s3:::olivier-m-s3-qa",
          "arn:aws:s3:::olivier-m-s3-qa/*",
          "arn:aws:s3:::olivier-m-s3-prod",
          "arn:aws:s3:::olivier-m-s3-prod/*",
        ]
      }
    ]
  })
}

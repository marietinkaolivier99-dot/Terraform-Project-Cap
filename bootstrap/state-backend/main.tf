
#reusable named value
locals {
  environments = toset(["dev", "qa", "prod"]) #turn list into a set >> for_each needs this
}


#Four resources
resource "aws_s3_bucket" "state" {
  for_each = local.environments
  bucket   = "olivier-m-s3-${each.key}"
}

resource "aws_s3_bucket_versioning" "state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.state[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = local.environments
  bucket   = aws_s3_bucket.state[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  for_each                = local.environments
  bucket                  = aws_s3_bucket.state[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

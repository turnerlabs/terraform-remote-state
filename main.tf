/**
 * A Terraform module that configures an s3 bucket for use with Terraform's remote state feature.
 *
 * Useful for creating a common bucket naming convention and attaching a bucket policy using the specified role.
 */

# the primary role that will be used to access the tf remote state
variable "role" {
}

# additional roles that should be granted access to the tfstate
variable "additional_roles" {
  type = list
  default = []
}

# the application that will be using this remote state
variable "application" {
}

# tags
variable "tags" {
  type = map(string)
}

//incomplete multipart upload deletion
variable "multipart_delete" {
  default = true
}

variable "multipart_days" {
  default = 3
}

# whether or not to set force_destroy on the bucket
variable "force_destroy" {
  default = true
}

# ensure bucket access is "Bucket and objects not public"
variable "block_public_access" {
  default = true
}

# if enabled, we will create a dynamodb table that can be used to store state file lock status
variable "dynamodb_state_locking" {
  default = false
}

# bucket for storing tf state
resource "aws_s3_bucket" "bucket" {
  bucket        = "tf-state-${var.application}"
  force_destroy = var.force_destroy

  tags = var.tags

  lifecycle { 
    ignore_changes = [ logging ]
  }
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration  {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration"  "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id                                     = "auto-delete-incomplete-after-x-days"
    status                                 = var.multipart_delete ? "Enabled" : "Disabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_days
    }

    expiration {
        expired_object_delete_marker = false
    }
  }
}

# explicitly block public access
resource "aws_s3_bucket_public_access_block" "bucket" {
  count = var.block_public_access ? 1 : 0

  depends_on = [aws_s3_bucket_policy.bucket_policy]

  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# dynamodb table used to storing lock state
resource "aws_dynamodb_table" "state_lock_table" {
  count = var.dynamodb_state_locking ? 1 : 0

  name           = "tf-state-lock-${var.application}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  tags           = var.tags

  attribute {
    name = "LockID"
    type = "S"
  }
}

# grant bucket owner full control of all objects; disable per-object ACLs
resource "aws_s3_bucket_ownership_controls" "bucket_owner" {
    bucket = aws_s3_bucket.bucket.id
    rule {
      object_ownership = "BucketOwnerPreferred"
    }
}

# lookup the role arn
data "aws_iam_role" "role" {
  name = var.role
}

data "aws_iam_role" "additional_roles" {
  for_each = toset(var.additional_roles)
  name = each.key
}

# grant the roles access to the bucket
resource "aws_s3_bucket_policy" "bucket_policy" {

  depends_on = [aws_s3_bucket.bucket]
  bucket = aws_s3_bucket.bucket.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal":{
        "AWS": [
               %{ for r in data.aws_iam_role.additional_roles }
                  "${r.arn}",
               %{ endfor }
               "${data.aws_iam_role.role.arn}"
               ]
      },
      "Action": [ "s3:*" ],
      "Resource": [
        "${aws_s3_bucket.bucket.arn}",
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    }
  ]
}
EOF

}

# the created bucket 
output "bucket" {
  value = aws_s3_bucket.bucket.bucket
}

# dynamodb table
output "dynamodb_lock_table" {
    value = var.dynamodb_state_locking ? aws_dynamodb_table.state_lock_table[0].name : null
}

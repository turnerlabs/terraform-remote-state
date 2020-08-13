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

# bucket for storing tf state
resource "aws_s3_bucket" "bucket" {
  bucket        = "tf-state-${var.application}"
  force_destroy = var.force_destroy

  versioning {
    enabled = true
  }

  tags = var.tags

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id                                     = "auto-delete-incomplete-after-x-days"
    prefix                                 = ""
    enabled                                = var.multipart_delete
    abort_incomplete_multipart_upload_days = var.multipart_days
  }
}

# explicitly block public access
resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# lookup the role arn
data "aws_iam_role" "role" {
  name = var.role
}

data "aws_iam_role" "additional_roles" {
  for_each = toset(var.additional_roles)
  name = each.key
}

# grant the role access to the bucket
resource "aws_s3_bucket_policy" "bucket_policy" {
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


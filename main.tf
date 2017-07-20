variable "region" {
  default = "us-east-1"
}

variable "role" {}
variable "application" {}

variable "tags" {
  type = "map"
}

provider "aws" {
  region = "${var.region}"
}

# bucket for storing tf state
resource "aws_s3_bucket" "bucket" {
  bucket        = "tf-state-${var.application}"
  force_destroy = "true"

  versioning {
    enabled = "true"
  }

  tags = "${var.tags}"
}

# lookup the role arn
data "aws_iam_role" "role" {
  role_name = "${var.role}"
}

# grant the role access to the bucket
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = "${aws_s3_bucket.bucket.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal":{
        "AWS": "${data.aws_iam_role.role.arn}"
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

output "bucket" {
  value = "${aws_s3_bucket.bucket.bucket}"
}

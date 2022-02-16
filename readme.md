### terraform-remote-state

A Terraform module that configures an s3 bucket for use with Terraform's remote state feature.

Useful for creating a common bucket naming convention and attaching a bucket policy using the specified role.


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| application | the application that will be using this remote state | string | - | yes |
| block\_public\_access | ensure bucket access is "Bucket and objects not public" | bool | `true` | no |
| multipart\_days |  | string | `3` | no |
| multipart\_delete | incomplete multipart upload deletion | string | `true` | no |
| role | the primary role that will be used to access the tf remote state | string | - | yes |
| additional\_roles | additional roles that will be granted access to the remote state | list of strings | \[] | no |
| tags | tags to apply the created S3 bucket | map | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| bucket | the created bucket |


#### usage example

setup the remote state bucket

```hcl
provider "aws" {
  profile = "my-profile"
  region  = "us-east-1"
}

module "tf_remote_state" {
  source = "github.com/turnerlabs/terraform-remote-state?ref=v5.0.0"

  role          = "aws-ent-prod-devops"
  application   = "my-test-app"

  tags = "${map("team", "my-team", "contact-email", "my-team@my-company.com", "application", "my-app", "environment", "dev", "customer", "my-customer")}"  
}

output "bucket" {
  value = "${module.tf_remote_state.bucket}"
}
```

```
$ tf init
$ tf apply

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:
bucket = tf-state-my-test-app
```

Now configure your script to use the remote state bucket.  Note that you need to be logged in to the specified role in order to apply your scripts.

```hcl
terraform {
  backend "s3" {
    region  = "us-east-1"
    bucket  = "tf-state-my-test-app"
    key     = "dev.terraform.tfstate"
  }
}
```

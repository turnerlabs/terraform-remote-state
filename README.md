### terraform-remote-state

A Terraform module that configures an s3 bucket for use with Terraform's remote state feature.

Useful for creating a common bucket naming convention and attaching a bucket policy using the specified role.

The way S3 buckets are described in Terraform changed significantly with
version 4.0.0 of the AWS provider, which corresponds to the `v5.0.0` tag of
this module.  Be sure to use a previous version of the module (the
immediately-prior one is v4.0.2) if you are using an older version of the AWS
provider. In general it's a good idea always to reference the module with an explicit
`?ref=_tag_` in the URL and commit the `.terraform.lock.hcl` file created by
`terraform init` alongside your source code.


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| application | the application that will be using this remote state | string | - | yes |
| block\_public\_access | ensure bucket access is "Bucket and objects not public" | bool | `true` | no |
| multipart\_days |  | string | `3` | no |
| multipart\_delete | incomplete multipart upload deletion | string | `true` | no |
| role | the primary role that will be used to access the tf remote state | string | - | yes |
| additional\_roles | additional roles that will be granted access to the remote state | list of strings | \[] | no |
| dynamodb\_state\_locking | if enabled, creates a dynamodb table to be used to store state lock status | bool | `false` | no |
| tags | tags to apply the created S3 bucket | map | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| bucket | the created bucket |
| dynamodb_lock_table | name of dynamodb lock table, if created |

#### usage example

setup the remote state bucket

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

module "tf_remote_state" {
  source = "github.com/turnerlabs/terraform-remote-state?ref=v5.1.0"

  role          = "aws-ent-prod-devops"
  application   = "my-test-app"

  tags = {
    team            = "my-team"
    "contact-email" = "my-team@my-company.com"
    application     = "my-app"
    environment     = "dev"
    customer        = "my-customer"
  }
}

output "bucket" {
  value = module.tf_remote_state.bucket
}
```

```
$ terraform init
$ terraform apply

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

##### dynamodb state locking

Terraform S3 backend allows you to define a dynamodb table that can be used to store state locking status. To create and use a table set dynamodb_state_locking to true.

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

module "tf_remote_state" {
  source = "github.com/turnerlabs/terraform-remote-state?ref=v5.1.0"

  role                   = "aws-ent-prod-devops"
  application            = "my-test-app"
  dynamodb_state_locking = "true"

  tags = {
    team            = "my-team"
    "contact-email" = "my-team@my-company.com"
    application     = "my-app"
    environment     = "dev"
    customer        = "my-customer"
  }
}

output "bucket" {
  value = module.tf_remote_state.bucket
}

output "bucket" {
  value = module.tf_remote_state.dynamodb_lock_table
}
```

```
$ terraform init
$ terraform apply

Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

bucket = "tf-state-my-test-app"
dynamodb_lock_table = "tf-state-lock-my-test-app"
```

Now configure your script to use the remote state bucket and lock table.  Note that you need to be logged in to the specified role in order to apply your scripts.

```hcl
terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "tf-state-my-test-app"
    key            = "dev.terraform.tfstate"
    dynamodb_table = "tf-state-lock-my-test-app"
  }
}
```

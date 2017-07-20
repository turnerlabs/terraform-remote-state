### terraform-remote-state

A Terraform module that configures an s3 bucket for use with Terraform's remote state feature.  

Useful for creating a common bucket naming convention and attaching a bucket policy using the specified role.

#### usage

setup the remote state bucket

```terraform
module "tf_remote_state" {
  source = "github.com/turnerlabs/terraform-remote-state?ref=v1.0.0"

  region        = "us-east-1"
  role          = "aws-ent-prod-devops"
  application   = "my-test-app"

  tags = "${map("team", "my-team", "contact-email", "my-team@my-company.com", "application", "my-app", "environment", "dev", "customer", "my-customer")}"  
}

output "bucket" {
  value = "${module.tf_remote_state.bucket}"
}
```

```
$ tf plan
$ tf apply

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:
bucket = tf-state-my-test-app
```

Now configure your script to use the remote state bucket.  Note that you need to be logged in to the specified role in order to apply your scripts.

```
terraform {
  backend "s3" {
    region  = "us-east-1"
    bucket  = "tf-state-my-test-app"
    key     = "dev.terraform.tfstate"
  }
}
```
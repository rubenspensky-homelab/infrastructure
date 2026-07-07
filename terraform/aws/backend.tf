terraform {
  backend "s3" {
    bucket       = "homelab-tf-state-rubenspensky"
    key          = "infra/aws/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}

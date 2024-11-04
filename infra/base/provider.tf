# Setup our aws provider

provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {
    region = var.region
    key = "base/terraform.tfstate"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    # can't use the caller identity data block because this is processed before any data sources
    bucket         = "from-k8s-to-aws-tfstate-645767464201"
    key            = "portfolio-ecs/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "from-k8s-to-aws-tf-lock"
    encrypt        = true
    profile        = "aws-learning"
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "aws-learning"
}
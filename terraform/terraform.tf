terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.53"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  profile = "terraform"
  region  = var.region
}
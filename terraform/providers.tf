terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.13.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
  }
  # backend "s3" {
  #   bucket         = "rev-terraform-state-backend"  # Replace with your S3 bucket name
  #   key            = "game-2048/terraform.tfstate" # Path and filename for the state file
  #   region         = "us-east-1"                   # AWS region of your S3 bucket
  #   use_lockfile   = true
  # }
}

provider "aws" {
  region = "us-east-1"
}

provider "tls" {
  # Configuration options
}

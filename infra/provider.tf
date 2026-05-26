# Configuración global de Terraform
terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket         = "express-app-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "express-app-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
  }
}

# Configuración del proveedor AWS
provider "aws" {
  region = var.region
}

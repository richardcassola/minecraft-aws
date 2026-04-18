terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "minecraft" {
  source = "./modules/minecraft"

  region          = var.region
  instance_type   = var.instance_type
  server_name     = var.server_name
  allowed_ssh_ips = var.allowed_ssh_ips
  alert_email     = var.alert_email
}

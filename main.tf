terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

  region            = var.region
  instance_type     = var.instance_type
  server_name       = var.server_name
  alert_email       = var.alert_email
  whitelist_players = var.whitelist_players
}

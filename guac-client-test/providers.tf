provider "aviatrix" {
  controller_ip = var.aviatrix_controller_ip
  username      = var.aviatrix_admin_account
  password      = var.aviatrix_admin_password
}

provider "aws" {
  version = "~> 2.0"
  region  = var.aws_region
}

provider "null" {}

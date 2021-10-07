#Regions
variable "region" {
  type        = string
  description = "AWS region to deploy the instances in"
  default     = "eu-central-1"
}

variable "hostname" {
  type        = string
  description = "Route53 domain to update"
  default     = "guactest"
}

variable "domain_name" {
  type        = string
  description = "Route53 domain to update"
  default     = "avxlab.de"
}

# Client Details
variable "ssh_key" {
  type        = string
  description = "SSH Public Key for the VM"
}

variable "username" {
  description = "Username for the client"
  type        = string
  default     = "testuser"
}

variable "client_password" {
  description = "Password for the client"
  type        = string
}
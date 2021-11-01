#Regions
variable "region" {
  type        = string
  description = "AWS region to deploy the instances in"
  default     = "us-east-1"
}

variable "vpc_id" {
  default = "vpc-03765f0c8469de54a"
}

variable "subnet_id" {
  default = "subnet-034f354a8d2496c83"
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
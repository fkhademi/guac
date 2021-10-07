data "aws_route53_zone" "domain_name" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "avx-guac-vpc" }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags   = { Name = "avx-guac-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id
  tags   = { Name = "avx-guac-rt" }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.0.0/26"
  tags       = { Name = "avx-guac-subnet" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a Guacamole client for each pod
module "aws_client" {
  source        = "git::https://github.com/fkhademi/terraform-aws-instance-module.git?ref=v1.3"
  name          = "guac-test"
  region        = var.region
  vpc_id        = aws_vpc.default.id
  subnet_id     = aws_subnet.public.id
  ssh_key       = var.ssh_key
  user_data     = data.template_file.cloudconfig.rendered
  public_ip     = true
  instance_size = "t3.small"
}

# User-Data for Guacamole
data "template_file" "cloudconfig" {
  template = file("${path.module}/cloud-init-client.tpl")
  vars = {
    username   = "testuser"
    password   = var.client_password
    hostname   = "guactest.${var.domain_name}"
    domainname = var.domain_name
  }
}

# Public DNS record for each Guacamole client
resource "aws_route53_record" "client" {
  zone_id = data.aws_route53_zone.domain_name.zone_id
  name    = "guactest.${data.aws_route53_zone.domain_name.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws_client.vm.public_ip]
}

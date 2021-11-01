data "aws_route53_zone" "domain_name" {
  name         = var.domain_name
  private_zone = false
}

# Create a Guacamole client for each pod
module "aws_client" {
  source        = "git::https://github.com/fkhademi/terraform-aws-instance-module.git?ref=v1.3"
  name          = "${var.hostname}vm"
  region        = var.region
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id
  ssh_key       = var.ssh_key
  user_data     = data.template_file.cloudconfig.rendered
  public_ip     = true
  instance_size = "t3.small"
}

# User-Data for Guacamole
data "template_file" "cloudconfig" {
  template = file("${path.module}/cloud-init-client.tpl")
  vars = {
    username   = var.username
    password   = var.client_password
    hostname   = "${var.hostname}.${var.domain_name}"
    domainname = var.domain_name
  }
}

# Public DNS record for each Guacamole client
resource "aws_route53_record" "client" {
  zone_id = data.aws_route53_zone.domain_name.zone_id
  name    = "${var.hostname}.${data.aws_route53_zone.domain_name.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws_client.vm.public_ip]
}

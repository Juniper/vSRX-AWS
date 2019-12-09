#provider "aws" {
#  region = "us-east-1"
#}
#provider "aws" {
#  alias = "eu-central-1"
#  region = "eu-central-1"
#}
#module "vpc_ireland" {
#  ...
#}
#module "vpc_frankfurt" {
#  providers {
#    aws = "aws.eu-central-1"
#  }
#  ...
#}

resource "aws_security_group" "allow_ssh_icmp_spoke1" {
  name        = "allow_ssh_icmp"
  description = "Allow SSH & ICMP inbound traffic"
  vpc_id      = "${module.spoke_vpc1.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["66.129.239.8/29"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ssh_icmp_spoke2" {
  name        = "allow_ssh_icmp"
  description = "Allow SSH & ICMP inbound traffic"
  vpc_id      = "${module.spoke_vpc2.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["66.129.239.8/29"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "akbhat_transit_vsrx"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW3fBHRMTQ3CUxWUnYD2XmjNjO8J6T038rYqjzUCNTYbWWCbH9sfdBu/GJpnh207hEB+PzRpKJnhsvPogb/wNNi0KzarWoUPKtqt0VQkpZg4fsIUcscyFiR3cb9pzKR4UOJzQo7ZTO0ulKqFeyrmDHM89bFMcC6ATz5lIvO5ZNukdtZ1+gnKqTLMoq8VcPYIllnOFNTiEpQyr+COmLMjNN7CVRqCmAo0vIw2mNZpA2hk/Nmstv7gxEGch2VNdJw6nOIaO9XXX+DcJagPoyJsjeuVb0yKi/DmEgPTZXhAsZ9Sgv8/pdj0vDf3O/G2LelohJ315q1p5h4pL2HGbVrnbf akbhat@ubuntu"
}

module "spoke_vpc1" {
  source = "terraform-aws-modules/vpc/aws"
  version         = "1.58.0"
  create_vpc      = true

  name = "akbhat-spoke-vpc1"
  cidr = "${var.spoke_vpc1_cidr}"
  azs             = ["${data.aws_availability_zones.available.names[0]}"]
#  private_subnets = ["10.150.1.0/24"]
  public_subnets  = ["${var.spoke_vpc1_subnet}"]

  enable_nat_gateway = true
#  enable_vpn_gateway = true

  tags = {
    Owner = "akbhat"
    Environment = "dev"
  }
}

module "spoke_vpc2" {
  source = "terraform-aws-modules/vpc/aws"
  version         = "1.58.0"
  create_vpc      = true

  name = "akbhat-spoke-vpc2"
  cidr = "${var.spoke_vpc2_cidr}"

  azs             = ["${data.aws_availability_zones.available.names[1]}"]
#  private_subnets = ["10.160.1.0/24"]
  public_subnets  = ["${var.spoke_vpc2_subnet}"]

  enable_nat_gateway = true
#  enable_vpn_gateway = true

  tags = {
    Owner = "akbhat"
    Environment = "dev"
  }
}

data "aws_ami" "ubuntu_server" {
  most_recent = true
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["*ubuntu-xenial-16.04-amd64-server-20181114*"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

module "ec2_cluster_spoke1" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "1.19.0"

  name                   = "vpc1-spoke"
  instance_count         = 1

  ami                    = "${data.aws_ami.ubuntu_server.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.deployer.key_name}"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.allow_ssh_icmp_spoke1.id}"]
  subnet_id              = "${element(module.spoke_vpc1.public_subnets, 0)}"
  associate_public_ip_address = true

  tags = {
    Owner = "akbhat"
    Environment = "dev"
  }
}

module "ec2_cluster_spoke2" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "1.19.0"

  name                   = "vpc2-spoke"
  instance_count         = 1

#  ami                    = "ami-0f9cf087c1f27d9b1"
  ami                    = "${data.aws_ami.ubuntu_server.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.deployer.key_name}"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.allow_ssh_icmp_spoke2.id}"]
  subnet_id              = "${element(module.spoke_vpc2.public_subnets, 0)}"
  associate_public_ip_address = true

  tags = {
    Owner = "akbhat"
    Environment = "dev"
  }
}

# Ingress Route Table attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke1" {
  subnet_ids         = ["${module.spoke_vpc1.public_subnets}"]
  transit_gateway_id = "${aws_ec2_transit_gateway.tvpc_tgw.id}"
  vpc_id             = "${module.spoke_vpc1.vpc_id}" 
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke2" {
  subnet_ids         = ["${module.spoke_vpc2.public_subnets}"]
  transit_gateway_id = "${aws_ec2_transit_gateway.tvpc_tgw.id}"
  vpc_id             = "${module.spoke_vpc2.vpc_id}"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke1" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.spoke1.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.ingress.id}"
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke2" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.spoke2.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.ingress.id}"
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke1_to_egress" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.spoke1.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.egress.id}"
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke2_to_egress" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.spoke2.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.egress.id}"
}

# Default routes pointing to TGW
resource "aws_route" "spoke_route_vpc1" {
  route_table_id          = "${element(module.spoke_vpc1.public_route_table_ids,0)}" 
  destination_cidr_block  = "${var.spoke_vpc2_cidr}"
  transit_gateway_id      = "${aws_ec2_transit_gateway.tvpc_tgw.id}"

  depends_on = ["aws_ec2_transit_gateway.tvpc_tgw"]
}

resource "aws_route" "spoke_route_vpc2" {
  route_table_id          = "${element(module.spoke_vpc2.public_route_table_ids,0)}"
  destination_cidr_block  = "${var.spoke_vpc1_cidr}" 
  transit_gateway_id      = "${aws_ec2_transit_gateway.tvpc_tgw.id}"

  depends_on = ["aws_ec2_transit_gateway.tvpc_tgw"]
}

# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

provider "aws" {
   
   access_key = var.access_key
   secret_key = var.secret_key
   region     = var.region
}

/************************************** App VPC resource ********************************/
resource "aws_vpc" "vpc_r" {
  cidr_block           = var.vpc_cidr_p
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-vpc"
  }
}

resource "aws_internet_gateway" "igw_r" {
  vpc_id = aws_vpc.vpc_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-vpc-igw"
  }
}
data "aws_ec2_transit_gateway" "tgw_id" {
  id = var.tgw_id_p
}

data "aws_ec2_transit_gateway_vpc_attachment" "tgw_security_attachment" {
  id = var.TgwSecurityAttachmentIdP
}


/*********************** AZ1 Configuration ************************/
resource "aws_subnet" "public_subnet_r" {
  availability_zone       = var.availability_zones_p
  vpc_id                  = aws_vpc.vpc_r.id
  cidr_block              = var.public_cidr_p
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet_r" {
  availability_zone       =var.availability_zones_p
  vpc_id                  = aws_vpc.vpc_r.id
  cidr_block              = var.private_cidr_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-private-subnet"
  }
}

resource "aws_subnet" "gwlbe_subnet_r" {
  availability_zone    =var.availability_zones_p
  vpc_id               = aws_vpc.vpc_r.id
  cidr_block           = var.gwlbe_cidr_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlbe-subnet"
  }
}

resource "aws_route_table" "public_route_table_r" {
  vpc_id       = aws_vpc.vpc_r.id
  route {
    cidr_block = "0.0.0.0/0"
     vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point_r.id
  }
  route {
    cidr_block       = "10.0.0.0/8"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  route {
    cidr_block       = "172.16.0.0/12"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  route {
    cidr_block       = "192.168.0.0/16"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-mgmt-route"
  }
}

resource "aws_route_table" "public_route_table_edge_r" {
  vpc_id           = aws_vpc.vpc_r.id
  route {
     cidr_block       = aws_subnet.public_subnet_r.cidr_block
     vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point_r.id
  }
}

resource "aws_route_table" "private_route_table_r" {
  vpc_id           = aws_vpc.vpc_r.id
  route {
    cidr_block     = "0.0.0.0/0"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-data-route"
  }
}

resource "aws_route_table" "gwlbe_route_table_r" {
  vpc_id               = aws_vpc.vpc_r.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_r.id
  }
  route {
    cidr_block       = "10.0.0.0/8"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  route {
    cidr_block       = "172.16.0.0/12"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
   route {
    cidr_block       = "192.168.0.0/16"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlbe-route"
  }
}

resource "aws_route_table_association" "public_subnet_route_association_r" {
  subnet_id      = aws_subnet.public_subnet_r.id
  route_table_id = aws_route_table.public_route_table_r.id
}

resource "aws_route_table_association" "public_subnet_route_association_edge_r" {
  gateway_id     = aws_internet_gateway.igw_r.id
  route_table_id = aws_route_table.public_route_table_edge_r.id
  depends_on =[aws_internet_gateway.igw_r]
}

resource "aws_route_table_association" "private_subnet_route_association_r" {
  subnet_id      = aws_subnet.private_subnet_r.id
  route_table_id = aws_route_table.private_route_table_r.id
} 

resource "aws_route_table_association" "gwlbe_subnet_route_association_r" {
  subnet_id      = aws_subnet.gwlbe_subnet_r.id
  route_table_id = aws_route_table.gwlbe_route_table_r.id
}

################################################################################
resource "aws_vpc_endpoint" "gwlbe_end_point_r" {
  service_name      = var.GwlbServiceNameP
  subnet_ids        = [aws_subnet.gwlbe_subnet_r.id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = aws_vpc.vpc_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlb-end-point"
  }
}

###############################################################################
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_vpc_attachment_r" {
  subnet_ids             = [aws_subnet.private_subnet_r.id]
  transit_gateway_id     = data.aws_ec2_transit_gateway.tgw_id.id  
  vpc_id                 = aws_vpc.vpc_r.id
  appliance_mode_support = "enable"
  transit_gateway_default_route_table_association=false
  transit_gateway_default_route_table_propagation=false
}

resource "aws_ec2_transit_gateway_route_table" "ec2_tgw_route_table_r" {
  transit_gateway_id = data.aws_ec2_transit_gateway.tgw_id.id
}

resource "aws_ec2_transit_gateway_route_table_association" "ec2_tgw_route_association_r" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_attachment_r.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ec2_tgw_route_table_r.id
}

resource "aws_ec2_transit_gateway_route" "tgw_route_table_entry_r" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.tgw_security_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ec2_tgw_route_table_r.id
}

resource "aws_ec2_transit_gateway_route" "tgw_reverse_route_table_entry_r" {
  destination_cidr_block         = aws_vpc.vpc_r.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_attachment_r.id
  transit_gateway_route_table_id = var.TgwSecurityRouteTableIdP
}
/*********************** Security Group Configuration ************************/
resource "aws_security_group" "bastion_gwlbe_public_r"{
  description = "Security group for the mgmt subnet of the vSRX App VPC"
  name = "${var.deployment_name_p}-vSRX-bastion-public-sg"
  vpc_id = aws_vpc.vpc_r.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "Ingress rule to allow ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.host_sg_p]
  }
  ingress {
    description      = "Ingress rule to allow ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_subnet.gwlbe_subnet_r.cidr_block]
  }
 
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.public_subnet_r.cidr_block]
  }
 
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.private_subnet_r.cidr_block]
    }
 
  tags = {
    Name = "${var.deployment_name_p}-vSRX-bastion-public-sg"
  }
}

resource "aws_security_group" "bastion_gwlbe_private_r" {
  description = "Security group for the data subnet of the vSRX App VPC"
  name = "${var.deployment_name_p}-vSRX-bastion-private-sg"
  vpc_id = aws_vpc.vpc_r.id
  egress{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.public_subnet_r.cidr_block, 
                        aws_subnet.private_subnet_r.cidr_block]
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-bastion-private-sg"
  }
}

resource "aws_instance" "public_bastion_host_r" {
  availability_zone = var.availability_zones_p
  ami  = var.ami_id_p 
  instance_type  = var.instance_type_p  
  key_name =  var.key_pair_p
  security_groups = [aws_security_group.bastion_gwlbe_public_r.id]
  subnet_id = aws_subnet.public_subnet_r.id
  tags={
     Name = "${var.deployment_name_p}-vSRX-bastion-host-public-subnet"
  }
}

resource "aws_instance" "private_bastion_host_r" {
  availability_zone = var.availability_zones_p
  ami  = var.ami_id_p 
  instance_type  = var.instance_type_p  
  key_name =  var.key_pair_p
  security_groups = [aws_security_group.bastion_gwlbe_private_r.id]
  subnet_id = aws_subnet.private_subnet_r.id
  tags={
     Name = "${var.deployment_name_p}-vSRX-bastion-host-private-subnet"
  }
}

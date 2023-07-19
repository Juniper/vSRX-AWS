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

resource "aws_eip" "nat_gw_eip_r" {
  vpc  = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-natgw-eip"
  }
}

resource "aws_nat_gateway" "nat_gw_r" {
  allocation_id     = aws_eip.nat_gw_eip_r.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.gwlbe_subnet_1_r.id

  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-natgw"
  }
  depends_on        = [aws_internet_gateway.igw_r]

}

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

resource "aws_subnet" "gwlbe_subnet_1_r" {
  availability_zone    =var.availability_zones_p
  vpc_id               = aws_vpc.vpc_r.id
  cidr_block           = var.gwlbe_cidr_1_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlbe-subnet"
  }
}

resource "aws_subnet" "gwlbe_subnet_2_r" {
  availability_zone    =var.availability_zones_p
  vpc_id               = aws_vpc.vpc_r.id
  cidr_block           = var.gwlbe_cidr_2_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlbe-subnet"
  }
}

resource "aws_route_table" "public_route_table_r" {
  vpc_id       = aws_vpc.vpc_r.id
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point_1_r.id
  }
 
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-public-route"
  }
}


resource "aws_route_table" "private_route_table_r" {
  vpc_id           = aws_vpc.vpc_r.id
  route {
    cidr_block     = "0.0.0.0/0"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point_2_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-private-route"
  }
}

resource "aws_route_table" "gwlbe_route_table_r" {
  vpc_id               = aws_vpc.vpc_r.id
  route {
    cidr_block       = var.public_cidr_p
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point_1_r.id
  }
  route {
    cidr_block          = var.private_cidr_p
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point_2_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlbe-route"
  }
}

resource "aws_route_table" "gwlbe_1_route_table_r" {
  vpc_id               = aws_vpc.vpc_r.id
  route {
    cidr_block       = "0.0.0.0/0"
    gateway_id       = aws_internet_gateway.igw_r.id
  }
}

resource "aws_route_table" "gwlbe_2_route_table_r"{
  vpc_id               = aws_vpc.vpc_r.id
  route {
    cidr_block       = "0.0.0.0/0"
    natnat_gateway_id = aws_nat_gateway.nat_gw_r.id
  }
}


resource "aws_route_table_association" "public_subnet_route_association_r" {
  subnet_id      = aws_subnet.public_subnet_r.id
  route_table_id = aws_route_table.public_route_table_r.id
}

resource "aws_route_table_association" "private_subnet_route_association_r" {
  subnet_id      = aws_subnet.private_subnet_r.id
  route_table_id = aws_route_table.private_route_table_r.id
} 

resource "aws_route_table_association" "gwlbe_subnet_route_association_r" {
  gateway_id = aws_internet_gateway.igw_r.id
  route_table_id = aws_route_table.gwlbe_route_table_r.id
}

resource "aws_route_table_association" "gwlbe_subnet_route_association_1_r" {
  subnet_id      = aws_subnet.gwlbe_subnet_1_r.id
  route_table_id = aws_route_table.gwlbe_1_route_table_r.id
}

resource "aws_route_table_association" "gwlbe_subnet_route_association_2_r" {
  subnet_id      = aws_subnet.gwlbe_subnet_2_r.id
  route_table_id = aws_route_table.gwlbe_2_route_table_r.id
}


################################################################################
resource "aws_vpc_endpoint" "gwlbe_end_point_1_r" {
  service_name      = var.GwlbServiceNameP
  subnet_ids        = [aws_subnet.gwlbe_subnet_1_r.id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = aws_vpc.vpc_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlb-end-point"
  }
}

resource "aws_vpc_endpoint" "gwlbe_end_point_2_r" {
  service_name      = var.GwlbServiceNameP
  subnet_ids        = [aws_subnet.gwlbe_subnet_2_r.id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = aws_vpc.vpc_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-app-${var.availability_zones_p}-gwlb-end-point"
  }
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
    cidr_blocks      = [aws_subnet.gwlbe_subnet_1_r.cidr_block]
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

resource "aws_security_group" "bastion_private_r" {
  description = "Security group for the private subnet of the vSRX App VPC"
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
  security_groups = [aws_security_group.bastion_private_r.id]
  subnet_id = aws_subnet.private_subnet_r.id
  tags={
     Name = "${var.deployment_name_p}-vSRX-bastion-host-private-subnet"
  }
}

resource "aws_instance" "bastion_host_r" {
  availability_zone = var.availability_zones_p
  ami  = var.ami_id_p 
  instance_type  = var.instance_type_p  
  key_name =  var.key_pair_p
  security_groups = [aws_security_group.bastion_gwlbe_public_r.id]
  subnet_id = aws_subnet.gwlbe_subnet_1_r.id
  tags={
     Name = "${var.deployment_name_p}-vSRX-bastion-host-gwlbe-subnet"
  }
}


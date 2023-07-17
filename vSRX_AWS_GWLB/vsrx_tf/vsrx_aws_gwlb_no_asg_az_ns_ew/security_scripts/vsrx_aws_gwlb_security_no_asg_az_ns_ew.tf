# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

provider "aws" {
   access_key = var.access_key
   secret_key = var.secret_key
   region     = var.region
}

locals {
  isRpmPortC = alltrue([
  var.vsrx_gwlb_health_protocol_p == "TCP",
  var.vsrx_gwlb_health_port_p == 49160])
}


resource "aws_vpc" "vpc_r" {
  cidr_block           = var.vpc_cidr_p
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-vpc"
  }
}

resource "aws_internet_gateway" "igw_r" {
  vpc_id = aws_vpc.vpc_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-vpc-igw"
  }
}

data "aws_ec2_transit_gateway" "tgw_id" {
  id = var.tgw_id_p
}
/*********************** AZ1 Configuration ************************/
resource "aws_subnet" "mgmt_subnet1_r" {
  availability_zone       =var.availability_zones_p[0]
  vpc_id                  = aws_vpc.vpc_r.id
  cidr_block              = var.mgmt_cidr_az1_p
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-mgmt-subnet"
  }
}

resource "aws_subnet" "data_subnet1_r" {
  availability_zone       =var.availability_zones_p[0]
  vpc_id                  = aws_vpc.vpc_r.id
  cidr_block              = var.data_cidr_az1_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-data-subnet"
  }
}

resource "aws_subnet" "gwlbe_subnet1_r" {
  availability_zone    =var.availability_zones_p[0]
  vpc_id               = aws_vpc.vpc_r.id
  cidr_block           = var.gwlbe_cidr_az1_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-gwlbe-subnet"
  }
}

resource "aws_subnet" "tgw_subnet1_r" {
  availability_zone  =var.availability_zones_p[0]
  vpc_id             = aws_vpc.vpc_r.id
  cidr_block         = var.tgw_cidr_az1_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-tgw-subnet"
  }
}

resource "aws_route_table" "mgmt_route_table1_r" {
  vpc_id       = aws_vpc.vpc_r.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_r.id
  }
  route {
    cidr_block       = "10.0.0.0/8"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point1_r.id
  }
  route {
    cidr_block       = "172.16.0.0/12"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point1_r.id
  }
  route {
    cidr_block       = "192.168.0.0/16"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point1_r.id
  }

  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-mgmt-route"
  }
}

resource "aws_route_table" "data_route_table1_r" {
  vpc_id           = aws_vpc.vpc_r.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw1_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-data-route"
  }
}

resource "aws_route_table" "gwlbe_route_table1_r" {
  vpc_id               = aws_vpc.vpc_r.id
  route {
    cidr_block         = "0.0.0.0/0"
    nat_gateway_id     = aws_nat_gateway.nat_gw1_r.id
  }
  route {
    cidr_block          = "10.0.0.0/8"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  route {
    cidr_block          = "172.16.0.0/12"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  route {
    cidr_block          = "192.168.0.0/16"
    transit_gateway_id  = data.aws_ec2_transit_gateway.tgw_id.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-gwlbe-route"
  }
}

resource "aws_route_table" "tgw_route_table1_r" {
  vpc_id             = aws_vpc.vpc_r.id
  route {
    cidr_block       = "0.0.0.0/0"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point1_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-tgw-route"
  }
}

resource "aws_route_table_association" "mgmt_subnet_route_association1_r" {
  subnet_id      = aws_subnet.mgmt_subnet1_r.id
  route_table_id = aws_route_table.mgmt_route_table1_r.id
}

resource "aws_route_table_association" "data_subnet_route_association1_r" {
  subnet_id      = aws_subnet.data_subnet1_r.id
  route_table_id = aws_route_table.data_route_table1_r.id
} 

resource "aws_route_table_association" "gwlbe_subnet_route_association1_r" {
  subnet_id      = aws_subnet.gwlbe_subnet1_r.id
  route_table_id = aws_route_table.gwlbe_route_table1_r.id
}

resource "aws_route_table_association" "tgw_subnet_route_association1_r" {
  subnet_id      = aws_subnet.tgw_subnet1_r.id
  route_table_id = aws_route_table.tgw_route_table1_r.id
}

resource "aws_eip" "nat_gw_eip1_r" {
  vpc  = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-natgw-eip"
  }
}

resource "aws_nat_gateway" "nat_gw1_r" {
  allocation_id     = aws_eip.nat_gw_eip1_r.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.mgmt_subnet1_r.id

  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-natgw"
  }
  depends_on        = [aws_internet_gateway.igw_r]

}

resource "aws_vpc_endpoint" "gwlbe_end_point1_r" {
  service_name      = aws_vpc_endpoint_service.gwlb_endpoint_service_r.service_name
  subnet_ids        = [aws_subnet.gwlbe_subnet1_r.id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = aws_vpc.vpc_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-gwlb-end-point"
  }
  depends_on        = [aws_lb.gwlb_r]

}

###############################################################################
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_vpc_attachment_r" {
  subnet_ids             = [aws_subnet.tgw_subnet1_r.id,
                        aws_subnet.tgw_subnet2_r.id]
  transit_gateway_id     = data.aws_ec2_transit_gateway.tgw_id.id  
  vpc_id                 = aws_vpc.vpc_r.id
  appliance_mode_support = "enable"
  transit_gateway_default_route_table_association=false
  transit_gateway_default_route_table_propagation=false
}

/*********************** AZ2 Configuration ************************/
resource "aws_subnet" "mgmt_subnet2_r" {
  availability_zone       = var.availability_zones_p[1]
  vpc_id                  = aws_vpc.vpc_r.id
  cidr_block              = var.mgmt_cidr_az2_p
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-mgmt-subnet"
  }
}

resource "aws_subnet" "data_subnet2_r" {
  availability_zone   = var.availability_zones_p[1]
  vpc_id              = aws_vpc.vpc_r.id
  cidr_block          = var.data_cidr_az2_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-data-subnet"
  }
}

resource "aws_subnet" "gwlbe_subnet2_r" {
  availability_zone     = var.availability_zones_p[1]
  vpc_id                = aws_vpc.vpc_r.id
  cidr_block            = var.gwlbe_cidr_az2_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-gwlbe-subnet"
  }
}

resource "aws_subnet" "tgw_subnet2_r" {
  availability_zone    = var.availability_zones_p[1]
  vpc_id               = aws_vpc.vpc_r.id
  cidr_block           = var.tgw_cidr_az2_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-tgw-subnet"
  }
}

resource "aws_route_table" "mgmt_route_table2_r" {
  vpc_id       = aws_vpc.vpc_r.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_r.id
  }
  route {
    cidr_block       = "10.0.0.0/8"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point2_r.id
  }
  route {
    cidr_block      = "192.168.0.0/16"
    vpc_endpoint_id = aws_vpc_endpoint.gwlbe_end_point2_r.id
  }
  route {
    cidr_block      = "172.16.0.0/12"
    vpc_endpoint_id = aws_vpc_endpoint.gwlbe_end_point2_r.id
  }

  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-mgmt-route"
  }
}

resource "aws_route_table" "data_route_table2_r" {
  vpc_id           = aws_vpc.vpc_r.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw2_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-data-route"
  }
}

resource "aws_route_table" "gwlbe_route_table2_r" {
  vpc_id           = aws_vpc.vpc_r.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw2_r.id
  }
  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = data.aws_ec2_transit_gateway.tgw_id.id
  }
  route {
    cidr_block         = "172.16.0.0/12"
    transit_gateway_id = data.aws_ec2_transit_gateway.tgw_id.id
  }
  route {
    cidr_block         = "192.168.0.0/16"
    transit_gateway_id = data.aws_ec2_transit_gateway.tgw_id.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-gwlbe-route"
  }
}

resource "aws_route_table" "tgw_route_table2_r" {
  vpc_id             = aws_vpc.vpc_r.id
  route {
    cidr_block       = "0.0.0.0/0"
    vpc_endpoint_id  = aws_vpc_endpoint.gwlbe_end_point2_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-tgw-route"
  }
  depends_on         = [aws_lb.gwlb_r]

}

resource "aws_route_table_association" "mgmt_subnet_route_association2_r" {
  subnet_id      = aws_subnet.mgmt_subnet2_r.id
  route_table_id = aws_route_table.mgmt_route_table2_r.id
}

resource "aws_route_table_association" "data_subnet_route_association2_r" {
  subnet_id      = aws_subnet.data_subnet2_r.id
  route_table_id = aws_route_table.data_route_table2_r.id
}

resource "aws_route_table_association" "gwlbe_subnet_route_association2_r" {
  subnet_id      = aws_subnet.gwlbe_subnet2_r.id
  route_table_id = aws_route_table.gwlbe_route_table2_r.id
}

resource "aws_route_table_association" "tgw_subnet_route_association2_r" {
   subnet_id      = aws_subnet.tgw_subnet2_r.id
   route_table_id = aws_route_table.tgw_route_table2_r.id
}

resource "aws_eip" "nat_gw_eip2_r"{
  vpc  = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-natgw-eip"
  }
}

resource "aws_nat_gateway" "nat_gw2_r" {
  allocation_id     = aws_eip.nat_gw_eip2_r.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.mgmt_subnet2_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-natgw"
  }
}

resource "aws_vpc_endpoint" "gwlbe_end_point2_r" {
  service_name      = aws_vpc_endpoint_service.gwlb_endpoint_service_r.service_name
  subnet_ids        = [aws_subnet.gwlbe_subnet2_r.id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = aws_vpc.vpc_r.id
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-gwlb-end-point"
  }
}

################################################################################
resource "aws_ec2_transit_gateway_route_table" "ec2_tgw_route_table_r" {
  transit_gateway_id = data.aws_ec2_transit_gateway.tgw_id.id
}

resource "aws_ec2_transit_gateway_route_table_association" "ec2_tgw_route_association_r" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_attachment_r.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ec2_tgw_route_table_r.id
}
/*********************** Security Group Configuration ************************/
resource "aws_security_group" "vsrx_sg_mgmt_r"{
  description = "Security group for the mgmt subnet of the vSRX security VPC"
  name = "${var.deployment_name_p}-vSRX-mgmt-sg"
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
    cidr_blocks      = [var.vsrx_host_sg_p]
  }
  ingress {
    description      = "Ingress rule to allow http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.vsrx_host_sg_p]
  }
  ingress{
    description      = "Ingress rule to allow http"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.vsrx_host_sg_p]
  }
  ingress {
    description      = "ingress rule to allow icmp"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = [var.vsrx_host_sg_p]
  }
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.mgmt_subnet1_r.cidr_block]
  }
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.mgmt_subnet2_r.cidr_block]
    }
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.data_subnet1_r.cidr_block]
    }
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.data_subnet2_r.cidr_block]
    }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-mgmt-sg"
  }
}

resource "aws_security_group" "vsrx_sg_data_r" {
  description = "Security group for the data subnet of the vSRX security VPC"
  name = "${var.deployment_name_p}-vSRX-data-sg"
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
    cidr_blocks      = [aws_subnet.data_subnet1_r.cidr_block, 
                        aws_subnet.data_subnet2_r.cidr_block]
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-data-sg"
  }
}

resource "aws_iam_role" "vsrx_boot_role_r" {
  name="${var.deployment_name_p}-vSRX-boot-role"
  path="/"
 
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
  
  inline_policy {
    name   = "${var.deployment_name_p}-vSRX-boot-policy"
    policy = data.aws_iam_policy_document.vsrx_boot_role_policy_r.json
  }
 
}

data "aws_iam_policy_document" "vsrx_boot_role_policy_r" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name_p}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData", 
                 "cloudwatch:GetMetricData", 
                 "cloudwatch:ListMetrics",
                 "cloudwatch:GetMetricStatistics"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
  }
}


resource "aws_iam_instance_profile" "vsrx_iam_instance_profile_r" {
  name = "${var.deployment_name_p}-vSRX-iam-instance-profile"
  role = aws_iam_role.vsrx_boot_role_r.name
 
}


resource "aws_launch_template" "vsrx_launch_template_1r" {
  name = "${var.deployment_name_p}-vSRX-launch-template-1"
  metadata_options {
      instance_metadata_tags = "enabled"
  }
  iam_instance_profile {
      arn = aws_iam_instance_profile.vsrx_iam_instance_profile_r.arn
  }
  block_device_mappings {
      device_name = "/dev/sda1"
      ebs {
        volume_size           = var.vsrx_disk_vol_p
        delete_on_termination = true
        volume_type           = "gp2"
      }
  }
  image_id      = var.vsrx_ami_id_p
  instance_type = var.vsrx_instance_type_p
  key_name      = var.vsrx_key_pair_p
   network_interfaces {
      delete_on_termination = "true"
      description = "${var.deployment_name_p}-vSRX-mgmt-interface"
      device_index = 0
      interface_type = "interface"
      subnet_id = aws_subnet.mgmt_subnet1_r.id
      security_groups =[aws_security_group.vsrx_sg_mgmt_r.id] 

    }
    network_interfaces {
      delete_on_termination = "true"
      description = "${var.deployment_name_p}-vSRX-data-interface"
      device_index = 1
      interface_type = "interface"
      subnet_id = aws_subnet.data_subnet1_r.id
      security_groups =[aws_security_group.vsrx_sg_data_r.id]

    }
  user_data = base64encode(templatefile("user-data",{isRpmPortC="${local.isRpmPortC}"}))
}

resource "aws_launch_template" "vsrx_launch_template_2r" {
  name = "${var.deployment_name_p}-vSRX-launch-template-2"
  metadata_options {
      instance_metadata_tags = "enabled"
  }
  iam_instance_profile {
      arn = aws_iam_instance_profile.vsrx_iam_instance_profile_r.arn
  }
  block_device_mappings {
      device_name = "/dev/sda1"
      ebs {
        volume_size           = var.vsrx_disk_vol_p
        delete_on_termination = true
        volume_type           = "gp2"
      }
  }
  image_id      = var.vsrx_ami_id_p
  instance_type = var.vsrx_instance_type_p
  key_name      = var.vsrx_key_pair_p
   network_interfaces {
      delete_on_termination = "true"
      description = "${var.deployment_name_p}-vSRX-mgmt-interface"
      device_index = 0
      interface_type = "interface"
      subnet_id = aws_subnet.mgmt_subnet2_r.id
      security_groups =[aws_security_group.vsrx_sg_mgmt_r.id] 

    }
    network_interfaces {
      delete_on_termination = "true"
      description = "${var.deployment_name_p}-vSRX-data-interface"
      device_index = 1
      interface_type = "interface"
      subnet_id = aws_subnet.data_subnet2_r.id
      security_groups =[aws_security_group.vsrx_sg_data_r.id]

    }
  user_data = base64encode(templatefile("user-data",{isRpmPortC="${local.isRpmPortC}"}))
}

resource "aws_instance" "vSrx1R"{

  launch_template {
    id = aws_launch_template.vsrx_launch_template_1r.id
   
  }
  availability_zone = var.availability_zones_p[0]
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[0]}-instance-1"
  }
}

    
resource "aws_instance" "vSrx2R"{
 
  launch_template {
    id = aws_launch_template.vsrx_launch_template_2r.id
   
  }
 
  availability_zone = var.availability_zones_p[1]
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-${var.availability_zones_p[1]}-instance-2"
  }
}


resource "aws_iam_policy" "lambda_pol_logs" {
  name = "${var.deployment_name_p}-vSrx-policy-lambda-1"
  path ="/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Effect": "Allow",
      "Resource": ["arn:aws:logs:*:*:*"]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_pol" {
  name = "${var.deployment_name_p}-vSrx-policy-lambda-2"
  path ="/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["ec2:DescribeImages","ec2:*","events:*","cloudwatch:*","autoscaling:*","elasticloadbalancing:*","cloudformation:DescribeStacks"],
      "Effect": "Allow",
      "Resource": ["*"]
    }
  ]
}
EOF
}

data "aws_iam_policy" "CloudWatchFullAccess" {
  arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}
data "aws_iam_policy" "AmazonS3FullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
data "aws_iam_policy" "AmazonEC2FullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "vSrxLambdaRoleR"{
   name = "${var.deployment_name_p}-vSRX-lambda-iam-policies"
   managed_policy_arns = [aws_iam_policy.lambda_pol.arn, aws_iam_policy.lambda_pol_logs.arn , data.aws_iam_policy.CloudWatchFullAccess.arn, data.aws_iam_policy.AmazonS3FullAccess.arn, data.aws_iam_policy.AmazonEC2FullAccess.arn, data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn]
   assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource aws_lambda_function "vSrxLambdaFunctionR" {
  function_name = "${var.deployment_name_p}-vSRX-config-lambda-func"
  role = aws_iam_role.vSrxLambdaRoleR.arn
  architectures = ["x86_64"]
  handler = "vsrx_lambda.event_handler" 
  package_type = "Zip"
  s3_bucket = var.s3_bucket_name_p
  s3_key = var.s3_lambda_zip_p 
  timeout = 300
  vpc_config {
    security_group_ids = [aws_security_group.vsrx_sg_data_r.id, aws_security_group.vsrx_sg_mgmt_r.id]
    subnet_ids = [aws_subnet.data_subnet2_r.id,aws_subnet.data_subnet1_r.id]
  }
  runtime = "python3.9"
  tags = {
    Name = "${var.deployment_name_p}-vSRX-lambda-func"
  }
  depends_on   = [aws_nat_gateway.nat_gw1_r,
                aws_nat_gateway.nat_gw2_r,
                aws_route_table_association.data_subnet_route_association1_r,
                aws_route_table_association.data_subnet_route_association2_r,
                aws_route_table.data_route_table1_r,
                aws_route_table.data_route_table2_r,
                aws_route_table_association.mgmt_subnet_route_association1_r,
                aws_route_table_association.mgmt_subnet_route_association2_r,
                aws_route_table.mgmt_route_table1_r,
                aws_route_table.mgmt_route_table2_r,
                aws_internet_gateway.igw_r]
 }



resource "aws_cloudformation_stack" "vSrxAssignEip1R" {
  depends_on    = [aws_lambda_function.vSrxLambdaFunctionR]
  name = "${var.deployment_name_p}-vsrx-assign-eip-1"   
  
  template_body =<<STACK
{
"Resources" : {

   "vSrxAssignEip1":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vSrxLambdaFunctionR.arn}",
          "region": "${var.region}",
          "stack_name": "${var.deployment_name_p}-vsrx-assign-eip-1",
          "log_level": "${var.log_level_p}",
          "cr_type": "alloc_and_attach_eip",
          "instance_id": "${aws_instance.vSrx1R.id}",
          "dev_index": "0"
          
        }
    }
 }

}
STACK
}

resource "aws_cloudformation_stack" "vSrxAssignEip2R" {
  depends_on    = [aws_lambda_function.vSrxLambdaFunctionR]
  name = "${var.deployment_name_p}-vsrx-assign-eip-2"   
  
  template_body =<<STACK
{
"Resources" : {

   "vSrxAssignEip2":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vSrxLambdaFunctionR.arn}",
          "region": "${var.region}",
          "stack_name": "${var.deployment_name_p}-vsrx-assign-eip-2",
          "log_level": "${var.log_level_p}",
          "cr_type": "alloc_and_attach_eip",
          "instance_id": "${aws_instance.vSrx2R.id}",
          "dev_index": "0"
          
        }
    }
 }

}
STACK
}


resource "aws_cloudformation_stack" "vSrxFetchDataIp1R" {
  depends_on  = [aws_lambda_function.vSrxLambdaFunctionR]
  name = "${var.deployment_name_p}-vsrx-fetch-data-ip-1"
  template_body =<<STACK
 {
  "Resources" : {

   "vSrxFetchDataIp1":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vSrxLambdaFunctionR.arn}",
          "region": "${var.region}",
          "stack_name": "${var.deployment_name_p}-vsrx-fetch-data-ip-1",
          "log_level": "${var.log_level_p}",
          "cr_type": "fetch_instance_ip" ,
          "instance_id": "${aws_instance.vSrx1R.id}",
          "dev_index": "1",
          "type"     : "private"
          }
        }
    },
    "Outputs": {
      "CustomResourceAttr": {
            "Value": {"Fn::GetAtt": ["vSrxFetchDataIp1","interface_ip"]
                
            }
        }
      }  
    
}
STACK
}
 
resource "aws_cloudformation_stack" "vSrxFetchDataIp2R" {
  depends_on  = [aws_lambda_function.vSrxLambdaFunctionR]
  name = "${var.deployment_name_p}-vsrx-fetch-data-ip-2"
  template_body =<<STACK
 {
  "Resources" : {

   "vSrxFetchDataIp2":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vSrxLambdaFunctionR.arn}",
          "region": "${var.region}",
          "stack_name": "${var.deployment_name_p}-vsrx-fetch-data-ip-2",
          "log_level": "${var.log_level_p}",
          "cr_type": "fetch_instance_ip" ,
          "instance_id": "${aws_instance.vSrx2R.id}",
          "dev_index": "1",
          "type"     : "private"
          }
        }
    },
    "Outputs": {
      "CustomResourceAttr": {
            "Value": {"Fn::GetAtt": ["vSrxFetchDataIp2","interface_ip"]
                
            }
        }
      }  
    
}
STACK
} 



resource "aws_lb" "gwlb_r" {
  name                             = "${var.deployment_name_p}-vSRX-gwlb"
  load_balancer_type               = "gateway"
  ip_address_type                  = "ipv4"
  enable_cross_zone_load_balancing = true

  subnet_mapping {
    subnet_id = aws_subnet.data_subnet1_r.id
  }
  subnet_mapping {
    subnet_id = aws_subnet.data_subnet2_r.id
  }
  tags = {
    "Name" = "${var.deployment_name_p}-vSRX-gwlb"
  }
}

resource "aws_lb_target_group" "gwlb_target_group_r" {
  name     = "${var.deployment_name_p}-tg"
  health_check {
     port               = var.vsrx_gwlb_health_port_p
     protocol           = var.vsrx_gwlb_health_protocol_p
     timeout            = 30
     healthy_threshold  = 5
     unhealthy_threshold= 3
     interval           = 30
    }
  deregistration_delay = 10
  port                 = 6081
  protocol             = "GENEVE"
  vpc_id               = aws_vpc.vpc_r.id
  target_type          = "ip"
  depends_on           =[aws_lb.gwlb_r,aws_instance.vSrx1R,aws_instance.vSrx2R]
}

resource "aws_lb_target_group_attachment" "Target1" {
  target_group_arn = aws_lb_target_group.gwlb_target_group_r.arn
  availability_zone = var.availability_zones_p[0]
  target_id        = "${resource.aws_cloudformation_stack.vSrxFetchDataIp1R.outputs["CustomResourceAttr"]}"
  depends_on       = [aws_lb_target_group.gwlb_target_group_r,resource.aws_cloudformation_stack.vSrxFetchDataIp1R]
}

resource "aws_lb_target_group_attachment" "Target2" {
  target_group_arn = aws_lb_target_group.gwlb_target_group_r.arn
  availability_zone = var.availability_zones_p[1]
  target_id        = "${resource.aws_cloudformation_stack.vSrxFetchDataIp2R.outputs["CustomResourceAttr"]}"
  depends_on       = [aws_lb_target_group.gwlb_target_group_r,resource.aws_cloudformation_stack.vSrxFetchDataIp2R]
}

resource "aws_vpc_endpoint_service" "gwlb_endpoint_service_r" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb_r.arn]
}


resource "aws_lb_listener" "vsrx_listener_r"{
  default_action {
    target_group_arn = aws_lb_target_group.gwlb_target_group_r.arn
    type             = "forward"
  }
  load_balancer_arn  = aws_lb.gwlb_r.arn
}

output "gwlb_id" {
  value = aws_lb.gwlb_r.id
}

output "gwlb_service_name" {
  value = aws_vpc_endpoint_service.gwlb_endpoint_service_r.service_name
}

output "TransitGatewayId"{
    description = "Transit gateway ID"
    value       = data.aws_ec2_transit_gateway.tgw_id.id
    
}

output "VpcSecurityAttachmentID"{
    description= "Security VPC - TGW attachment ID"
    value = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_attachment_r
}

output "TgwRouteTableID"{
  description= "Transit gateway security attachment route table ID"
  value =  aws_ec2_transit_gateway_route_table.ec2_tgw_route_table_r
} 


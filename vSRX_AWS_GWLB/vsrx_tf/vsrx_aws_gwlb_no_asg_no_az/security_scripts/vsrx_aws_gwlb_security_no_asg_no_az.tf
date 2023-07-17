# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

provider "aws" {
   access_key = "${var.access_key}"
   secret_key = "${var.secret_key}"
   region     = "${var.region}"
}

locals {
  isRpmPortC = alltrue([
  var.vsrx_gwlb_health_protocol_p == "TCP",
  var.vsrx_gwlb_health_port_p == 49160])
}

resource "aws_vpc" "VpcR"  {
  cidr_block = "${var.vpc_cidr_p}"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-vpc"
    }
} 

resource "aws_internet_gateway" "IgwR"{
  vpc_id = aws_vpc.VpcR.id
}

resource "aws_subnet" "MgmtSubnetR"{
  availability_zone="${var.availability_zones_p}"
  vpc_id = aws_vpc.VpcR.id
  cidr_block = "${var.mgmt_cidr_p}"
}

resource "aws_route_table" "MgmtRouteTableR"{
  vpc_id = aws_vpc.VpcR.id
 }

resource "aws_route" "MgmtRouteTableEntryR"{
   route_table_id = aws_route_table.MgmtRouteTableR.id
   destination_cidr_block ="0.0.0.0/0"
   gateway_id = aws_internet_gateway.IgwR.id
   depends_on = [aws_route_table.MgmtRouteTableR]

}

resource "aws_route_table_association" "MgmtSubnetRouteAssociationR"{
   subnet_id = aws_subnet.MgmtSubnetR.id
   route_table_id = aws_route_table.MgmtRouteTableR.id
  }

resource "aws_eip" "NatGwREipR"{
  vpc= true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-natgw-eip"
  }
}

resource "aws_nat_gateway" "NatGwR" {
  allocation_id = aws_eip.NatGwREipR.id
  connectivity_type = "public"
  subnet_id     = aws_subnet.MgmtSubnetR.id

  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-natgw"
  }
  depends_on = [aws_internet_gateway.IgwR]
}

resource "aws_subnet" "DataSubnetR"{
  availability_zone="${var.availability_zones_p}"
  vpc_id = aws_vpc.VpcR.id
  cidr_block = "${var.data_cidr_p}"
 
}

resource "aws_route_table" "DataRouteTableR"{
  vpc_id = aws_vpc.VpcR.id
  }

resource "aws_route" "DataRouteTableEntryR"{
   route_table_id = aws_route_table.DataRouteTableR.id
   destination_cidr_block ="0.0.0.0/0"
   nat_gateway_id = aws_nat_gateway.NatGwR.id
   depends_on = [aws_route_table.DataRouteTableR]

}

resource "aws_route_table_association" "DataSubnetRouteAssociationR"{
   subnet_id = aws_subnet.DataSubnetR.id
   route_table_id = aws_route_table.DataRouteTableR.id
   } 

resource "aws_security_group" "vSrxSgMgmtR"{
  description = "security group for the public subnet of vpc"
  vpc_id = aws_vpc.VpcR.id
  egress{

    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    }
  
  ingress{
    description      = "ingress rule to allow ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_subnet.MgmtSubnetR.cidr_block]
    
  }
  
  ingress{
    description      = "ingress rule to allow http"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_subnet.MgmtSubnetR.cidr_block]
  }
  
  ingress{ 
    description      = "ingress rule to allow http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [aws_subnet.MgmtSubnetR.cidr_block]
  }
  
  ingress{
    description      = "ingress rule to allow icmp"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = [aws_subnet.MgmtSubnetR.cidr_block]
  } 

  ingress{
    description      = "ingress rule to allow ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.vsrx_host_sg_p]
  }
  
  ingress{
    description      = "ingress rule to allow http"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.vsrx_host_sg_p]
  }

  ingress{
    description      = "ingress rule to allow http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.vsrx_host_sg_p]

  }
  
  ingress{
    description      = "ingress rule to allow icmp"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = [var.vsrx_host_sg_p]

  } 
  tags = {
    Name = "${var.deployment_name_p}-vSRX-mgmt-sg"
  }
}

resource "aws_security_group" "vSrxSgDataR"{

  description = "security group for the private subnet of vpc"
  vpc_id = aws_vpc.VpcR.id
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
    protocol         = -1
    cidr_blocks      = [aws_subnet.DataSubnetR.cidr_block]

  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-data-sg"
  }
  
}


resource "aws_iam_policy" "vSrxBootPolR" {
  name = "${var.deployment_name_p}-vSRX-policy"
  path ="/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject" 
      ],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::*", "arn:aws:s3:::${var.s3_bucket_name_p}", "arn:aws:s3:::${var.s3_bucket_name_p}/*"]
    }
  ]
}
EOF
}

resource "aws_iam_role" "vSrxBootRoleR"{
   name = "${var.deployment_name_p}-vSRX-boot-role"
   path ="/"
   managed_policy_arns = [aws_iam_policy.vSrxBootPolR.arn]
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
}

resource "aws_iam_instance_profile" "vSrxInstanceProfile" {
  name = "${var.deployment_name_p}-vSRX-iam-instance-profile"
  role = aws_iam_role.vSrxBootRoleR.name 
}


resource "aws_launch_template" "vSrxLaunchTemplateR" {
 name = "${var.deployment_name_p}-vSRX-launch-template"

 iam_instance_profile {
   arn = aws_iam_instance_profile.vSrxInstanceProfile.arn
   
  }
 block_device_mappings {
    device_name = "/dev/sda1"
 

    ebs {
      volume_size = 20
      delete_on_termination = "true"
      volume_type = "gp2"
    
    }
 }
    image_id = var.vsrx_ami_id_p
    instance_type = var.vsrx_instance_type_p
    key_name =  var.vsrx_key_pair_p
    network_interfaces {
      delete_on_termination = "true"
      description = "management interface"
      device_index = 0
      interface_type = "interface"
      subnet_id = aws_subnet.MgmtSubnetR.id
      security_groups =[aws_security_group.vSrxSgMgmtR.id] 

    }
    network_interfaces {
      delete_on_termination = "true"
      description = "data interface-ge"
      device_index = 1
      interface_type = "interface"
      subnet_id = aws_subnet.DataSubnetR.id
      security_groups =[aws_security_group.vSrxSgDataR.id]

    }
    
    user_data = base64encode(templatefile("user-data",{isRpmPortC = "${local.isRpmPortC}" }))

}



resource "aws_instance" "vSrxR"{
  launch_template {
    id = aws_launch_template.vSrxLaunchTemplateR.id
   
  }
  availability_zone = var.availability_zones_p
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
    security_group_ids = [aws_security_group.vSrxSgMgmtR.id, aws_security_group.vSrxSgDataR.id]
    subnet_ids = [aws_subnet.DataSubnetR.id]
  }
  runtime = "python3.9"
  depends_on = [ aws_nat_gateway.NatGwR , aws_subnet.DataSubnetR, aws_route_table.DataRouteTableR, aws_route.DataRouteTableEntryR,aws_internet_gateway.IgwR , aws_route_table_association.MgmtSubnetRouteAssociationR, aws_route_table_association.DataSubnetRouteAssociationR ,aws_route_table.MgmtRouteTableR,aws_route.MgmtRouteTableEntryR]

}


resource "aws_cloudformation_stack" "vSrxAssignEipR" {
  depends_on    = [aws_lambda_function.vSrxLambdaFunctionR]
  name = "${var.deployment_name_p}-vsrx_assign_eip"   
  
  template_body =<<STACK
{
"Resources" : {

   "vSrxAssignEip":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vSrxLambdaFunctionR.arn}",
          "region": "${var.region}",
          "stack_name": "${var.deployment_name_p}-vsrx_assign_eip",
          "log_level": "${var.log_level_p}",
          "cr_type": "alloc_and_attach_eip" ,
          "instance_id": "${aws_instance.vSrxR.id}",
          "dev_index": "0"
          
        }
    }
 }

}
STACK
}

resource "aws_cloudformation_stack" "vSrxFetchDataIpR" {
  depends_on  = [aws_lambda_function.vSrxLambdaFunctionR]
  name = "${var.deployment_name_p}-vsrx_fetch_data_ip"
  template_body =<<STACK
 {
  "Resources" : {

   "vSrxFetchDataIp":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vSrxLambdaFunctionR.arn}",
          "region": "${var.region}",
          "stack_name": "${var.deployment_name_p}-vsrx_fetch_data_ip",
          "log_level": "${var.log_level_p}",
          "cr_type": "fetch_instance_ip" ,
          "instance_id": "${aws_instance.vSrxR.id}",
          "dev_index": "1",
          "type"     : "private"
          }
        }
    },
    "Outputs": {
      "CustomResourceAttr": {
            "Value": {"Fn::GetAtt": ["vSrxFetchDataIp","interface_ip"]
                
            }
        }
      }  
    
}
STACK
}
 

resource "aws_lb" "GwlbR" {
  name               = "${var.deployment_name_p}-vSRX-gwlb"
  load_balancer_type = "gateway"
  ip_address_type    = "ipv4"
  subnet_mapping {
    subnet_id            = aws_subnet.DataSubnetR.id
    }

}

resource "aws_lb_target_group" "GwlbTargetGroupR" {
  name     = "${var.deployment_name_p}-target"
  health_check {
     port = var.vsrx_gwlb_health_port_p
     protocol = var.vsrx_gwlb_health_protocol_p 
  }
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = aws_vpc.VpcR.id
  target_type = "ip"
  
  depends_on =[aws_lb.GwlbR,aws_instance.vSrxR]
  
}


resource "aws_lb_target_group_attachment" "Targets" {
  target_group_arn = aws_lb_target_group.GwlbTargetGroupR.arn
  target_id        = "${resource.aws_cloudformation_stack.vSrxFetchDataIpR.outputs["CustomResourceAttr"]}"
  depends_on       = [aws_lb_target_group.GwlbTargetGroupR,resource.aws_cloudformation_stack.vSrxFetchDataIpR]
}

resource "aws_lb_listener" "vSrxListenerR"{
  default_action {
    target_group_arn = aws_lb_target_group.GwlbTargetGroupR.id
    type             = "forward"
  }
  load_balancer_arn = aws_lb.GwlbR.arn
}

resource "aws_vpc_endpoint_service" "GwlbEndPointR" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.GwlbR.arn]
}



resource "aws_cloudformation_stack" "ResourceInfo" {
  name =  "${var.deployment_name_p}-resource-info"                               
  template_body =<<STACK
{
"Resources" : {

   "ResourceInfo":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vSrxLambdaFunctionR.arn}",
          "region": "${var.region}",
          "stack_name": "${var.deployment_name_p}-resource-info",
          "cr_type": "get_resource_info" ,
          "resource_type": ["gwlb_end_point_service_name"],
          "service_id"   :"${aws_vpc_endpoint_service.GwlbEndPointR.id}"
          }
   }
},
  "Outputs": {
      "CustomResourceService": {
            "Value": {"Fn::GetAtt": ["ResourceInfo","gwlb_service_name"]
                
            }
        }
      }  
    
}
STACK
}


output "GwlbId" {
  value = aws_lb.GwlbR 
}

output "GwlbEndPointServices" {
  value = aws_cloudformation_stack.ResourceInfo.outputs["CustomResourceService"]
  }                          


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
  isSimpleScalingC = var.scaling_type_p == "simple_scaling" ? true : false
  isTargetScalingC = var.scaling_type_p == "target_scaling" ? true : false
  isScalingC = anytrue([local.isSimpleScalingC, local.isTargetScalingC ])
  value = (local.isScalingC ? "enable" : "disable")
  isLocalConfigC = var.configSync_p == "local_config_sync" ? true : false
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

resource "aws_subnet" "mgmt_subnet_r" {
  availability_zone       =var.availability_zones_p
  vpc_id                  = aws_vpc.vpc_r.id
  cidr_block              = var.mgmt_cidr_az1_p
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-mgmt-subnet"
  }
}

resource "aws_subnet" "data_subnet_r" {
  availability_zone       =var.availability_zones_p
  vpc_id                  = aws_vpc.vpc_r.id
  cidr_block              = var.data_cidr_az1_p
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-data-subnet"
  }
}


resource "aws_route_table" "mgmt_route_table_r" {
  vpc_id       = aws_vpc.vpc_r.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-mgmt-route"
  }
}

resource "aws_route_table" "data_route_table_r" {
  vpc_id           = aws_vpc.vpc_r.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_r.id
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-data-route"
  }
}

resource "aws_route_table_association" "mgmt_subnet_route_association_r" {
  subnet_id      = aws_subnet.mgmt_subnet_r.id
  route_table_id = aws_route_table.mgmt_route_table_r.id
}

resource "aws_route_table_association" "data_subnet_route_association_r" {
  subnet_id      = aws_subnet.data_subnet_r.id
  route_table_id = aws_route_table.data_route_table_r.id
} 


resource "aws_eip" "nat_gw_eip_r" {
  vpc  = true
  tags = {
    Name = "${var.deployment_name_p}-vSRX-security--natgw-eip"
  }
}

resource "aws_nat_gateway" "nat_gw_r" {
  allocation_id     = aws_eip.nat_gw_eip_r.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.mgmt_subnet_r.id

  tags = {
    Name = "${var.deployment_name_p}-vSRX-security-natgw"
  }
  depends_on        = [aws_internet_gateway.igw_r]

}

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
    cidr_blocks      = [aws_subnet.mgmt_subnet_r.cidr_block]
  }
  ingress{
    description      = "ingress rule to allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_subnet.data_subnet_r.cidr_block]
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
    cidr_blocks      = [aws_subnet.data_subnet_r.cidr_block]
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

resource "aws_launch_template" "vsrx_launch_template_r" {
  name = "${var.deployment_name_p}-vSRX-launch-template"
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
    description           = "${var.deployment_name_p}-vSRX-data-interface"
    device_index          = 0
    interface_type        = "interface"
    security_groups       =[aws_security_group.vsrx_sg_data_r.id]
  }
 
  user_data = base64encode(templatefile("user-data",
  {metric_collect_interval_p ="${var.metric_collect_interval_p}",
  cloudwatch_namespace_p = "${var.cloudwatch_namespace_p}",
  isRpmPortC ="${local.isRpmPortC}",isScalingC="${local.isScalingC}"}))
}


resource "aws_iam_role" "vsrx_asg_lambda_role_r" {
   name = "${var.deployment_name_p}-vSRX-lambda-iam-policies"
   managed_policy_arns = [data.aws_iam_policy.CloudWatchFullAccess.arn, 
                          data.aws_iam_policy.AmazonS3FullAccess.arn, 
                          data.aws_iam_policy.AmazonEC2FullAccess.arn, 
                          data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn]
   assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": ["lambda.amazonaws.com"]
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
  path ="/"
  inline_policy {
    name   = "${var.deployment_name_p}-vSRX-lambda-iam-policies"
    policy = data.aws_iam_policy_document.vsrx_asg_lambda_role_policy_r.json
  }
 
}

data "aws_iam_policy_document" "vsrx_asg_lambda_role_policy_r" {
  statement {
    
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup",
                 "logs:CreateLogStream",
                 "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    
    effect    = "Allow"
    actions   = ["events:*", 
                 "cloudwatch:*", 
                 "autoscaling:*",
                 "elasticloadbalancing:*",
                 "cloudformation:DescribeStacks"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage",
                 "sqs:SendMessage",
                 "sqs:GetQueueUrl",
                 "sqs:DeleteMessage",
                 "sqs:SetQueueAttributes",
                 "sqs:ChangeMessageVisibility",
                 "sqs:GetQueueAttributes"]
   resources = ["arn:aws:sqs:*:*:${aws_sqs_queue.sqs_fifo_queue_r.name}" ]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject",
                 "s3:GetBucketNotification",
                 "s3:PutBucketNotification",
                 "s3:GetBucketTagging",
                 "s3:PutBucketTagging",
                 "s3:PutObjectLegalHold",
                 "s3:GetObjectLegalHold"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name_p},arn:aws:s3:::${var.s3_bucket_name_p}/*"]
    
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["*"]
    
  }
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


resource aws_lambda_function "vsrx_asg_lambda_r" {
  function_name = "${var.deployment_name_p}-vSRX-config-lambda-func"
  description   = "Lambda function to handle Auto scaling group events and configuration"
  role          = aws_iam_role.vsrx_asg_lambda_role_r.arn
  architectures = ["x86_64"]
  handler       = "vsrx_lambda.event_handler" 
  package_type = "Zip"
  s3_bucket    = var.s3_bucket_name_p
  s3_key       = var.s3_lambda_zip_p
  timeout      = lookup(var.TimeOut,"value")
  vpc_config {
    security_group_ids = [aws_security_group.vsrx_sg_mgmt_r.id, 
                          aws_security_group.vsrx_sg_data_r.id]
    subnet_ids         = [aws_subnet.data_subnet_r.id]
  }
  runtime      = "python3.9"
  environment {
    variables = {
      asg_name  = "${var.deployment_name_p}-vSRX-ASG"
      sqs_url   = "${aws_sqs_queue.sqs_fifo_queue_r.name}"
      s3_bucket = "${var.s3_bucket_name_p}"
    }
  }
  tags = {
    Name = "${var.deployment_name_p}-vSRX-config-lambda-func"
  }
  depends_on   = [aws_nat_gateway.nat_gw_r,
                aws_route_table_association.data_subnet_route_association_r,
                aws_route_table.data_route_table_r,
                aws_route_table_association.mgmt_subnet_route_association_r,
                aws_route_table.mgmt_route_table_r,
                aws_internet_gateway.igw_r,
                aws_sqs_queue.sqs_fifo_queue_r ]
 }


resource "aws_autoscaling_group" "vsrx_asg_r" {
  name                      = "${var.deployment_name_p}-vSRX-ASG"
  max_size                  = var.asg_max_size_p
  min_size                  = var.asg_min_size_p
  desired_capacity          = var.asg_desired_size_p
  health_check_grace_period = 900
  health_check_type         = "ELB"
  wait_for_capacity_timeout = "14m"
  target_group_arns = [aws_lb_target_group.gwlb_target_group_r.arn]
  launch_template {
    id      = aws_launch_template.vsrx_launch_template_r.id
    version = "$Latest"
  }
  
  vpc_zone_identifier      = [aws_subnet.data_subnet_r.id]
                               

  initial_lifecycle_hook {
    default_result       = "ABANDON"
    heartbeat_timeout    = 3600
    name                 = "${var.deployment_name_p}-vSRX-Launch"
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
    notification_metadata = <<EOF
    {
      'log_level': '${var.log_level_p}',
      'gwlb_id': '${aws_lb.gwlb_r.id}',
      'gwlb_tg': '${aws_lb_target_group.gwlb_target_group_r.id}',
      'sqs_url': '${aws_sqs_queue.sqs_fifo_queue_r.name}',
      's3': '${var.s3_bucket_name_p}',
      'config_sync_type': '${var.configSync_p}',
      'eni_list': ['mgmt'],
      'mgmt_idx_at': '1',
      'data_idx_at': '0'
      'snet_info': {
          '${var.availability_zones_p}':{
            'mgmt': {'snet_id':'${aws_subnet.mgmt_subnet_r.id}', 'sg':'${aws_security_group.vsrx_sg_mgmt_r.id}', 'idx':'1', 'alloc_eip':'true'}
          }
        }
    }
    EOF
  }

  initial_lifecycle_hook {
    default_result       = "CONTINUE"
    name                 = "${var.deployment_name_p}-vSRX-Terminate"
    heartbeat_timeout    = 600
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    notification_metadata = <<EOF
    {
      'log_level': '${var.log_level_p}',
      'gwlb_id': '${aws_lb.gwlb_r.id}',
      'gwlb_tg': '${aws_lb_target_group.gwlb_target_group_r.id}',
      'sqs_url': '${aws_sqs_queue.sqs_fifo_queue_r.name}',
      's3': '${var.s3_bucket_name_p}',
      'config_sync_type': '${var.configSync_p}',
      'eni_list': ['mgmt'],
      'mgmt_idx_at': '1',
      'data_idx_at': '0'
      'snet_info': {
          '${var.availability_zones_p}':{
            'mgmt': {'snet_id':'${aws_subnet.mgmt_subnet_r.id}', 'sg':'${aws_security_group.vsrx_sg_mgmt_r.id}', 'idx':'1', 'alloc_eip':'true'}
          }
        }
    }
    EOF
  }
  lifecycle {
    create_before_destroy = true
  }
  metrics_granularity = "1Minute"
  enabled_metrics     = ["GroupMinSize", 
                     "GroupMaxSize", 
                     "GroupDesiredCapacity",
                     "GroupInServiceInstances", 
                     "GroupTerminatingInstances"]

  depends_on  = [aws_lambda_function.vsrx_asg_lambda_r,
                aws_cloudwatch_event_rule.asg_rule_r,
                aws_lb.gwlb_r,
                aws_lb_target_group.gwlb_target_group_r,
                aws_lambda_event_source_mapping.sqs_trigger_r]

tag {
      key                 = "Name"
      value               = "${var.deployment_name_p}-vSRX-ASG"
      propagate_at_launch = true
    }
  
tag {
  key = "AsgDimension"
  propagate_at_launch = true
  value= local.value

}
tag {
      key                 = "GwlbId"
      value               = "${aws_lb.gwlb_r.id}"
      propagate_at_launch = true
    }
tag {
      key                 = "GwlbTg"
      value               = "${aws_lb_target_group.gwlb_target_group_r.arn}"
      propagate_at_launch = true
    }
}

  
resource "aws_cloudwatch_event_rule" "asg_rule_r" {
  name        = "${var.deployment_name_p}-ASG-Rule"
  description = "Event Bridge rule to trigger during the Launch/Terminate"
  event_pattern = <<EOF
  {
    "source" :["aws.autoscaling"],
    "detail-type": [
      "EC2 Instance-launch Lifecycle Action", 
      "EC2 Instance-terminate Lifecycle Action"
    ],
    "detail":  {
      "AutoScalingGroupName": [
        "${var.deployment_name_p}-vSRX-ASG"
      ]
    }
  }
  EOF
  is_enabled = true
  depends_on = [aws_lambda_function.vsrx_asg_lambda_r]
}

resource "aws_cloudwatch_event_target" "event_rule_to_lambda_r" {
  rule      = aws_cloudwatch_event_rule.asg_rule_r.id
  target_id = "${var.deployment_name_p}-vSRX-lambda-target"
  arn       = aws_lambda_function.vsrx_asg_lambda_r.arn
}



resource "aws_cloudwatch_event_rule" "house_keeping_r"{
  count               = local.isLocalConfigC ? 1 : 0
  name                = "${var.deployment_name_p}-Housekeeping-Rule"
  description         = "Housekeeping lambda for local config sync"
  event_bus_name      = "default"
  schedule_expression = "rate(${var.house_keeping_time_p} minutes)"
  is_enabled          = true

}

resource "aws_cloudwatch_event_target" "house_keeping_target_r"{
 count       = local.isLocalConfigC ? 1 : 0 
 rule        = aws_cloudwatch_event_rule.house_keeping_r[0].id
 arn         = aws_lambda_function.vsrx_asg_lambda_r.arn
 retry_policy{
    maximum_event_age_in_seconds = 60
    maximum_retry_attempts = 100 
 }
 input = <<EOF
 {
                "evnt_from": "house_keeping",
                "log_level": "${var.log_level_p}",
                "gwlb_id": "${aws_lb.gwlb_r.id}",
                "gwlb_tg": "${aws_lb_target_group.gwlb_target_group_r.id}",
                "sqs_url": "${aws_sqs_queue.sqs_fifo_queue_r.name}",
                "s3_bucket": "${var.s3_bucket_name_p}",
                "asg_name": "${aws_autoscaling_group.vsrx_asg_r.name}",
                "config_sync_type": "${var.configSync_p}"
  }
EOF

}
resource "aws_lambda_permission" "HouseKeeping"{
  count         = local.isLocalConfigC ? 1 : 0
  function_name = aws_lambda_function.vsrx_asg_lambda_r.function_name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.house_keeping_r[0].arn
}

resource "aws_lambda_permission" "lambda_invoke_permission_r" {
  statement_id  = "InvokeLambdaFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vsrx_asg_lambda_r.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_rule_r.arn
} 

resource "aws_lambda_permission" "lambda_invoke_permission_cloudwatch_r" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vsrx_asg_lambda_r.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_rule_r.arn 
}

resource "aws_lambda_permission" "s3Permission"{
count         = local.isLocalConfigC ? 1 : 0
function_name = aws_lambda_function.vsrx_asg_lambda_r.function_name
action        = "lambda:InvokeFunction"
principal     = "s3.amazonaws.com"
source_arn    = "arn:aws:s3:::${var.s3_bucket_name_p}"
}

resource "aws_cloudformation_stack" "s3_lambda_trigger_r" {
  count         = local.isLocalConfigC ? 1 : 0
  depends_on    = [aws_lambda_permission.s3Permission]
  name          =  "s3-lambda-trigger-${var.deployment_name_p}"                                         
  template_body =<<STACK

{
"Resources" : {

   "ResourceInfo":{
        "Type": "AWS::CloudFormation::CustomResource",
        "Properties": {
          "ServiceToken":"${aws_lambda_function.vsrx_asg_lambda_r.arn}",
          "region": "${var.region}",
          "log_level":"${var.log_level_p}" ,
          "stack_name": "s3-lambda-trigger-${var.deployment_name_p}",
          "cr_type": "s3_notification_trig" ,
          "lambda_arn": "${aws_lambda_function.vsrx_asg_lambda_r.arn}"
          "bucket_name": "${var.s3_bucket_name_p}"
          "prefix": "config/vsrx_config"
          "suffix": ".txt"
          "s3_event_type": "s3:ObjectCreated:*"
          "asg_name": "${aws_autoscaling_group.vsrx_asg_r.name}"
          "sqs_url": "${aws_sqs_queue.sqs_fifo_queue_r.name}"
        }
     }
  }
}
STACK
} 


resource "aws_autoscaling_policy" "TargetTrackingScalingR" {
  count = local.isTargetScalingC ? 1 : 0
  autoscaling_group_name = aws_autoscaling_group.vsrx_asg_r.name
  name                   = "${var.deployment_name_p}-vSRX-asg-policy"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    customized_metric_specification {
           metric_dimension{ 
            name = "AutoScalingGroupName"
            value = aws_autoscaling_group.vsrx_asg_r.id
              }
            metric_name = "DataPlaneCPU1Util"
            namespace = var.cloudwatch_namespace_p
            statistic = "Average"
            }
    disable_scale_in = false
    target_value = var.cpu_threshold_p
  }
}

resource "aws_autoscaling_policy" "ScaleOutAsgR" {
  count = local.isSimpleScalingC ? 1 : 0
  autoscaling_group_name =  aws_autoscaling_group.vsrx_asg_r.name
  name                   = "${var.deployment_name_p}-vSRX-asg-policy-scaleout"
  policy_type            = "SimpleScaling"
  adjustment_type =  "ChangeInCapacity"
  cooldown = "600"
  scaling_adjustment = 1
  }

resource "aws_autoscaling_policy" "ScaleInAsgR" {
  count = local.isSimpleScalingC ? 1 : 0
  autoscaling_group_name =  aws_autoscaling_group.vsrx_asg_r.name
  name                   = "${var.deployment_name_p}-vSRX-asg-policy-scalein"
  policy_type            = "SimpleScaling"
  adjustment_type =  "ChangeInCapacity"
  cooldown = "600"
  scaling_adjustment = -1
  }

resource "aws_cloudwatch_metric_alarm" "ScaleOutAsgAlarmR" {
  count = local.isSimpleScalingC ? 1 : 0
  alarm_name                = "${var.deployment_name_p}-scale-out-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "DataPlaneCPU1Util"
  namespace                 = var.cloudwatch_namespace_p
  period                    = "600"
  statistic                 = "Average"
  threshold                 = var.cpu_threshold_p
  alarm_description         = "Scale out ASG when CPU > ${var.cpu_threshold_p}"
  actions_enabled = "true"
  alarm_actions = [aws_autoscaling_policy.ScaleOutAsgR[0].arn]
  unit = "Percent"
}

resource "aws_cloudwatch_metric_alarm" "ScaleInAsgAlarmR" {
  count = local.isSimpleScalingC ? 1 : 0
  alarm_name                = "${var.deployment_name_p}-scale-in-alarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "DataPlaneCPU1Util"
  namespace                 = var.cloudwatch_namespace_p
  period                    = "1200"
  statistic                 = "Average"
  threshold                 = var.cpu_threshold_p
  alarm_description         = "Scale out ASG when CPU < ${var.cpu_threshold_p}"
  actions_enabled = "true"
  alarm_actions = [aws_autoscaling_policy.ScaleInAsgR[0].arn]
  unit = "Percent"
  treat_missing_data = "missing"
}

resource "aws_lb" "gwlb_r" {
  name                             = "${var.deployment_name_p}vSRX-gwlb"
  load_balancer_type               = "gateway"
  ip_address_type                  = "ipv4"
  enable_cross_zone_load_balancing = true

  subnet_mapping {
    subnet_id = aws_subnet.data_subnet_r.id
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
  target_type          = "instance"
  depends_on           =[aws_lb.gwlb_r]
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

 resource "aws_sqs_queue" "sqs_fifo_queue_r"{
  name                        =  "${var.deployment_name_p}-vSRX-security-vpc.fifo"
  delay_seconds               = 0
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = lookup(var.TimeOut,"value")
  redrive_allow_policy        = jsonencode({redrivePermission = "denyAll" }) 
  tags = {
       key                 = "Name"
       value               = "${var.deployment_name_p}-vSRX-security-vpc.fifo" 
    }
 }

 resource "aws_lambda_event_source_mapping" "sqs_trigger_r"{
  batch_size              = 1
  enabled                 = true
  event_source_arn        = aws_sqs_queue.sqs_fifo_queue_r.arn
  function_name           = aws_lambda_function.vsrx_asg_lambda_r.arn
  function_response_types = ["ReportBatchItemFailures"]
  scaling_config {
    maximum_concurrency = "${var.asg_desired_size_p}"
  }
}


output "gwlb_id" {
  value = aws_lb.gwlb_r.id
}

output "gwlb_service_name" {
  value = aws_vpc_endpoint_service.gwlb_endpoint_service_r.service_name
}
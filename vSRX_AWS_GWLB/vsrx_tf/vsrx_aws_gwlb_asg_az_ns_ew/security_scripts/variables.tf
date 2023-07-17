# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

/*********************** Secret and Access key ************************/
variable "access_key" {
  description = "AWS access key"
  type        = string
}

variable "secret_key" {
  description = "AWS secret key"
  type        = string
}

variable "region" {
  description = "AWS region to deploy the stack"
  type        = string
}
/*********************** VPC Configuration ************************/
variable "deployment_name_p" {
  description = "Deployement name for the vSRX security VPC stack"
  type        = string
}

variable "vpc_cidr_p" {
  description = "CIDR for the vSRX Security VPC"
  type        = string
}

variable "availability_zones_p" {
  description = "AZ to launch vSRX - Needs two AZ's"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"] 
}

variable "mgmt_cidr_az1_p" {
  description = "CIDR for mgmt subnet in AZ-1 for vSRX"
  type        = string
  default     = "10.0.0.0/24"
}

variable "data_cidr_az1_p" {
  description = "CIDR for data subnet in AZ-1 for vSRX"
  type        = string
}

variable "gwlbe_cidr_az1_p" {
  description = "CIDR for gwlbe subnet in AZ-1 for vSRX"
  type        = string
}

variable "tgw_cidr_az1_p" {
  description = "CIDR for tgw subnet in AZ-1 for vSRX"
  type        = string
}

variable "mgmt_cidr_az2_p" {
  description = "CIDR for mgmt subnet in AZ-2 for vSRX"
  type        = string
  default     ="10.0.8.0/24"
}

variable "data_cidr_az2_p" {
  description = "CIDR for data subnet in AZ-2 for vSRX"
  type        = string
}

variable "gwlbe_cidr_az2_p" {
  description = "CIDR for gwlbe subnet in AZ-2 for vSRX"
  type        = string
}

variable "tgw_cidr_az2_p" {
  description = "CIDR for tgw subnet in AZ-2 for vSRX"
  type        = string
}
/*********************** Transit gateway ************************/
variable "tgw_id_p" {
  description = "Transit gateway ID which is in appliance mode"
  type        = string
}

/*********************** vSRX configuration **********************/
variable "vsrx_ami_id_p" {
  description = "AMI-ID for the vSRX for the region"
  type        = string
}

variable "vsrx_key_pair_p" {
  description = "Keypair to manage vSRX"
  type        = string
}

variable "vsrx_host_sg_p" {
  description = "CIDR or Source IP address to whitelist SSH access, the default is 0.0.0.0/0"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vsrx_instance_type_p" {
  description = <<EOF
  "Instance type for vSRX:
  Allowed Values:
  c5.large,
  c5.xlarge,
  c5.2xlarge,
  c5.4xlarge,
  c5n.large,
  c5n.xlarge,
  c5n.2xlarge,
  c5n.4xlarge"
  EOF
  type        = string
  default     = "c5.large"
}

variable "vsrx_disk_vol_p" {
  description = "Instance disk volume size default: 20"
  type        = number
  default     = 20
}

variable "vsrx_gwlb_health_protocol_p" {
  description = <<EOF
  "Health check Protocol to use with GWLB: 
  Allowed Values:
  TCP,
  HTTPS"
  EOF
  type        = string
  default     = "TCP"
}

variable "vsrx_gwlb_health_port_p" {
  description = <<EOF
  "Health check Port to use with GWLB: 
  Allowed Values:
  49160,
  443"
  EOF
  type        = number
  default     = 49160
}

/*********************** S3 bucket information**********************/
variable "s3_bucket_name_p" {
  description = "Preconfigured S3 bucket name which has vsrx_lambda code as zip file"
  type        = string
}

variable "s3_lambda_zip_p" {
  description = "Preconfigured S3 bucket key which points to .zip file example: vsrx_lambda.zip"
  type        = string
  default     = "vsrx_lambda.zip"
}

variable "log_level_p" {
  description = "Log level for lambda function: info/debug"
  type        = string
  default     = "info"
}

/*********************** Autoscaling configuration **********************/
variable "asg_min_size_p" {
  description = "Minimum number of vSRX instance in Autoscaling group"
  type        = number
  default     = 1
}

variable "asg_desired_size_p" {
  description = "Desired number of vSRX instance in Autoscaling group"
  type        = number
  default     = 2
}

variable "asg_max_size_p" {
  description = "Maximum number of vSRX instance in Autoscaling group"
  type        = number
  default     = 4 
}

/*********************** Autoscaling - Scaling policies configuration **********************/
variable "enable_asg_scaling_p" {
  description = "Enable ASG scaling policy"
  type        = bool
  default     = true
}

variable "scaling_type_p" {
  description = "Scaling policy type: simple_scaling/target_scaling"
  type        = string
  default     = "simple_scaling"
}

variable "cloudwatch_namespace_p" {
  description = "Namespace for the cloudagent metric collections"
  type        = string
  default     = "vsrx_gwlb_asg_metric"
}

variable "cpu_threshold_p" {
  description = "Threshold for data cpu utilization"
  type        = number
  default     = 50
}

variable "metric_collect_interval_p" {
  description = "Metric interval time for Cloud agent in Min"
  type        = number
  default     = 1
}

########## Config Sync across ASG mechanism ###########
variable "TimeOut" {
  type = map
  default = {
  "value" = 600
  }
}

variable "configSync_p"{
    description = <<EOF
    "Local Config Sync tracks the vsrx_config.txt in s3bucket config/vsrx_config.txt in the series of set commands,
    Adding a valid set command adds to the vSRX device across ASG, 
    Removing a valid set command removes from the vSRX device across ASG
    AllowedValues:
      - local_config_sync
      - disable"
    EOF
    type       = string
    default    = "local_config_sync"
  }

variable "house_keeping_time_p"{
    description = "Housekeeping Lambda -- Lambda is triggered by a timer to check if the vSRX config is consistent across ASG"
    type        = number
    default     = 30
  }
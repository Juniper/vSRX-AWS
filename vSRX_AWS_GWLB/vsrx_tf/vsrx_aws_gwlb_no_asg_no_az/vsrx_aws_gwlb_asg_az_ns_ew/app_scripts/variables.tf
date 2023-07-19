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
  description = "Deployement name for the vSRX application VPC "
  type        = string
}

variable "vpc_cidr_p" {
  description = "CIDR for the vSRX application VPC"
  type        = string
}

variable "availability_zones_p" {
  description = "AZ to launch vSRX - Needs two AZ's"
  type        = string
  default     = "us-east-1a"
}

variable "public_cidr_p" {
  description = "CIDR for mgmt subnet in AZ-1 for vSRX"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_cidr_p" {
  description = "CIDR for data subnet in AZ-1 for vSRX"
  type        = string
}

variable "gwlbe_cidr_p" {
  description = "CIDR for gwlbe subnet in AZ-1 for vSRX"
  type        = string
}


/*********************** Transit gateway ************************/
variable "tgw_id_p" {
  description = "Transit gateway ID which is in appliance mode"
  type        = string
}

/*********************** vSRX configuration **********************/
variable "ami_id_p" {
  description = "AMI-ID for the vSRX for the region"
  type        = string
}

variable "key_pair_p" {
  description = "Keypair to manage vSRX"
  type        = string
}

variable "host_sg_p" {
  description = "CIDR or Source IP address to whitelist SSH access, the default is 0.0.0.0/0"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type_p" {
  description = "Select instance type"
  type        = string
  default     = "c5.large"
}

variable "GwlbServiceNameP"{
  description = "Enter the service name of the vpce endpoint"
  type = string
}

variable "TgwSecurityAttachmentIdP"{
  description = "Enter the tgw security attachment id"
  type = string
}

variable "TgwSecurityRouteTableIdP"{
  description = "enter the tgw security route table id"
  type = string
}
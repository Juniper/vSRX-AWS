variable "region" {
  default = "us-east-1"
}
variable "primary_region" {}

variable "cf_template" {
  default = "lambda.template"
}
variable "public_key_path" {}

variable "allowed_ssh_ipadd" {
  default = "0.0.0.0/0"
}
variable "enable_term_protection" {
  default = "No"
}
variable "vpc_cidr" {
  default = "10.10.0.0/16"
}
variable "pub_mgmt_subnet_az1" {
  default = "10.10.10.0/24"
}
variable "pub_mgmt_subnet_az2" {
  default = "10.10.20.0/24"
}
variable "pub_data_subnet_az1" {
  default = "10.10.30.0/24"
}
variable "pub_data_subnet_az2" {
  default = "10.10.40.0/24"
}
variable "vsrx_ec2_type" {
  default = "C5.large"
}
variable "ami_name_filter" {
  default = "*srx*18.4R1.8--pm*"
}

variable "preferred_path_tag" {
  default = "transitvpc:preferred-path"
}
variable "vpc_spoke_tag" {
  default = "transitvpc:spoke"
}
variable "vpc_spoke_tag_value" {
  default = "true"
}
variable "bgp_asn" {
  default = "64514"
}
variable "s3_prefix_key_names" {
  default = "vpnconfigs/"
}
variable "accountid" {
  default = ""
}

variable "spoke_vpc1_cidr" {
  default = "10.150.0.0/16"
}

variable "spoke_vpc1_subnet" {
  default = "10.150.2.0/24"
}

variable "spoke_vpc2_cidr" {
  default = "10.160.0.0/16"
}

variable "spoke_vpc2_subnet" {
  default = "10.160.2.0/24"
}

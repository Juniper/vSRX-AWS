#data "aws_region" "current" {}

#terraform {
#  backend "s3" {
#    bucket = "akbhat-transit-gw-solution"
#    key    = "akbhat/tvpc/terraform.tfstate"
#    region = "us-east-1"
#  }
#}

#data "terraform_remote_state" "aws_tvpc_global" {
#  backend = "s3"
#  config {
#    region = "us-east-1"
#    bucket = "akbhat-transit-gw-solution"
#    key = "akbhat/terraform/tvpc/terraform.tfstate"
#  }
#}

module "tvpc-us-east-1" {
  source = "./tvpc"
  primary_region = 1 
  public_key_path = "./akbhat_transit_vsrx.pub"
  cf_template = "lambda.template"
#  region = "${var.primary_region_with_lambdas}" 
  region = "us-east-1"
#  ami_name_filter = "*junos-vsrx3-x86-64-19.1R1.6-std--pm.img"
  ami_name_filter = "*srx*18.4R1.8--pm*"
}

module "tvpc-us-west-2" {
  source = "./tvpc"
  primary_region = 0
  public_key_path = "./akbhat_transit_vsrx.pub"
  region = "us-west-2"
#  ami_name_filter = "*junos-vsrx3-x86-64-19.1R1.6-std--pm.img"
  spoke_vpc1_cidr = "10.170.0.0/16"
  spoke_vpc1_subnet = "10.170.2.0/24"
  spoke_vpc2_cidr = "10.180.0.0/16"
  spoke_vpc2_subnet = "10.180.2.0/24"
}

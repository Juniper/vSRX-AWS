# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

/*##################### MANDATORY #######################*/
access_key           = ""
secret_key           = ""
region               = "us-east-1"
deployment_name_p    = ""
vpc_cidr_p           = "10.128.0.0/16"
availability_zones_p = ""

#Subnets in AZ1
public_cidr_p  = "10.128.1.0/24"
private_cidr_p  = "10.128.2.0/24"
gwlbe_cidr_1_p = "10.128.0.0/24"
gwlbe_cidr_2_p = "10.128.0.0/24"

#Configuration
ami_id_p               = "ami-05fa00d4c63e32376" 
key_pair_p             = ""
host_sg_p              = ""
instance_type_p        = "c5.large"
GwlbServiceNameP       = ""

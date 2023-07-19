# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

/*##################### MANDATORY #######################*/
access_key           = ""
secret_key           = ""
region               = ""
deployment_name_p    = ""
vpc_cidr_p           = "10.0.0.0/16"
#Need two AZ, example - [ "us-east-1a", "us-east-1b" ]
availability_zones_p = []

#Subnets in AZ1
mgmt_cidr_az1_p  = "10.0.0.0/24"
data_cidr_az1_p  = "10.0.2.0/24"
gwlbe_cidr_az1_p = "10.0.3.0/24"
tgw_cidr_az1_p   = "10.0.4.0/24"

#Subnets in AZ2
mgmt_cidr_az2_p  = "10.0.8.0/24"
data_cidr_az2_p  = "10.0.9.0/24"
gwlbe_cidr_az2_p = "10.0.10.0/24"
tgw_cidr_az2_p   = "10.0.12.0/24"

#Transit gateway
tgw_id_p         = ""  

#vSRX Configuration
vsrx_ami_id_p               = "" 
vsrx_key_pair_p             = ""
vsrx_host_sg_p              = ""
vsrx_instance_type_p        = "c5.large"
vsrx_disk_vol_p             = 20
vsrx_gwlb_health_protocol_p = "TCP"
vsrx_gwlb_health_port_p     = 49160

# Preconfigured S3 bucket
s3_bucket_name_p        = ""
s3_lambda_zip_p         = "vsrx_lambda.zip"
log_level_p             = "info"  

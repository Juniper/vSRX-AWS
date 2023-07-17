# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

/*##################### MANDATORY #######################*/
access_key           = ""
secret_key           = ""
region               = ""
deployment_name_p    = ""
vpc_cidr_p           = ""
availability_zones_p = ""
mgmt_cidr_p          = ""
data_cidr_p          = ""


#vSRX Configuration#
vsrx_ami_id_p               = "" 
vsrx_key_pair_p             = ""
vsrx_host_sg_p              = ""
vsrx_instance_type_p        = ""
vsrx_disk_vol_p             = 20
vsrx_gwlb_health_protocol_p = "TCP"
vsrx_gwlb_health_port_p     = 49160

# Preconfigured S3 bucket#
s3_bucket_name_p = ""
s3_lambda_zip_p  = "vsrx_lambda.zip"
log_level_p      = "info"  







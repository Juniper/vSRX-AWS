# Copyright (c) Juniper Networks, Inc., 2023. All rights reserved.

/*##################### MANDATORY #######################*/
access_key          = ""
secret_key          = ""
region              = ""
deployment_name_p   = ""
vpc_cidr_p          = "10.0.0.0/16"
availability_zones_p = ""

/*Subnets in AZ1*/
mgmt_cidr_az1_p = "10.0.0.0/24"
data_cidr_az1_p = "10.0.2.0/24"

/*vSRX Configuration*/
vsrx_ami_id_p               = "" 
vsrx_key_pair_p             = ""
vsrx_host_sg_p              = ""
vsrx_instance_type_p        = "c5.large"
vsrx_disk_vol_p             = 20
vsrx_gwlb_health_protocol_p = "TCP"
vsrx_gwlb_health_port_p     = 49160

/*# Preconfigured S3 bucket*/
s3_bucket_name_p = ""
s3_lambda_zip_p  = "vsrx_lambda.zip"
log_level_p      = "info"  /* # Supported info/debug*/

# Autoscaling configuration
asg_min_size_p            =1 
asg_desired_size_p        =2 
asg_max_size_p            = 4

 # Autoscaling - Scaling policies configuration
enable_asg_scaling_p      = true
scaling_type_p            = "disbale"
metric_collect_interval_p =1
cloudwatch_namespace_p    ="vsrx_gwlb_asg_metric"
cpu_threshold_p           = 50

# Config Sync across ASG mechanism
configSync_p              = "disable"
house_keeping_time_p      = 30
TimeOut                   = {"value"=600}

#!/bin/bash

set -x

prefix=`whoami`
VPC_NAME="${prefix}-vpc-test1"
# Enter your KEY_NAME
KEY_NAME='<your-key-name>'
# Ensure the publickey file downloaded from your AWS account is accessible
KEY_FILE='<your-key-name.pem>'
VPC_CIDR='172.31.0.0/16'
SUBNET_MGT="${prefix}-manage-01"
SUBNET_MGT_CIDR='172.31.10.0/24'
SUBNET_WEB="${prefix}-webtier-01"
SUBNET_WEB_CIDR='172.31.20.0/24'
ROUTE_TABLE_WEB="${prefix}-webtier-rtb"
SUBNET_PUBLIC="${prefix}-public-01"
SUBNET_PUBLIC_CIDR='172.31.30.0/24'
ROUTE_TABLE_PUBLIC="${prefix}-public-rtb"
AVAILABILITY_ZONE='us-east-1a'
INSTANCE_NAME="${prefix}-vsrx-test"
IMAGE_ID='ami-0f0442c45665d343a'
# The saml files have to be created for the VPC and other resources to be created in your account
PROFILE_OPTION='--profile saml'
#VERBOSE_OPTION='--verbose'
USE_EXISTING_VPC='--skip-if-exist'
Topology="
                                    ge-0/0/0           ge-0/0/1
                                        +-----------------+     
 nginx(ECS) +-----+ SUBNET_WEB +--------|       vSRX      |-------+ SUBNET_PUBLIC +--+-- INTERNET
                                        +--------+--------+                          |
                                                 | fxp0                              |
                                                 |                                   |
                                                 +                                   |
                                            SUBNET_MGT +-----------------------------+
"
vpc_id_file="/tmp/$$.vpc.id"
### Creating VPC
### if a VPC with same name is existing , it will do nothing
### Create seperated route table for $SUBNET_WEB and $SUBNET_PUBLIC
./vsrx-aws vpc-create --name "$VPC_NAME" \
     --subnet $SUBNET_MGT_CIDR,name=$SUBNET_MGT,availability_zone=$AVAILABILITY_ZONE  \
     --subnet $SUBNET_WEB_CIDR,name=$SUBNET_WEB,availability_zone=$AVAILABILITY_ZONE,route_table=$ROUTE_TABLE_WEB  \
     --subnet $SUBNET_PUBLIC_CIDR,name=$SUBNET_PUBLIC,availability_zone=$AVAILABILITY_ZONE,route_table=$ROUTE_TABLE_PUBLIC \
     --save-vpc-id $vpc_id_file \
     $PROFILE_OPTION  \
     $VERBOSE_OPTION \
     $USE_EXISTING_VPC \
     "$VPC_CIDR"

instance_id_file="/tmp/$$.vsrx.id"
### Launching a vSRX instance into VPC
### Configure source NAT and policy with Cloud-init (--junos-config-file <config-file>)
### Configure ge-0/0/0 and ge-0/0/1 automatically with the auto-assigned private address (--config-interface)
### Wait until pic is only , the traffic can be forwarded between ge-0/0/0 and ge-0/0/1 (--wait-pic-online)
### Save new instance id to file (--save-instance-id "$instance_id_file")
if [ $? -eq 0 ]
then
    vpc_id="`cat $vpc_id_file`"
    ./vsrx-aws deploy --instance-name "$INSTANCE_NAME" \
                  --key-name "$KEY_NAME" \
                  --key-file "$KEY_FILE" \
                  --vpc-id "$vpc_id" \
                  --nic subnet-name=$SUBNET_MGT,public-ip=auto \
                  --nic subnet-name=$SUBNET_WEB,subnet-gateway=self \
                  --nic subnet-name=$SUBNET_PUBLIC,public-ip=auto \
                  --junos-config-file demo/data/init_src_nat.conf \
                  --config-interface \
                  --wait-fpc-online \
                  --save-instance-id "$instance_id_file" \
                  $PROFILE_OPTION \
                  $VERBOSE_OPTION \
                  $IMAGE_ID
fi

### Start a nginx server inside the $SUBNET_WEB
### This needs to permit internet access of $SUBNET_WEB at first
if [ $? -eq 0 ]
then
    nginx_private_ip="`./demo/tools/nginx_ecs_run.py --vpc-id "$vpc_id" --subnet-name  $SUBNET_WEB $PROFILE_OPTION`"
    echo "nginx task private ip address $nginx_private_ip"
fi

### Configure vSRX Junos with destination NAT and security policy
### Using jinja2 template to set external and internal web server address automatically
if [ $? -eq 0 -a ! -z "$nginx_private_ip" ] 
then
    instance_id="`cat $instance_id_file`"
    ./vsrx-aws junos-config --instance-id "$instance_id" \
                  --key-file "$KEY_FILE" \
                  --jinja2  \
                  --extra-vars "web_server_ip=$nginx_private_ip" \
                  $PROFILE_OPTION \
                  $VERBOSE_OPTION \
                  demo/data/dst_nat_config.j2
fi


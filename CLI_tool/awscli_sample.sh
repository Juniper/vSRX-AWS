#!/bin/bash

set -x

prefix= 'Name'
VPC_NAME="${prefix}-vpc-test1"
# Enter your KEY_NAME
KEY_NAME='key1'
# Ensure the publickey file downloaded from your AWS account is accessible
KEY_FILE='key1.pem'
VPC_CIDR='172.27.0.0/16'
SUBNET_MGT="${prefix}-manage-01"
SUBNET_MGT_CIDR='172.27.10.0/24'
SUBNET_WEB="${prefix}-webtier-01"
SUBNET_WEB_CIDR='172.27.20.0/24'
ROUTE_TABLE_WEB="${prefix}-webtier-rtb"
SUBNET_PUBLIC="${prefix}-public-01"
SUBNET_PUBLIC_CIDR='172.27.30.0/24'
ROUTE_TABLE_PUBLIC="${prefix}-public-rtb"
AVAILABILITY_ZONE='us-east-1a'
INSTANCE_NAME="${prefix}-vsrx-test"
IMAGE_ID='ami-0f0442c45665d343a'
# The saml files have to be created for the VPC and other resources to be created in your account
PROFILE_OPTION='--profile profile_name'
#VERBOSE_OPTION='--verbose'
USE_EXISTING_VPC='--skip-if-exist'
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

vpc_id="`cat $vpc_id_file`"
./vsrx-aws deploy --instance-name "$INSTANCE_NAME" \
	  --key-name "$KEY_NAME" \
	  --key-file "$KEY_FILE" \
	  --vpc-id "$vpc_id" \
	  --nic subnet-name=$SUBNET_MGT,public-ip=auto \
	  --nic subnet-name=$SUBNET_WEB,subnet-gateway=self \
	  --nic subnet-name=$SUBNET_PUBLIC,public-ip=auto \
	  --config-interface \
	  --wait-fpc-online \
	  --save-instance-id "$instance_id_file" \
	  $PROFILE_OPTION \
	  $VERBOSE_OPTION \
	  $IMAGE_ID




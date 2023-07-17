# vSRX Deployement

A CloudFormation template to depoy a vSRX in security VPC along with Gateway Load Balancer without Autoscaling group. This creates most of the resources needed to deploy the vSRX to handle the traffic from the Gateway load balancer. The vSRX is bootstrapped with minimal default config to allow the geneve traffic originating from the GWLB. This topolgy deploys resources in two AZ (User choice of AZ's as input) and creates a VPC attachment with TGW.

This template deploys the following resources

* VPC
* Internet Gateway IGW
* Mgmt subnet
* Data subnet
* Bastion host
* NAT GW
* Route tables
* Add route table entries
* Lambda function
* Gateway Load balancer
* Target group and listener
* Bootstrap vSRX through userData
* VPC attachment with TGW and route tables

# Topology

Refer to [AWS Centralized VPC](https://aws.amazon.com/blogs/networking-and-content-delivery/centralized-inspection-architecture-with-aws-gateway-load-balancer-and-aws-transit-gateway/)

![Alt text](vsrx_aws_gwlb_security_no_asg_az_ns_ew.png?raw=true "Topology")
# vSRX Deployement

A CloudFormation template to depoy a vSRX in security VPC along with Gateway Load Balancer without Autoscaling group. This creates most of the resources needed to deploy the vSRX to handle the traffic from the Gateway load balancer. The vSRX is bootstrapped with minimal default config to allow the geneve traffic originating from the GWLB. This topolgy deploys resources in two AZ's (User choice of AZ's as input). The application VPC can deply the Gateway load balancer endpoint and route traffic to the security VPC by adding the appropriate route entries.

This template deploys the following resources

* VPC
* Internet Gateway IGW
* Mgmt subnets
* Data subnets
* Bastion host
* NAT GW
* Route tables
* Add route table entries
* Lambda function
* Gateway Load balancer
* Target group and listener
* Bootstrap vSRX through userData

# Topology

Security VPC topology

![Alt text](vsrx_aws_gwlb_no_asg_az.png?raw=true "Topology")
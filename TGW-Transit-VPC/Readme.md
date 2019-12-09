AWS Transit GW based TVPC Solution

Installing Terraform

If Terraform 0.11.x is not already installed, use the following instructions:

sudo apt-get install unzip
sudo mkdir /bin/terraform

sudo curl -O https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip
sudo unzip terraform_0.11.13_linux_amd64.zip -d /bin/terraform

export PATH=$PATH:/bin/terraform
Deployment Instructions

Review/override variables in main.tf

DO NOT CHANGE

primary_region = 0
cf_template = "lambda.template"
MAY CHANGE

region = "us-east-1"
ami_name_filter = "*srx*18.4R1.8--pm*"
CHANGE - Provide path to public SSH key

public_key_path = "./akbhat_transit_vsrx.pub"
Initialize Terraform providers:

terraform init
- Found version 1.58.0 of terraform-aws-modules/vpc/aws on registry.terraform.io
- Found version 1.19.0 of terraform-aws-modules/ec2-instance/aws on registry.terraform.io
- Downloading plugin for provider "aws" (2.4.0)...
- Downloading plugin for provider "template" (2.1.0)...

Run Terraform plan to ensure there are no errors:

terraform plan
Deploy the template to AWS:

terraform apply -auto-approve
NOTE: This module provisions two spoke VPCs alongwith EC2 instances, attaches them to the TGW for testing purposes

Destroy all the deployed resources:

terraform destroy

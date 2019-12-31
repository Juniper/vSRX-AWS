About the CLI tool:
-------------------

The tool vsrx-aws aims to be a simple CLI option to deploy the vSRX and other supported solutions such as ELB on AWS. The tool is in its Beta stage and there is no planned effort to address any issues that may be reported. 


PREREQUISITE
--------------

1. Install python pacakges: click boto3 pyyaml tabulate
  # sudo pip install click boto3 pyyaml tabulate

2. Install docker engine 
  https://docs.docker.com/install/

3. Activate SAML credentials. For more info on SAML:
   https://aws.amazon.com/identity/saml/

  For Juniper SSO based SAML tokens:
  https://it-gitlab.junipercloud.net/cloud-platform/aws-samlapi


INSTALLATION STEPS
------------------

Unzip all the contents of the file. If all the packages listed above have been installed, then:

#./vsrx-aws
Usage: vsrx-aws [OPTIONS] COMMAND [ARGS]...

  vsrx-aws is an orchestration tool for automated provisioning, scaling and
  management of vSRX in AWS

Options:
  --help  Show this message and exit.

Commands:
  deploy        Launch a vSRX instance
  images        List vSRX images in AWS marketplace
  junos-config  Load Junos configuration file to vSRX instances
  scaleout      Scale out performance with vSRX cluster and AWS ELB
  stats         Display resource usage statistics of running vSRX instances
  vpc-create    Create a new VPC
  vpc-show      Show VPC parameters
  wait          Wait vSRX fpc online

EXAMPLE
-------

An example command to create a VPC, subnets, route-tables and deploy a vSRX instance with DestNAT is in the file "launch_vsrx_dnat_web_ecs.sh".

Edit the file to update the Key filenames before you execute the shell script.

One such complete execution of the tool is in the success_log.txt file.

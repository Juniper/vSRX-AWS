About the CLI tool:
-------------------

The tool vsrx-aws aims to be a simple CLI option to deploy the vSRX and other supported solutions such as ELB on AWS. 

The tool is in its Beta stage and there is no planned effort to address any issues that may be reported. 


PREREQUISITE
--------------

1. Install python packages: click boto3 pyyaml tabulate
   #sudo pip install click boto3 pyyaml tabulate

2. Install docker engine 
  https://docs.docker.com/install/

3. Activate SAML credentials. For more info on SAML:
   https://aws.amazon.com/identity/saml/

  For Juniper SSO based SAML tokens:
  https://it-gitlab.junipercloud.net/cloud-platform/aws-samlapi
  
  (OR) 
  
   if you have an indvidual account, you need to execute these after installing aws-cli:
 
#aws configure   # you will need to provide your access-key ID and secret-access-key as inputs; set the region and leave the format to json
#aws sts get-session-token –duration-seconds 64000    #enter the duration you want to retain the tokens for
 
  Once done, you will get an output such as:
 
$ aws sts get-session-token --duration-seconds 6000
{
    "Credentials": {
        "AccessKeyId": "AAAAAAH6ET44444444WG",
        "SecretAccessKey": "mcem+B111111111111111111n7VjgitGi+jHefo",
        "SessionToken": "FwoGZXIvYXdzEHIaDHKLw97y4O99UYO85yKBAasdfasdfasdfc69X8y2NUTwPeOElwwCA6dS2+PGjeinVdibTGWE9ON9PAUqb3scUg5YJ74DO8766rpiCRtClDV1Kf7I0NQPQQK3gAvHcVejp6wrQddGgrQfbX0xzPJLAEqbNh8mAtYZKWQhnq5w36L4AtG/NqTkmrTG9TXHkkSji2JXxBTIoU1jeIRXeHFFlRAT08yCzu7kUUsfGf4aXcF14/vjjkuI/oHaUy6cfpQ==",
        "Expiration": "2020-01-20T10:41:22Z"
    }
}
 
Next, you will need to edit ~/.aws/credentials and enter it in the below format:
 
[profile_name]
aws_access_key_id = AAAAAAH6ET44444444WG
aws_secret_access_key = mcem+B1111111111111111n7VjgitGi+jHefo
aws_session_token = FwoGZXIvYXdzEHIaDHKLw97y4O99UYO85yKBAasdfasdfasdfc69X8y2NUTwPeOElwwCA6dS2+PGjeinVdibTGWE9ON9PAUqb3scUg5YJ74DO8766rpiCRtClDV1Kf7I0NQPQQK3gAvHcVejp6wrQddGgrQfbX0xzPJLAEqbNh8mAtYZKWQhnq5w36L4AtG/NqTkmrTG9TXHkkSji2JXxBTIoU1jeIRXeHFFlRAT08yCzu7kUUsfGf4aXcF14/vjjkuI/oHaUy6cfpQ==
aws_security_token = FwoGZXIvYXdzEHIaDHKLw97y4O99UYO85yKBAasdfasdfasdfc69X8y2NUTwPeOElwwCA6dS2+PGjeinVdibTGWE9ON9PAUqb3scUg5YJ74DO8766rpiCRtClDV1Kf7I0NQPQQK3gAvHcVejp6wrQddGgrQfbX0xzPJLAEqbNh8mAtYZKWQhnq5w36L4AtG/NqTkmrTG9TXHkkSji2JXxBTIoU1jeIRXeHFFlRAT08yCzu7kUUsfGf4aXcF14/vjjkuI/oHaUy6cfpQ==
 
  When you execute the shell script or the command to launch vSRX on AWS, remember to set the argument for –profile to “profile_name” from the credentials file.
  
4. You may need to subscribe to the vSRX image at https://aws.amazon.com/marketplace/pp/B01MS9F1O0 for launching the preferred ami-ID


INSTALLATION STEPS
------------------

Unzip all the contents of the file. If all the packages listed above have been installed, then:

#./vsrx-aws
Usage: vsrx-aws [OPTIONS] COMMAND [ARGS]...

  vsrx-aws is an orchestration tool for automated provisioning, scaling and management of vSRX in AWS
  
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

Variables to be defined in the .sh file:

prefix= 'your_name'
KEY_NAME='key1'
KEY_FILE='key1.pem'  <<<need to copy the key to the directory
IMAGE_ID='ami-0f0442c45665d343a'
PROFILE_OPTION='--profile profile_name'. <<< from the .aws/credentials file - use the profile name created in prerequisites

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

An example command to create a VPC, subnets, route-tables and deploy a vSRX instance is in the file awscli_sample.sh




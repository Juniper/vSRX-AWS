# vSRX Deployment with AWS GWLB 

The repository contains the source code for the AWS Cloud formation template and Terraform to create a centralized security VPC with **vSRX** and AWS Gateway load balancer.
This also provides an example application stack along with AWS lambda functions.

## Pre-requisites
Before running the cloud formation template, the following things are needed.

* **Creating S3 bucket** - Creating a dedicated S3 bucket for the vSRX Security VPC which hosts the code for the AWS lambda functions with appropriate object structure and files. S3 bucket is region specific.

* **Upload Lambda Function** - A  lambda code written in Python to handle events from the custom resource, Autoscaling and Local config sync if it's enabled. Provided **vsrx_lambda.zip** is the source code for the AWS Lambda functions.

* **IAM Role** - User with IAM role which allows creating IAM policies and other resources described in the CFT.

* **CFT/Terraform** - Running Cloud Formation Template/Terraform from the below-given topology examples 

## Pre-requisites Steps

* Step 1 - Create a dedicated s3 bucket for the vSRX GWLB deployment
```
aws s3api create-bucket --bucket <bucket_name> --region <region> --object-lock-enabled-for-bucket

aws s3api put-public-access-block \
--bucket <bucket_name>  \
--public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

Example:
---------
aws s3api create-bucket --bucket vsrx-gwlb-bucket  --region us-east-1 --object-lock-enabled-for-bucket

aws s3api put-public-access-block \
    --bucket vsrx-gwlb-bucket \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

```
* Step 2 - Copy **vsrx_lambda.zip** to the root of the created s3 bucket. Please find the **vsrx_lambda.zip** in **vsrx_lambda/vsrx_lambda.zip**

```
aws s3 cp vsrx_lambda.zip s3://<bucket_name>/

Example:
---------
aws s3 cp vsrx_lambda.zip s3://vsrx-gwlb-bucket/

```
* Step 3 - Ensure proper IAM role.

* Step 4 - Run the CFT from one of the below topologies either using the [AWS Console](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-using-console.html) or [AWS CLI](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/create-stack.html).

## Source Code Directory Structure

**vsrx_cft**        : YAML templates for application and security VPC stack. \
**vsrx_tf**         : Terraform Scripts for application and security VPCstack. \
**vsrx_lambda.zip** : vSRX AWS Lambda function source code with dependencies.

```
.
├── vsrx_cft
│   ├── vsrx_aws_gwlb_asg_az
│   ├── vsrx_aws_gwlb_asg_az_ns_ew
│   ├── vsrx_aws_gwlb_asg_no_az
│   ├── vsrx_aws_gwlb_no_asg_az
│   ├── vsrx_aws_gwlb_no_asg_az_ns_ew
│   └── vsrx_aws_gwlb_no_asg_no_az
└── vsrx_tf
    ├── vsrx_aws_gwlb_asg_az_ns_ew
    │   ├── app_scripts
    │   └── security_scripts
    ├── vsrx_aws_gwlb_asg_no_az
    │   ├── app_scripts
    │   └── security_scripts
    ├── vsrx_aws_gwlb_no_asg_az_ns_ew
    │   ├── app_scripts
    │   └── security_scripts
    └── vsrx_aws_gwlb_no_asg_no_az
        ├── app_scripts
        └── security_scripts
└── vsrx_lambda.zip
```

## Cloud Formation Topologies

### Subdirectory Structure
Example
```
.
├── README.md
├── vsrx_aws_gwlb_app_asg_az_ns_ew.yaml  (Application VPC stack is tagged with _app_)
├── vsrx_aws_gwlb_security_asg_az_ns_ew.png
└── vsrx_aws_gwlb_security_asg_az_ns_ew.yaml (Security VPC stack is tagged with _security_)
```
An example CFT template to launch vSRX with GWLB in single, multi-AZ along with/without autoscaling group.

- Security VPC with a single vSRX  deployed in a single Availability Zone (AZ) - **vsrx_cft/vsrx_aws_gwlb_no_asg_no_az**
- Security VPC with a two vSRX and deployed in multi Availability Zone (AZ) - **vsrx_cft/vsrx_aws_gwlb_no_asg_az**
- Security VPC with vSRX along with ASG in a single Availability Zone (AZ) - **vsrx_cft/vsrx_aws_gwlb_asg_no_az**
- Security VPC with vSRX along with ASG in multi Availability Zone (AZ) - **vsrx_cft/srx_aws_gwlb_asg_az**
- Security VPC with vSRX along with ASG, and TGW, for North-South and East-west traffic inspection - **vsrx_cft/vsrx_aws_gwlb_asg_az_ns_ew**
- Security VPC with vSRX without Autoscaling group, and TGW, for North-South and East-west traffic inspection - **vsrx_cft/vsrx_aws_gwlb_no_asg_az_ns_ew**


## Terraform Topologies

An example Terraform scripts to launch vSRX with GWLB in single, multi-AZ along with/without autoscaling group.

### Folder structure:
```
vsrx_tf
    ├── app_scripts (Terraform Scripts for application VPC stack)
    └── security_scripts  (Terraform Scripts for security VPC stack)
```
    
- Security VPC with a single vSRX  deployed in a single Availability Zone (AZ) - **vsrx_tf/vsrx_aws_gwlb_no_asg_no_az**
- Security VPC with vSRX along with ASG in a single Availability Zone (AZ) - **vsrx_tf/vsrx_aws_gwlb_asg_no_az**
- Security VPC with vSRX along with ASG, and TGW, for North-South and East-west traffic inspection - **vsrx_tf/vsrx_aws_gwlb_asg_az_ns_ew**
- Security VPC with vSRX without Autoscaling group, and TGW, for North-South and East-west traffic inspection - **vsrx_tf/vsrx_aws_gwlb_no_asg_az_ns_ew**

## Local config Sync

A local Asynchronous config sync is implemented using the lambda function to keep the vSRX config behind the Autoscaling group in sync. Apart from the user data, to add additional vSRX configs/policies when the instance is created by the ASG, or if there are incremental changes that need to be pushed after vSRX is up and running follow the below steps:

The vSRX config can be pushed when 
- 
- Create a folder or object folder config in the s3 bucket created earlier by running

```
aws s3api put-object --bucket <bucket_name> --key config/

Example:
---------
aws s3api put-object --bucket vsrx-gwlb-bucket --key config/
```

- Create **vsrx_config.txt** file and add vSRX config as the series of set commands for an example
```
set system syslog file mylog structured-data
set security cloud aws cloudwatch log group vsrx_test_log_grp
set security cloud aws cloudwatch log file mylog security-hub-import
set security cloud aws cloudwatch log file mylog collect-interval 1
```

- Copy the **vsrx_config.txt** to the **config/** object folder. 
```
aws s3 <path to local vsrx_config.txt> s3://<bucket_name>/config/vsrx_config.txt

Example:
---------
aws s3 cp vsrx_config.txt s3://vsrx-gwlb-bucket/config/vsrx_config.txt
```
- Create **init-config.json** file with the below key/value pair.
```

Options: 

ssh_param_name: "The parameter name of the vSRX private ssh keys in the AWS param store as the secured string"
    type: MANDATORY
    

"log_level":  Change the lambda log level.
    type: OPTIONAL
    Options: info/debug/none
    Defaults: info

"module_log_level": Change the lambda-dependent module log level.
    type: OPTIONAL
    Options: info/debug/none
    Defaults: info

 "permission" : Permission for lambda function to send set/delete commands.
    type: OPTIONAL (LIST)
    Options: ["ENABLE_DELETE", "DISABLE_DELETE","ENABLE_SET", "DISABLE_SET"]
    Defaults: DISABLE_DELETE, ENABLE_SET

"concurrency": Propagation time to push config parallelly for all vSRX behind ASG.
    type: OPTIONAL
    Options: enable/disable
    Defaults: disable
""

Example:
---------
{
    "ssh_param_name": "vsrx_ssh_private_key",
    "log_level"  : "debug",
    "cmd_info": "disable",
    "module_log_level": "none",
    "permission" : ["ENABLE_DELETE"],
    "concurrency": "enable"
}

```
SSH keys as a secure string in [AWS param store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)

- Copy **init-config.json** to the config/ object folder. 
```
aws s3 <path to local init-config.json> s3://<bucket_name>/config/init-config.json

Example:
---------
aws s3 cp init-config.json s3://vsrx-gwlb-bucket/config/init-config.json
```

-  Enabling the local_config_sync template is required, this creates additional resources in the VPC stack such as:
    - S3 event trigger created by a custom resource.
    - S3 bucket gets tagged with the Autoscaling group name and the SQS queue and retrieved when the AWS Lambda function is triggered by the S3 event.
    - S3 permission to invoke AWS Lambda. 
    - Housekeeping event rule that triggers lambda every x minutes to ensure the config is in sync. 
    - Housekeeping permission to invoke AWS Lambda.

#### ASG Create

when the ASG creates a new vSRX instance, it calls the AWS Lambda function to handle the Lifecycle hook, it adds an async message to the AWS SQS FIFO queue to indicate the newly launched vSRX needs some additional configs and it looks for the vsrx_config.txt under <s3_bucket>/config/vsrx_config.txt

#### Incremental Updates - ADD
if the additional config is needed after the vSRX is up and running. The additional commands in the series of set commands can be appended to the vsrx_config.txt and copied from the local vsrx_config.txt to the <s3_bucket>/config/vsrx_config.txt. This creates an event and notifies the AWS Lambda function about the config resync is needed and pushes the newly added set commands to all available vSRX.

Initially, on day 1, the configs in **vsrx_config.txt** were:

```
set system syslog file mylog structured-data
set security cloud aws cloudwatch log group vsrx_test_log_grp
set security cloud aws cloudwatch log file mylog security-hub-import
set security cloud aws cloudwatch log file mylog collect-interval 1
```

on day 2, if the additional configs are needed, for example `set security cloud traceoptions file cloudagent.log` append to the **vsrx_config.txt**
```
set system syslog file mylog structured-data
set security cloud aws cloudwatch log group vsrx_test_log_grp
set security cloud aws cloudwatch log file mylog security-hub-import
set security cloud aws cloudwatch log file mylog collect-interval 1

set security cloud traceoptions file cloudagent.log
```

#### Incremental Updates - DELETE

if config needs to be removed for example `set security cloud traceoptions file cloudagent.log`, remove it from the vsrx_config.txt either by removing the entire line or commenting the line with #.

```
set system syslog file mylog structured-data
set security cloud aws cloudwatch log group vsrx_test_log_grp
set security cloud aws cloudwatch log file mylog security-hub-import
set security cloud aws cloudwatch log file mylog collect-interval 1
set security cloud traceoptions file cloudagent.log
```

option 1:
```
set system syslog file mylog structured-data
set security cloud aws cloudwatch log group vsrx_test_log_grp
set security cloud aws cloudwatch log file mylog security-hub-import
set security cloud aws cloudwatch log file mylog collect-interval 1

#set security cloud traceoptions file cloudagent.log
```

option 2:
```
set system syslog file mylog structured-data
set security cloud aws cloudwatch log group vsrx_test_log_grp
set security cloud aws cloudwatch log file mylog security-hub-import
set security cloud aws cloudwatch log file mylog collect-interval 1

```

### Caveats 

- **vsrx_config.txt** acts as a centralized config file which dictates what additional configs that are common to all the vSRX behind the ASG.
- Best effort config sync implementation, if there are errors in the config file, the config is not pushed. The AWS Lambda performs the commit_check before committing.
- The set commands are case-sensitive.

### Resources

The following resources are used for the local config sync

- AWS FIFO SQS queue
- S3 event notification trigger
- HouseKeeping rule
- S3 permission to invoke lambda
- Housekeeping rule  permission to invoke lambda

# AWS Lambda Function

vSRX AWS Lambda function is python based code needed to deploy the centralized vSRX security VPC. The AWS lambda function handles the following.

* events trigerred by the AWS custom resources (AWS::CloudFormation::CustomResource).
* events trigerred by the AWS event bridge rule during the Autoscaling events such as during instance creation and termination.
* events trigerred from the AWS SQS FIFO queue for the local config sync mechanism if its enabled.

## Creating package
Please use the `vsrx_lambda.zip` provided for the lambda functions packages along with its dependencies to create the centralized security vSRX VPC.

In anycase, if you need to add additional dependency or enhance the lambda function according to your needs, please follow the below steps. **vsrx_lambda.zip** has dependencies on `cfnresponse, ncclient and junos-eznc`. Some of the internal dependencies such as lxml is environment specific, suggestion is to use the Linux EC2 AMI on AWS to download the dependencies.

Steps to add additional dependencies

- Launch AWS EC2 Linux instance AMI on AWS, and install Python3.9
- Install Python3.9
    ```
    sudo yum install gcc openssl-devel bzip2-devel libffi-devel
    cd /opt 
    wget https://www.python.org/ftp/python/3.9.16/Python-3.9.16.tgz
    sudo tar xzf Python-3.9.16.tgz
    cd Python-3.9.16
    sudo ./configure --enable-optimizations
    sudo make altinstall
    sudo rm -f /opt/Python-3.9.16.tgz
    python3.9 -V
    ```
- create requirements.txt with the below package information and if any addtional python module is required
    ```
    cfnresponse
    ncclient
    junos-eznc
    ```
- Install the dependencies by running
```
    /usr/local/bin/python3.9 -m pip install --upgrade pip pip3.9 install --target ./package -r requirements.txt --upgrade --use-pep517
```

- Change directory to package
```
    cd package
```

- zip all files recursively
    ```
    zip -r ../vsrx_lambda.zip .
    ```

- Adding all vsrx_*.py files to vsrx_lambda.zip + any additional files
```
    zip -g vsrx_lambda.zip vsrx_s3.py vsrx_async_step.py vsrx_aws.py vsrx_asg.py vsrx_cr.py vsrx_lambda.py vsrx_async_common.py vsrx_async_utils.py vsrx_async.py vsrx_force_sync.py vsrx_housekeeping.py
```

- Copy the vsrx_lambda.zip file to the S3 bucket either through AWS console or through aws cli
```
    aws s3 cp vsrx_lambda.zip s3://<s3_bucket_name>

    Example:
    ---------
    aws s3 cp vsrx_lambda.zip s3://vsrx-gwlb-bucket
```
- Update Lambda function, this required only if the code is modified after the lambda function is created.

    ```
    aws lambda update-function-code --function-name <lambda_function_name> --s3-bucket <s3_bucket_name> --s3-key <vsrx_lambda>.zip
    ```
Follow the below steps to add a spoke VPC from another account to the account that contains your Transit VPC:

1)   Download the template in this page to your local machine.
2)    Do the following changes in your primary account:

a)     Navigate to your S3 bucket (in which your vpcconfigs folder resides). Click on the permission tab, grant permission to the other AWS account via the canonical user ID (this step may not be   needed if you complete all the following steps but it’s still recommended)

b)      Under Permissions choose bucket policy.

c)    Add a new line for each additional AWS account:
 
{
"Version": "2008-10-17",
"Statement": [
      {
      "Effect": "Allow",
      "Principal": {
         "AWS": [
            "arn:aws:iam::<account-1-ID>:root"
            ]
        },
       "Action": [
             "s3:GetObject",
             "s3:PutObject",
             "s3:PutObjectAcl"
           ],
       "Resource": "arn:aws:s3:::<S3 bucket name>/<bucket prefix>/*"
        }
    ]
}
 

d)  Go to the AWS Identity and Access Management (IAM) console, and in the left navigation pane, choose Encryption Keys.


e)   Choose the encryption key for this solution (You will see “Transit VPC” in the key description), and in the Key Policy section, choose Switch to policy view

f)    In the list of roles allowed to use the master key, add a new line (shown in bold font in the following code block) for each additional account ID:
 
{      
    "Sid": "Allow use of the key",
    "Effect": "Allow",
    "Principal": {
        "AWS": [
          "arn:aws:iam:: <transit-vpc-primary-account-id>:role/TransitVPC-TransitVpcPollerRole-[cloudformation-id]",
          "arn:aws:iam:: <transit-vpc-primary-account-id>:role/TransitVPC-CiscoConfigFunctionRole-[cloudformation-id]",
          "arn:aws:iam:: <transit-vpc-primary-account-id>:role/TransitVPC-LambdaLoaderRole-[cloudformation-id]",
          "arn:aws:iam::<account-1-id>:root"
        ]
},
            
3)    Create a CloudFormation stack (from the template downloaded in step 1) in your second account (from which you would like to connect Spoke VPCs). Make sure to fill in the “bucket name” field with the name of the bucket that was created when you first created the transit VPC solution in the primary account.
4)    Tag the spoke VPC that needs to be connected with the appropriate key/value (same as the one that you used in your primary account)

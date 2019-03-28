import boto3
import botocore
import json
from botocore.vendored import requests
from datetime import datetime

ec2_client = boto3.client('ec2')
asg_client = boto3.client('autoscaling')


 
def lambda_handler(event, context):
    subnet_tags = ["untrust", "trust"]
    if trigger_check(event, context):
        return

    AutoScalingGroupName=event['detail']['AutoScalingGroupName']
    instance_id = event['detail']['EC2InstanceId']
    
    if event["detail-type"] == "EC2 Instance-launch Lifecycle Action":
        LifecycleHookName=event['detail']['LifecycleHookName']
        for i in range(len(subnet_tags)):
            if not attach_interface_per_subnet(instance_id, subnet_tags[i], i + 1):
                complete_lifecycle_action_failure(LifecycleHookName, AutoScalingGroupName, instance_id)
                return
        disable_instance_mac_check(instance_id)
        complete_lifecycle_action_success(LifecycleHookName, AutoScalingGroupName, instance_id)
        
    elif event["detail-type"] == "EC2 Instance Terminate Successful":
        pass


def trigger_check(event, context):
    update_trigger = False
    if 'RequestType' in event:
        if event['RequestType'] == 'Create':
            desired_num_instances = int(event["ResourceProperties"]["DesiredInstances"])
            AutoScalingGroupName = event["ResourceProperties"]["AutoScalingGroupName"]
            update_asg = asg_client.set_desired_capacity(AutoScalingGroupName=AutoScalingGroupName,\
                                                        DesiredCapacity=desired_num_instances)
        response("SUCCESS", event, context)
        update_trigger = True

    return update_trigger

def response(status, event, context):
    request_body = {
        "Status": status,
        "PhysicalResourceId" : context.log_stream_name,
        "StackId" : event["StackId"],
        "RequestId" : event["RequestId"],
        "LogicalResourceId" : event["LogicalResourceId"],
        "Data" : {}
    }
    response = requests.put(event["ResponseURL"], data=json.dumps(request_body))
        
    
def attach_interface_per_subnet(instance_id, subnet, index):
    subnet_id = get_subnet_id(instance_id, subnet)
    interface_id = create_interface(subnet_id)
    if not interface_id:
        log("Interface create failure for Instance {}".format(instance_id))
        return False
    attachment = attach_interface(interface_id, instance_id, index)
    if not attachment:
        log("Interface {} attach failure for instance {}".format(interface_id, instance_id))
        delete_interface(interface_id)
        return False
    return True
       
        
def get_subnet_id(instance_id, subnet):
    subnet_id = None
    try:
        result = ec2_client.describe_instances(InstanceIds=[instance_id])
        for tag in result['Reservations'][0]['Instances'][0]['Tags']:
            if tag['Key'] == subnet:
                subnet_id = tag['Value']
                log("Subnet id: {}".format(subnet_id))
    except botocore.exceptions.ClientError as e:
        log("Error describing the instance {}: {}".format(instance_id, e.response['Error']))
        subnet_id = None

    return subnet_id
'''
def get_interface_id(instance_id, index):
    network_interface_id = None
    try:
        result = ec2_client.describe_instances(InstanceIds=[instance_id])
        network_interface_id = result['Reservations'][0]['Instances'][0]['NetworkInterfaces'][index]['NetworkInterfaceId']
        log("NetworkInterface id: {}".format(network_interface_id))
    except botocore.exceptions.ClientError as e:
        log("Error describing the instance {}: {}".format(instance_id, e.response['Error']))

    return network_interface_id
'''

def create_interface(subnet_id):
    network_interface_id = None
    if subnet_id:
        try:
            network_interface = ec2_client.create_network_interface(SubnetId=subnet_id)
            network_interface_id = network_interface['NetworkInterface']['NetworkInterfaceId']

            log("Created network interface: {}".format(network_interface_id))
        except botocore.exceptions.ClientError as e:
            log("Error creating network interface: {}".format(e.response['Error']))

    return network_interface_id


def attach_interface(network_interface_id, instance_id, index):
    attachment = None

    if network_interface_id and instance_id:
        try:
            attach_interface = ec2_client.attach_network_interface(
                NetworkInterfaceId=network_interface_id,
                InstanceId=instance_id,
                DeviceIndex=index
            )
            attachment = attach_interface['AttachmentId']
            
            ec2_client.modify_network_interface_attribute(NetworkInterfaceId=network_interface_id,
                                                          Attachment={
                                                            'AttachmentId': attachment,
                                                            'DeleteOnTermination': True
                                                          }
                                                         )
            log("Created network attachment: {}".format(attachment))
        except botocore.exceptions.ClientError as e:
            log("Error attaching network interface: {}".format(e.response['Error']))
            attachment = None

    return attachment

def disable_instance_mac_check(instance_id):
    operation = False
    try:
        result = ec2_client.describe_instances(InstanceIds=[instance_id])
        for interface in result['Reservations'][0]['Instances'][0]['NetworkInterfaces']:
            if interface['SourceDestCheck'] == True:
                network_interface_id = interface['NetworkInterfaceId']
                ec2_client.modify_network_interface_attribute(NetworkInterfaceId=network_interface_id,
                                                              SourceDestCheck={
                                                                'Value': False
                                                                }
                                                             )
                log("Disable interface source and destination mac address check for nic: {}".format(network_interface_id))
                operation = True

    except botocore.exceptions.ClientError as e:
        log("Error disabling the interface mac address check {}: {}".format(instance_id, e.response['Error']))

    return operation




def delete_interface(network_interface_id):
    
    try:
        ec2_client.delete_network_interface(
            NetworkInterfaceId=network_interface_id
        )
        log("Deleted network interface: {}".format(network_interface_id))
    except botocore.exceptions.ClientError as e:
        log("Error deleting interface {}: {}".format(network_interface_id, e.response['Error']))
        return False
    return True
        
def complete_lifecycle_action_success(hookname,groupname,instance_id):
    try:
        asg_client.complete_lifecycle_action(
                LifecycleHookName=hookname,
                AutoScalingGroupName=groupname,
                InstanceId=instance_id,
                LifecycleActionResult='CONTINUE'
            )
        log("Lifecycle hook CONTINUEd for: {}".format(instance_id))
    except botocore.exceptions.ClientError as e:
        log("Error completing life cycle hook for instance {}: {}".format(instance_id, e.response['Error']))
                
            
def complete_lifecycle_action_failure(hookname,groupname,instance_id):
    try:
        asg_client.complete_lifecycle_action(
                LifecycleHookName=hookname,
                AutoScalingGroupName=groupname,
                InstanceId=instance_id,
                LifecycleActionResult='ABANDON'
            )
        log("Lifecycle hook ABANDONed for: {}".format(instance_id))
    except botocore.exceptions.ClientError as e:
        log("Error completing life cycle hook for instance {}: {}".format(instance_id, e.response['Error']))
            
    

def log(log_str):
    print('{}Z {}'.format(datetime.utcnow().isoformat(), log_str))

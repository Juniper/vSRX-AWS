import json
import boto3
import logging


logger = logging.getLogger()
logger.setLevel(logging.INFO)

AWS_ACCESS_KEY = '' 
AWS_SECRET_KEY = ''
AWS_REGION = '' #e.g. cn-northwest-1

#intance id and interface id e.g.{'id':'i-05b8bcda0f9e6aeee','server_interface':'eni-0937ac3ddbc376502'}
VSRX1 = {'id':'','server_interface':''}  
VSRX2 = {'id':'','server_interface':''}


ROUTE_TABLE_ID = '' #e.g. rtb-04baa74a820c42f10
ROUTE_DEST = '' #e.g. 192.167.102.0/24

def get_new_internal_gateway(failed_instance_id):
    logger.info("Getting internal interface of new vSRX...")
    logger.info("Fail node: '{}'".format(failed_instance_id))
    if failed_instance_id == VSRX1['id']:
        logger.info("Internal interface ID: '{}'".format(VSRX2['server_interface']))
        return VSRX2['server_interface']
    elif failed_instance_id == VSRX2['id']:
        logger.info("Internal interface ID: '{}'".format(VSRX1['server_interface']))
        return VSRX1['server_interface']
    else:
        logger.warn("No matched instance ID")
        return False

def update_route(route_table_id, destination_cidr, eni):
    try:
        ec2 = boto3.resource(
            'ec2',
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY,
            region_name=AWS_REGION
        )
        route_resource = ec2.Route(route_table_id, destination_cidr)
    except:
        logger.exception("Could not get route resource for Route '{}' in Route Table '{}'".format(
            destination_cidr,
            route_table_id
        ))
        return False

    logger.info("Updating Route '{}' for Route Table '{}'...".format(
        destination_cidr,
        route_table_id
    ))
    try:
        route_resource.replace(
            DryRun=False,
            NetworkInterfaceId=eni
        )
    except:
        logger.exception("Could not update Route '{}' for Route Table '{}'...".format(
            destination_cidr,
            route_table_id
        ))
        return False
    logger.info("Route '{}' for Route Table '{}' updated".format(
        destination_cidr,
        route_table_id
    ))
    return True


def lambda_handler(event, context):
    logger.info("Starting Script...")
    eni = get_new_internal_gateway(event['detail']['instance-id'])
    success = update_route(
        route_table_id=ROUTE_TABLE_ID,
        destination_cidr=ROUTE_DEST,
        eni=eni
    )

    if success is True:
        complete_message = "successfully updated."
        logger.info(complete_message)
    else:
        complete_message = "Failed to update."
        logger.warn(complete_message)

    return {
        "CompleteMessage": complete_message
    }

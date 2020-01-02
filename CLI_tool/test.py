import os
import sys
import boto3
import json
from util import *

def vpc_attach_internet_gateway(session, vpc_id):
    info_msg('Checking if there is internet gateway in VPC(%s)' % vpc_id)
    ec2 = session.resource('ec2')
    vpc = ec2.Vpc(vpc_id)
    igws = vpc.internet_gateways.all()
    for igw in igws:
        info_msg('There is already internet gateway attached')
        return igw.internet_gateway_id
    igw = ec2.create_internet_gateway()
    info_msg('Created internet gateway , id = %s' % igw.internet_gateway_id)
    vpc.attach_internet_gateway(InternetGatewayId = igw.internet_gateway_id)
    info_msg('Attached internet gateway(%s) to VPC(%s)' % \
                  (igw.internet_gateway_id, vpc_id))
    return igw.internet_gateway_id

def get_route_table_by_subnet(session, subnet_id):
    client = session.client('ec2')
    filters = [
        {
            'Name': 'association.subnet-id',
            'Values': [
                subnet_id
            ]
        }
    ]
    response = client.describe_route_tables(Filters = filters)
    debug_msg('response describe_route_tables: %s' % json.dumps(response))
    if len(response['RouteTables']) > 0:
        return response['RouteTables'][0]['Associations'][0]['RouteTableId']
    else:
        debug_msg('No explict associated route table')
        subnet = ec2.Subnet(subnet_id)
        vpc = ec2.Vpc(subnet.vpc_id)
        for rtb in vpc.route_tables.all():
            for assoc in rtb.associations_attribute:
                if assoc['Main']:
                    debug_msg('main route table %s' % rtb.route_table_id)
                    return rtb.route_table_id
    return None

def create_route(session, rtb_id, cidr, gw_id):
    ec2 = session.resource('ec2')
    route_table = ec2.RouteTable(rtb_id)
    info_msg('Creating route rtb_id %s, CIDR %s, gw_id %s' % (rtb_id, cidr, gw_id))
    route_table.create_route(DestinationCidrBlock=cidr, GatewayId=gw_id)

enable_verbose_mode()
session = boto3.Session(profile_name='saml')
client = session.client('ec2')
ec2 = session.resource('ec2')
igw_id = vpc_attach_internet_gateway(session, 'vpc-05b2c027f5c52bcb3')
rtb_id = get_route_table_by_subnet(session, 'subnet-0abd82c8743026a36')
create_route(session, rtb_id, '0.0.0.0/0', igw_id)
rtb_id = get_route_table_by_subnet(session, 'subnet-02d25007e2d220ca7')
create_route(session, rtb_id, '0.0.0.0/0', igw_id)



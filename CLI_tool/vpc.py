import sys 
import os
import boto3
import click
import json
import datetime
import time
import traceback
from util import *
from tabulate import tabulate
from botocore.exceptions import ClientError
from botocore.exceptions import NoCredentialsError

def get_name_by_tags(tags, max_len):
    for tag in tags:
        if tag['Key'] == 'Name':
            name = tag['Value']
            return name[:max_len] + (name[max_len:] and '..')
    return ""

def show_vpc_parameters(session, id_list, 
                show_state, show_subnet_name, show_route_table):
    ec2 = session.resource('ec2')
    table = []
    head_row = ['VPC_ID', 'VPC_NAME', 'CIDR', 'SUBNETS','SEC_GROUPS']
    if show_route_table:
        head_row.append('ROUTE_TABLE')
    if show_state:
        head_row.append('STATE')
    table.append(head_row)
    for vpc_id in id_list:
        try:
            vpc = ec2.Vpc(vpc_id)
        except:
            error_msg(traceback.format_exc())
            sys.exit(1)
        vpc_name = get_name_by_tags(vpc.tags, 16)
        vpc_cidr = vpc.cidr_block
        vpc_state = vpc.state
        vpc_subnets = get_vpc_subnets_str(vpc, show_subnet_name)
        vpc_groups = get_vpc_group_str(vpc)
        row = [vpc_id, vpc_name, vpc_cidr, vpc_subnets, vpc_groups]
        if show_route_table:
            vpc_route_tables = get_route_table_str(vpc)
            row.append(vpc_route_tables)
        if show_state:
            row.append(vpc_state)
        table.append(row)
    print(tabulate(table, headers="firstrow",  tablefmt="grid"))

def get_vpc_subnets_str(vpc, show_subnet_name):
    result = ''
    for subnet in vpc.subnets.all():
        if show_subnet_name:
            name_str = '(%s)' % get_name_by_tags(subnet.tags, 20)
        else:
            name_str = ''
        subnet_str = '%s%s,%s,%s\n' % \
             (subnet.id, name_str, subnet.cidr_block, subnet.availability_zone)
        result += subnet_str
    return result

def get_route_table_str(vpc):
    result = ''
    for rt in vpc.route_tables.all():
        name_str = '(%s)' % get_name_by_tags(rt.tags, 16)
        route_table_str = '%s%s\n' % \
             (rt.route_table_id, name_str)
        result += route_table_str
    return result

def get_vpc_group_str(vpc):
    result = ''
    for group in vpc.security_groups.all():
        group_name = group.group_name
        short_name = group_name[:22] + (group_name[22:] and '..')
        group_str = '%s(%s)\n' % \
             (group.group_id, short_name)
        result += group_str
    return result

def parse_vpc_subnets(subnets_conf):
    subnets = []
    for subnet_conf in subnets_conf:
        subnet = {}
        config_items = subnet_conf.split(',')
        if len(config_items) > 0 :
            subnet['cidr'] = config_items.pop(0)
        else:
            error_msg('Need to specify subnet CIDR block')
            sys.exit(1)
        for config_item in config_items:
            option = config_item.split('=')
            if len(option) != 2:
                error_msg('Invalid subnet option %s in configuration %s' \
                    % (config_item, subnet_conf))
                sys.exit(1)
            option_name = option[0].strip()
            option_value = option[1].strip()
            if option_name != 'name' and \
               option_name != 'route_table' and \
               option_name != 'availability_zone':
                error_msg('Unknown option name "%s" in subnet configuration %s' \
                    % (option_name, subnet_conf))
                sys.exit(1)
            subnet[option_name] = option_value
        subnets.append(subnet)
    return subnets

def write_vpc_id(vpc_id, output_file):
    info_msg('Saving vpc_id(%s) to %s' % (vpc_id, output_file))
    with open(output_file, 'w') as outfile:
        outfile.write('%s' % vpc_id)

@click.command()
@click.option('--name', is_flag=True, help='Show VPC by name instead of ID')
@click.option('--show-state', is_flag=True, help='Show VPC state')
@click.option('--show-subnet-name', is_flag=True, help='Show name of subnet')
@click.option('--show-route-table', is_flag=True, help='Show route table in VPC')
@click.option('-v', '--verbose', is_flag=True, help='Enable verbose mode to get more information')
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
@click.argument('VPC-ID')
def vpc_show(vpc_id, name, show_state, show_subnet_name, show_route_table, \
             verbose, profile, region):
    """Show VPC parameters"""
    if verbose:
        enable_verbose_mode()
    session = boto3.Session(profile_name=profile, region_name=region)
    ec2 = session.resource('ec2')
    vpc_ids = []
    if name != True:
        vpc_ids = []
        vpc_ids.append(vpc_id)
    else:
        vpc_name = vpc_id
        vpc_ids = vpc_name_to_ids(session, vpc_name)
    show_vpc_parameters(session, vpc_ids, show_state, show_subnet_name, show_route_table)

@click.command()
@click.option('--name', help='VPC name')
@click.option('--subnet', multiple=True, help='Add a subnet to the VPC')
@click.option('--skip-if-exist', is_flag=True, help='Skip creating VPC if another VPC has the same name')
@click.option('-v', '--verbose', is_flag=True, help='Enable verbose mode to get more information')
@click.option('--save-vpc-id', type=click.Path(), help='Save VP ID to the file')
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
@click.argument('CIDR-BLOCK')
def vpc_create(cidr_block, name, subnet, skip_if_exist, verbose, save_vpc_id, profile, region):
    """Create a new VPC"""
    if verbose:
        enable_verbose_mode()
    subnet_conf_list = parse_vpc_subnets(subnet)
    session = boto3.Session(profile_name=profile, region_name=region)
    ec2 = session.resource('ec2')
    if skip_if_exist and name != None:
        info_msg('Checking if there is VPC with the same name')
        existing_vpcs = vpc_name_to_ids(session, name)
        if len(existing_vpcs) > 0:
            info_msg('Existing VPC(s): %s' % json.dumps(existing_vpcs))
            info_msg('Skip create new VPC')
            return 0
    vpc = ec2.create_vpc(CidrBlock=cidr_block)
    if name != None:
        vpc.create_tags(Tags=[{"Key": "Name", "Value": name}])
    info_msg("Created VPC, id=%s" % vpc.id)
    vpc.wait_until_available()
    vpc_id = vpc.id
    debug_msg("Creating subnets:%s" % json.dumps(subnet_conf_list))
    for subnet_conf in subnet_conf_list:
        subnet_param = {}
        subnet_param['VpcId'] = vpc_id
        subnet_param['CidrBlock'] = subnet_conf['cidr']
        if 'availability_zone' in subnet_conf:
            subnet_param['AvailabilityZone'] = subnet_conf['availability_zone']
        subnet = ec2.create_subnet(**subnet_param)
        info_msg('Created subnet, id=%s' % subnet.subnet_id)
        if 'route_table' in subnet_conf:
            route_table = vpc.create_route_table()
            info_msg('Created route table, id=%s' % route_table.id)
            route_table.associate_with_subnet(SubnetId=subnet.id)
            info_msg('Associated route table to subnet %s' % subnet.id)
            route_table.create_tags(Tags=[{"Key": "Name", "Value": subnet_conf['route_table']}])
        if 'name' in subnet_conf:
            subnet.create_tags(Tags=[{"Key": "Name", "Value": subnet_conf['name']}])
    if save_vpc_id != None:
        write_vpc_id(vpc_id, save_vpc_id)
    info_msg('Showing VPC information:')
    show_vpc_parameters(session, [vpc_id], False, True, True)

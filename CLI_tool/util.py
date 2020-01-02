import sys
import os
import boto3
import click
import json
import logging
import logging.handlers
import socket
import struct

handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))
logger = logging.getLogger('vsrx-aws')
logger.setLevel(logging.INFO)
logger.addHandler(handler)

def debug_msg(msg):
    logger.debug(msg)

def error_msg(msg):
    logger.error(msg)

def info_msg(msg):
    logger.info(msg)

def warning_msg(msg):
    logger.warning(msg)

def disable_info_msg():
    logger.setLevel(logging.WARNING)

def disable_debug_msg():
    logger.setLevel(logging.INFO)

def enable_verbose_mode():
    logger.setLevel(logging.DEBUG)

def ip2int(addr):
    return struct.unpack("!I", socket.inet_aton(addr))[0]

def int2ip(addr):
    return socket.inet_ntoa(struct.pack("!I", addr))

def _print_instance_info(ident, title, desc):
    str_0 = ''.ljust(ident, ' ')
    str_1 = title.ljust(40, '.')
    if desc == None or desc == '':
        desc = 'n/a'
    str_2 = '[%s]' % desc
    info_msg(str_0 + str_1 + str_2)

def security_groups_str(groups):
    ids = []
    for group in groups:
        ids.append(group['GroupId'])
    return ','.join(ids)

def get_network_interface(instance, device_index):
    for interface in instance.network_interfaces:
        if device_index == interface.attachment['DeviceIndex']:
            return interface
    return None

def get_security_group_by_name(session, group_name, vpc_id):
    client = session.client('ec2')
    ec2 = session.resource('ec2')
    group_id = None
    filters = []
    filters.append({
        'Name':'vpc-id',
        'Values': [vpc_id]
    })  
    filters.append({
        'Name':'group-name',
        'Values': [group_name]
    })  
    response = client.describe_security_groups(Filters = filters)
    debug_msg("filters describe_security_groups():" + json.dumps(filters))
    debug_msg("response describe_security_groups():" + json.dumps(response))
    if len(response['SecurityGroups']) > 0:
        for sg in response['SecurityGroups']:
            group_id = sg['GroupId']
            return group_id
    return None

def get_subnet_gateway(session, subnet_id):
    ec2 = session.resource('ec2')
    subnet = ec2.Subnet(subnet_id)
    cidr = subnet.cidr_block
    mask_len = int(cidr.split('/')[1])
    subnet_ip =  ip2int(cidr.split('/')[0])
    gateway_ip = subnet_ip + 1 
    gateway = int2ip(gateway_ip)
    return gateway, mask_len

def create_default_security_group(session, group_name, vpc_id, is_fxp0):
    ec2 = session.resource('ec2')
    security_group = ec2.create_security_group(
            GroupName = group_name,
            Description = 'Security group of automated orchestration',
            VpcId = vpc_id)
    if is_fxp0:
        response = security_group.authorize_ingress(
            CidrIp = '0.0.0.0/0',
            FromPort = 830,
            ToPort = 830,
            IpProtocol = 'tcp'
        )
        debug_msg("response authorize_ingress:" + json.dumps(response))
        response = security_group.authorize_ingress(
            CidrIp = '0.0.0.0/0',
            FromPort = 22,
            ToPort = 22,
            IpProtocol = 'tcp'
        )
        debug_msg("response authorize_ingress:" + json.dumps(response))
    else:
        response = security_group.authorize_ingress(
            CidrIp = '0.0.0.0/0',
            FromPort = -1,
            ToPort = -1,
            IpProtocol = '-1'
        )
        debug_msg("response authorize_ingress:" + json.dumps(response))
           
    return security_group.group_id

def instance_set_default_groups(session, instance):
    default_group_fxp0 = 'vsrx-fxp0-group'
    default_group_ge = 'vsrx-ge-group'
    for interface in instance.network_interfaces:
        device_index = interface.attachment['DeviceIndex']
        if device_index == 0:
            group_name = default_group_fxp0
            is_fxp0 = True
        else:
            group_name = default_group_ge
            is_fxp0 = False
        response = interface.describe_attribute(Attribute = 'groupSet')
        group_id = None
        if_group_ids = []
        for sg in response['Groups']:
            if sg['GroupName'] == group_name:
                group_id = sg['GroupId']
                info_msg("%s already in group list" % group_name)
                break
            else:
                if_group_ids.append(sg['GroupId'])
        if group_id == None:
            group_id = get_security_group_by_name(session, \
                     group_name, instance.vpc_id)
            if group_id == None:
                group_id = create_default_security_group(session, \
                        group_name, instance.vpc_id, is_fxp0)
            if group_id != None:
                if_group_ids.append(group_id)
                interface.modify_attribute(Groups = if_group_ids)


def vpc_name_to_ids(session, vpc_name):
    vpc_ids = []
    client = session.client('ec2')
    filters = [ 
        {   
            'Name': 'tag:Name',
            'Values': [
                vpc_name
            ]   
        }   
    ]   
    response = client.describe_vpcs(Filters = filters)
    debug_msg('response describe_vpcs: %s' % json.dumps(response))
    for vpc in response['Vpcs']:
        vpc_ids.append(vpc['VpcId'])
    return vpc_ids

def instance_name_to_ids(session, instance_name, vpc_id):
    instance_ids = []
    client = session.client('ec2')
    filters = [ 
        {   
            'Name': 'tag:Name',
            'Values': instance_name   
        }   
    ]
    if vpc_id != None:
        filters.append({
            'Name':'vpc-id',
            'Values': [vpc_id]
        })
    response = client.describe_instances(Filters = filters)
    #debug_msg('response describe_instances: %s' % json.dumps(response))
    for resv in response['Reservations']:
        for instance in resv['Instances']:
            instance_ids.append(instance['InstanceId'])
    return instance_ids


def print_instance_info(instance):
    first_ident = 4
    second_ident = 8
    _print_instance_info(first_ident, 'Instance ID', instance.instance_id)
    _print_instance_info(first_ident, 'Image ID', instance.image_id)
    _print_instance_info(first_ident, 'Instance type', instance.instance_type)
    _print_instance_info(first_ident, 'Architecture', instance.architecture)
    _print_instance_info(first_ident, 'Public IP', instance.public_ip_address)
    _print_instance_info(first_ident, 'Key Name', instance.key_name)
    _print_instance_info(first_ident, 'VPC ID', instance.vpc_id)
    _print_instance_info(first_ident, 'State', instance.state['Name'])
    interface_num = len(instance.network_interfaces)
    for dev_id in range(interface_num):
        interface = get_network_interface(instance, dev_id)
        if dev_id == 0:
            interface_name = 'fxp0'
        else:
            ge_id = dev_id - 1
            interface_name = 'ge-0/0/%d' % ge_id
        _print_instance_info(first_ident, '%s - Status' % interface_name, interface.status)
        _print_instance_info(first_ident, '%s - Mac address' % interface_name, interface.mac_address)
        if interface.association_attribute != None and 'PublicIp' in interface.association_attribute:
            _print_instance_info(first_ident, '%s - Public IPv4' % interface_name, \
                           interface.association_attribute['PublicIp'])
        _print_instance_info(first_ident, '%s - Private IPv4' % interface_name, interface.private_ip_address)
        _print_instance_info(first_ident, '%s - Subnet ID' % interface_name, interface.subnet_id)
        groups_id_str = security_groups_str(interface.groups)
        _print_instance_info(first_ident, '%s - Groups' % interface_name, groups_id_str)
        _print_instance_info(first_ident, '%s - src/dst check' % interface_name, interface.source_dest_check)


def is_valid_ipv4_address(address):
    try:
        socket.inet_pton(socket.AF_INET, address)
    except AttributeError:  # no inet_pton here, sorry
        try:
            socket.inet_aton(address)
        except socket.error:
            return False
        return address.count('.') == 3
    except socket.error:  # not a valid address
        return False

    return True


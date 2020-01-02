import sys
import os
import boto3
import click
import json
import datetime
import time
import re
import socket
import yaml
from util import *
from cloudwatch import configure_cloudwatch_dashbord
from botocore.exceptions import ClientError
import traceback

def convert_timestamp(item_date_object):
    if isinstance(item_date_object, (datetime.date, datetime.datetime)):
        return item_date_object.strftime("%m/%d/%Y %H:%M:%S")

def subnet_name_to_ids(session, subnet_name, vpc_id):
    subnet_ids = []
    client = session.client('ec2')
    filters = [ 
        {   
            'Name': 'tag:Name',
            'Values': [
                subnet_name
            ]   
        }   
    ]
    if vpc_id != None:
        filters.append({
            'Name':'vpc-id',
            'Values': [vpc_id]
        })

    response = client.describe_subnets(Filters = filters)
    debug_msg('response describe_subnets: %s' % json.dumps(response))
    for subnet in response['Subnets']:
        subnet_ids.append(subnet['SubnetId'])
    return subnet_ids

def subnet_id_to_vpc_id(session, subnet_id):
    ec2 = session.resource('ec2')
    subnet = ec2.Subnet(subnet_id)
    return subnet.vpc_id

def check_security_group(session, group_id, vpc_id):
    info_msg('Checking security group %s' % group_id)
    ec2 = session.resource('ec2')
    try:
        sg = ec2.SecurityGroup(group_id)
        if vpc_id != None and vpc_id != sg.vpc_id:
            return False
        else:
            return True
    except:
        #error_msg(traceback.format_exc())
        return False

def parse_nic_configs(nic_configs):
    nics = []
    for nic_conf in nic_configs:
        nic = {}
        config_items = nic_conf.split(',')
        for config_item in config_items:
            if config_item == '':
                continue
            option = config_item.split('=')
            if len(option) != 2:
                error_msg('Invalid nic option %s in configuration %s' \
                    % (config_item, nic_conf))
                sys.exit(1)
            option_name = option[0].strip()
            option_value = option[1].strip()
            if option_name != 'subnet-name' and \
               option_name != 'subnet-id' and \
               option_name != 'subnet-gateway' and \
               option_name != 'public-ip' and \
               option_name != 'private-ip' and \
               option_name != 'group':
                error_msg('Unknown option name "%s" in nic configuration %s' \
                    % (option_name, nic_conf))
                sys.exit(1)
            if option_name == 'group':
                if 'group' not in nic:
                    nic['group'] = []
                nic['group'].append(option_value)
            elif option_name == 'subnet-gateway':
                if option_value != 'self' and \
                   not re.search('^igw-', option_value) and \
                   not re.search('^eni-', option_value):
                    error_msg('Invalid subnet-gateway value in %s' % nic_conf)
                    error_msg('subnet-gateway should be one of "self"|GatewayId|NetworkInterfaceId')
                    sys.exit(1)
                else:
                    nic[option_name] = option_value
            else:
                nic[option_name] = option_value
        nics.append(nic)
    return nics

def check_nic_configs(session, nics, vpc_id):
    info_msg('Checking nics configurations ..')
    for nic in nics:
        if 'subnet-id' in nic and 'subnet-name' in nic:
            warning_msg('Ignoring subnet-name %s as subnet-id specified for same nic')
        if 'subnet-id' not in nic and 'subnet-name' not in nic:
            error_msg('Need to specify either subnet-id or subnet-name for nic')
            sys.exit(1)
        if 'subnet-id' not in nic:
            subnet_ids = subnet_name_to_ids(session, nic['subnet-name'], vpc_id)
            if len(subnet_ids) == 0:
                error_msg('Cannot get subnet id from name %s, vpc id:%s' % \
                    (nic['subnet-name'], str(vpc_id)))
                sys.exit(1)
            elif len(subnet_ids) > 1:
                error_msg('Muiltiple subnets %s got from name %s, vpc id:%s' % \
                    (json.dumps(subnet_ids), nic['subnet-name'], str(vpc_id)))
                sys.exit(1)
            else:
                nic['subnet-id'] = subnet_ids[0]
                info_msg('Subnet id %s (%s)' % (nic['subnet-id'], nic['subnet-name']))
            if vpc_id == None:
                vpc_id = subnet_id_to_vpc_id(nic['subnet-id'])
        ec2 = session.resource('ec2')
        subnet = ec2.Subnet(nic['subnet-id'])
        nic['subnet-cidr'] = subnet.cidr_block
        rtb_id = get_route_table_by_subnet(session, nic['subnet-id'])
        nic['subnet-rtb'] = rtb_id
        if 'group' in nic:
            for sg in nic['group']:
                valid = check_security_group(session, sg, vpc_id)
                if not valid:
                    error_msg('Invalid security group %s' % sg)
                    sys.exit(1)

def interface_add_elastic_ip(client, interface_id, ip_addr):
    info_msg('Adding elastic IP to interface %s' % interface_id)
    if ip_addr == None:
        info_msg('Allocating new elastic IP')
        allocation = client.allocate_address(Domain='vpc')
        alloc_id = allocation['AllocationId']
        ip_addr = allocation['PublicIp']
    else:
        ip_list = [ip_addr]
        info_msg('Associating existing elastic IP %s' % ip_addr)
        response = client.describe_addresses(PublicIps=ip_list)
        debug_msg('IP information:' + json.dumps(response))
        alloc_id = response['Addresses'][0]['AllocationId']
    response = client.associate_address(AllocationId=alloc_id,
                                     NetworkInterfaceId=interface_id,
                                     AllowReassociation = True)
    info_msg("Associated elastic IP address %s" % ip_addr)
    debug_msg(json.dumps(response))
    return ip_addr

def disable_source_dest_check(instance):
    for interface in instance.network_interfaces:
        if interface.attachment['DeviceIndex'] != 0:
            interface.modify_attribute(SourceDestCheck = {'Value': False})
            info_msg("Interface %s(device_idx %d): src/dst check disabled" % \
                    (interface.description, interface.attachment['DeviceIndex']))

def get_interface_id(instance, dev_id):
    for interface in instance.network_interfaces:
        if interface.attachment['DeviceIndex'] == dev_id:
            return interface.id
    return None

def get_interface_public_ip(instance, dev_id):
    for interface in instance.network_interfaces:
        if interface.attachment['DeviceIndex'] == dev_id:
            if interface.association_attribute != None and \
                     'PublicIp' in interface.association_attribute:
                return interface.association_attribute['PublicIp']
            else:
                break
    return None

def read_userdata(filename):
    with open(filename) as f:
        return f.read()

def probe_tcp_port(ip, port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex((ip, port))
    return result

def get_subnet_info(ec2, subnet_id):
    subnet = ec2.Subnet(subnet_id)
    cidr = subnet.cidr_block
    mask_len = int(cidr.split('/')[1])
    subnet_ip =  ip2int(cidr.split('/')[0])
    gateway_ip = subnet_ip + 1
    gateway = int2ip(gateway_ip)
    return gateway, mask_len

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
        ec2 = session.resource('ec2')
        subnet = ec2.Subnet(subnet_id)
        vpc = ec2.Vpc(subnet.vpc_id)
        for rtb in vpc.route_tables.all():
            for assoc in rtb.associations_attribute:
                if assoc['Main']:
                    debug_msg('main route table %s' % rtb.route_table_id)
                    return rtb.route_table_id
    return None

def create_route_with_igw(session, rtb_id, cidr, gw_id):
    info_msg('Creating route rtb_id %s, CIDR %s, gw_id %s' % (rtb_id, cidr, gw_id))
    ec2 = session.resource('ec2')
    route_table = ec2.RouteTable(rtb_id)
    route_table.create_route(DestinationCidrBlock=cidr, GatewayId=gw_id)

def create_route_with_interface_id(session, rtb_id, cidr, interface_id):
    info_msg('Creating route rtb_id %s, CIDR %s, interface_id %s' \
         % (rtb_id, cidr, interface_id))
    ec2 = session.resource('ec2')
    route_table = ec2.RouteTable(rtb_id)
    try:
        route_table.create_route(DestinationCidrBlock=cidr, NetworkInterfaceId=interface_id)
    except ClientError as e:
        if e.response['Error']['Code'] == "RouteAlreadyExists":
            client = session.client('ec2')
            client.delete_route(DestinationCidrBlock=cidr, RouteTableId=rtb_id)
            route_table.create_route(DestinationCidrBlock=cidr, NetworkInterfaceId=interface_id)
        else:
            error_msg(e)
            sys.exit(1)

def configure_subnets_route(session, nic_param_list):
    info_msg('Configuring routes between subnets')
    dst_dev_id = 0
    debug_msg(json.dumps(nic_param_list))
    for nic_params in nic_param_list:
        if dst_dev_id == 0:
            dst_dev_id += 1
            continue
        debug_msg('dst %d' % dst_dev_id)
        dst_cidr = nic_params['subnet-cidr']
        interface_id = nic_params['interface-id']
        src_dev_id = 0
        for src_nic_params in nic_param_list:
            if src_dev_id == 0 or dst_dev_id == src_dev_id:
                src_dev_id += 1
                continue
            debug_msg('src %d' % src_dev_id)
            rtb_id = src_nic_params['subnet-rtb']
            interface_id = src_nic_params['interface-id']
            debug_msg('dst_cidr %s rtb_id %s iface_id %s' % (dst_cidr, rtb_id, interface_id))
            create_route_with_interface_id(session, rtb_id, dst_cidr, interface_id)
            src_dev_id += 1
        dst_dev_id += 1

def configure_ge_interfaces(ec2, fxp0_addr, instance, key_file):
    info_msg('Configuring ge interfaces ...')
    abs_key_path = os.path.abspath(key_file)
    interface_var = {}
    interface_var['interfaces'] = []
    for interface in instance.network_interfaces:
        if interface.attachment['DeviceIndex'] != 0:
            interface_param = {}
            ge_id = interface.attachment['DeviceIndex'] - 1 
            subnet_gw,mask_len = get_subnet_info(ec2, interface.subnet_id)
            name = 'ge-0/0/%d' % ge_id
            address = "%s/%d" % (interface.private_ip_address, mask_len)
            interface_var['interfaces'].append({
               'name': name,
               'address':address
            })
            if interface.association_attribute != None and \
                'PublicIp' in interface.association_attribute and \
                'default_gw' not in interface_var:
                interface_var['default_gw'] = subnet_gw
    if len(interface_var['interfaces']) == 0:
        info_msg("no ge interfaces to configure")
        return True
    param_file = '/tmp/%s-interfaces.yml' % instance.instance_id
    debug_msg(yaml.dump(interface_var, default_flow_style=True))
    with open(param_file, 'w') as outfile:
        yaml.dump(interface_var, outfile, default_flow_style=False)
    ansible_cmd = "docker run -it --rm -v \"$(pwd)/ansible/playbook/:/playbooks\" -v \"%s:/host-key.pem\" " + \
                  "-v %s:/interfaces_var.yml " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, configure_interfaces.yml"
    ansible_cmd = ansible_cmd % (abs_key_path, param_file, fxp0_addr)
    info_msg(ansible_cmd)
    os.system(ansible_cmd)

def show_system_info(fxp0_addr, key_file):
    info_msg('Showing system information ...')
    abs_key_path = os.path.abspath(key_file)
    ansible_cmd = "docker run -it --rm -v \"$PWD/ansible/playbook/\":/playbooks -v \"%s:/host-key.pem\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, show_device_info.yml"
    ansible_cmd = ansible_cmd % (abs_key_path, fxp0_addr)
    info_msg(ansible_cmd)
    os.system(ansible_cmd)

def configure_cloudwatch_device(fxp0_addr, key_file):
    info_msg('Configuring CloudWatch on device ...')
    abs_key_path = os.path.abspath(key_file)
    ansible_cmd = "docker run -it --rm -v \"$PWD/ansible/playbook/\":/playbooks -v \"%s:/host-key.pem\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, configure_cloudwatch.yml"
    ansible_cmd = ansible_cmd % (abs_key_path, fxp0_addr)
    info_msg(ansible_cmd)
    os.system(ansible_cmd)

def try_netconf(fxp0_addr, key_file):
    debug_msg('Trying NETCONF channel ...')
    abs_key_path = os.path.abspath(key_file)
    ansible_cmd = "docker run -it --rm -v \"$PWD/ansible/playbook/\":/playbooks -v \"%s:/host-key.pem\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, show_device_info.yml"
    ansible_cmd = ansible_cmd % (abs_key_path, fxp0_addr)
    debug_msg(ansible_cmd)
    system_info = os.popen(ansible_cmd).read()
    #debug_msg(system_info)
    hit = re.search("executed successfully", system_info)
    if hit:
        debug_msg('NETCONF service is available')
        return True
    else:
        debug_msg('NETCONF service is not available')
        return False

def is_fpc_online(fxp0_addr, key_file):
    debug_msg('Checking fpc status ...')
    abs_key_path = os.path.abspath(key_file)
    ansible_cmd = "docker run -it --rm -v \"$PWD/ansible/playbook/\":/playbooks -v \"%s:/host-key.pem\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, show_pic_status.yml"
    ansible_cmd = ansible_cmd % (abs_key_path, fxp0_addr)
    debug_msg(ansible_cmd)
    fpc_info = os.popen(ansible_cmd).read()
    debug_msg(fpc_info)
    hit = re.search("PIC\s+0\s+Online", fpc_info)
    if hit:
        debug_msg('detected PIC O online now')
        return True
    else:
        debug_msg('PIC O is still offline')
        return False

def write_instance_id(instance_id, output_file):
    info_msg('Saving instance_id(%s) to %s' % (instance_id, output_file))
    with open(output_file, 'w') as outfile:
        outfile.write('%s' % instance_id)

@click.command()
@click.option('--instance-type', default='c5.large', help='Type of EC2 instance', show_default=True)
@click.option('--instance-name', help='The name of instance tag name')
@click.option('--key-name', prompt='Key pair name to access vSRX instance', help='The name of the key pair')
@click.option('--key-file', prompt='Private key file to access vSRX instance', type=click.Path(), help='Private key file')
@click.option('--vpc-id', help='Specify VPC ID')
@click.option('--vpc-name', help='Specify VPC name')
@click.option('--nic', multiple=True, help='The interface to associated with the instance')
@click.option('--iam-role', help='The IAM role associated with the instance')
@click.option('--junos-config-file', type=click.Path(), help='JUNOS configuration file')
@click.option('--config-interface', is_flag=True, help='Configure device interfaces over NETCONF')
@click.option('--config-cloudwatch', is_flag=True, help='Configure CloudWatch monitoring')
@click.option('--wait-netconf-ready', is_flag=True, help='Wait until device NETCONF service is ready')
@click.option('--wait-fpc-online', is_flag=True, help='Wait until device fpc online')
@click.option('--save-instance-id', type=click.Path(), help='Save vSRX instance ID to the file')
@click.option('-v', '--verbose', is_flag=True, help='Enable verbose mode to get more information')
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
@click.argument('image-id')
def deploy(image_id, instance_type, instance_name, vpc_id, vpc_name,
          key_name, key_file, nic, iam_role, 
          junos_config_file, config_interface, config_cloudwatch, wait_netconf_ready,
          wait_fpc_online, save_instance_id, verbose, profile, region):
    """Launch a vSRX instance"""
    if verbose:
        enable_verbose_mode()
    info_msg('Starting to deploy vSRX in AWS, image_id=%s' % image_id)
    if (config_cloudwatch or config_interface) and key_file == None:
        error_msg('Please specify key file by "--key-file"')
        sys.exit(1)
    if key_file != None and not os.path.isfile(key_file):
        error_msg('Key file "%s" does not exist' % key_file)
        sys.exit(1)
    session = boto3.Session(profile_name=profile, region_name=region)
    if vpc_id != None and vpc_name != None:
        warning_msg('Ignoring VPC name %s when VPC ID %s is specified' % (vpc_name, vpc_id))
    elif vpc_name != None:
        vpc_id_list = vpc_name_to_ids(session, vpc_name)
        if len(vpc_id_list) == 0:
            error_msg('Cannot get VPC ID from name %s' % vpc_name)
            sys.exit(1)
        elif len(vpc_id_list) > 1:
            error_msg('Multiple VPC ID got %s from name %s' % \
               (json.dumps(vpc_id_list), vpc_name))
            sys.exit(1)
        else:
            vpc_id = vpc_id_list[0]
    nic_param_list = parse_nic_configs(nic)
    check_nic_configs(session, nic_param_list, vpc_id)
    client = session.client('ec2')
    ec2 = session.resource('ec2')
    instance_params = {}
    instance_params['InstanceType'] = instance_type
    instance_params['ImageId'] = image_id
    instance_params['MinCount'] = 1
    instance_params['MaxCount'] = 1
    if instance_name != None:
        instance_params['TagSpecifications'] = [
            {
                'ResourceType':'instance',
                'Tags': [
                    {
                        'Key': 'Name',
                        'Value': instance_name
                    }
                ]
            }
        ]
    if key_name != None:
        instance_params['KeyName'] = key_name
    dev_id = 0
    network_interfaces = []
    public_ip_needed = False
    for nic_params in nic_param_list:
        interface = {}
        interface['DeviceIndex'] = dev_id
        interface['SubnetId'] = nic_params['subnet-id']
        if 'group' in nic_params:
            interface['Groups'] = nic_params['group']
        if 'public-ip' in nic_params and nic_params['public-ip'] != 'none':
            public_ip_needed = True
        if dev_id == 0:
            interface['Description'] = 'fxp0'
        else:
            ge_id = dev_id - 1
            interface['Description'] = 'ge-0/0/%d' % ge_id
        network_interfaces.append(interface)
        dev_id += 1
    if len(network_interfaces) > 0:
        instance_params['NetworkInterfaces'] = network_interfaces
    if iam_role != None:
        instance_params['IamInstanceProfile'] = {}
        instance_params['IamInstanceProfile']['Name'] = iam_role
    if junos_config_file != None:
        userdata = read_userdata(junos_config_file)
        instance_params['UserData'] = userdata
    instances = ec2.create_instances(**instance_params)
    instance = instances[0]
    info_msg('One vSRX instance created')   
    info_msg("Waiting instance ready ...")
    instance.wait_until_running()
    info_msg('Instance is running now')
    fxp0_ip = None
    igw_id = None
    if len(instance.network_interfaces) > 0:
        dev_id = 0
        if public_ip_needed:
            igw_id = vpc_attach_internet_gateway(session, instance.vpc_id)
        for nic_params in nic_param_list:
            interface_id = get_interface_id(instance, dev_id)
            nic_params['interface-id'] = interface_id
            if 'subnet-gateway' in nic_params:
                rtb_id = get_route_table_by_subnet(session, nic_params['subnet-id'])
                subnet_gateway = nic_params['subnet-gateway']
                if subnet_gateway == 'self':
                    debug_msg('interface id %s' % interface_id)
                    create_route_with_interface_id(session, rtb_id, '0.0.0.0/0', interface_id)
                elif re.search("^eni-", subnet_gateway):
                    create_route_with_interface_id(session, rtb_id, '0.0.0.0/0', subnet_gateway)
                elif re.search("^igw-", subnet_gateway):
                    create_route_with_igw(session, rtb_id, '0.0.0.0/0', subnet_gateway)
            if 'public-ip' in nic_params:
                if nic_params['public-ip'] == 'auto':
                    interface_add_elastic_ip(client, interface_id, None)
                else:
                    interface_add_elastic_ip(client, interface_id, nic_params['pubic-ip'])
                rtb_id = get_route_table_by_subnet(session, nic_params['subnet-id'])
                if 'subnet-gateway' not in nic_params and rtb_id != None:
                    if igw_id != None:
                        create_route_with_igw(session, rtb_id, '0.0.0.0/0', igw_id)
            dev_id += 1
        instance_set_default_groups(session, instance)
    disable_source_dest_check(instance)
    instance_id = instance.instance_id
    instance = ec2.Instance(instance_id)
    fxp0_ip = get_interface_public_ip(instance, 0)
    print_instance_info(instance)
    if config_interface or config_cloudwatch:
        wait_netconf_ready = True
    if fxp0_ip != None and wait_netconf_ready:
       info_msg('Waiting vSRX NETCONF service ready ...')
       while True:
          probe_result = probe_tcp_port(fxp0_ip, 830)
          if probe_result == 0:
              if key_file != None:
                  if try_netconf(fxp0_ip, key_file):
                      time.sleep(15)
                      break
              else:
                  break
          else:
             info_msg('%s:NETCONF is not ready, waiting 60s ...' \
                    % instance.instance_id)
             time.sleep(60)
       info_msg('%s:vSRX is ready to configure' % instance.instance_id)
       time.sleep(5)
       if key_file != None:
           show_system_info(fxp0_ip, key_file)
    if config_interface == True:
        configure_ge_interfaces(ec2, fxp0_ip, instance, key_file)
    if config_cloudwatch == True:
        configure_cloudwatch_dashbord(session, region, instance, 'vsrx-ns')
        configure_cloudwatch_device(fxp0_ip, key_file)
    if wait_fpc_online and fxp0_ip != None:
        while not is_fpc_online(fxp0_ip, key_file):
            info_msg('%s:vSRX FPC PIC 0 is not online, waiting 60s ...' % instance.instance_id)
            time.sleep(60)
        info_msg('%s:vSRX PC PIC 0 is online now' % instance.instance_id)
    if save_instance_id != None:
        write_instance_id(instance.instance_id, save_instance_id)

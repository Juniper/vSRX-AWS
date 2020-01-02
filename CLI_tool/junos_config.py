import sys 
import os
import boto3
import click
import json
import yaml
from util import *


def get_instance_var(session, instance_id):
    ec2 = session.resource('ec2')
    instance = ec2.Instance(instance_id)
    instance_var = {}
    ge_interfaces = []
    for interface in instance.network_interfaces:
        if interface.attachment['DeviceIndex'] != 0:
            interface_param = {}
            ge_id = interface.attachment['DeviceIndex'] - 1 
            subnet_gw,mask_len = get_subnet_gateway(session, interface.subnet_id)
            interface_param['name'] = 'ge-0/0/%d' % ge_id
            interface_param['private_ip_mask'] = "%s/%d" % (interface.private_ip_address, mask_len)
            interface_param['private_ip'] = interface.private_ip_address
            instance_var['ge_0_0_%d_private_ip' % ge_id] = interface.private_ip_address
            if interface.association_attribute != None and \
                'PublicIp' in interface.association_attribute:
                interface_param['public_ip'] = interface.association_attribute['PublicIp']
                instance_var['ge_0_0_%d_public_ip' % ge_id] = interface.association_attribute['PublicIp']
            ge_interfaces.append(interface_param)
    instance_var['ge-interfaces'] = ge_interfaces
    if instance.public_ip_address != None:
        instance_var['public_ip'] = instance.public_ip_address
    instance_var['instance_id'] = instance.instance_id
    return instance_var

def config_instance_with_template(instance_var, junos_config_file, key_file, extra_vars):
    abs_key_path = os.path.abspath(key_file)
    abs_config_file = os.path.abspath(junos_config_file)
    if 'public_ip' not in instance_var:
        warning_msg('no public IP address on instance %s' % instance_var['instance_id'])
        print instance_var
        return False
    debug_msg('Instance variables:%s' % json.dumps(instance_var))
    instance_id = instance_var['instance_id']
    param_file = '/tmp/%s-var.yml' % instance_id
    fxp0_addr = instance_var['public_ip']
    debug_msg(yaml.dump(instance_var, default_flow_style=True))
    with open(param_file, 'w') as outfile:
        yaml.dump(instance_var, outfile, default_flow_style=False)
    if extra_vars == None:
        ansible_cmd = "docker run -it --rm -v \"$(pwd)/ansible/playbook:/playbooks\" -v \"%s:/host-key.pem\" " + \
                  "-v %s:/instance_var.yml -v \"%s:/junos.conf.j2\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, configure_junos_j2.yml"
        ansible_cmd = ansible_cmd % (abs_key_path, param_file, abs_config_file, fxp0_addr)
    else:
        ansible_cmd = "docker run -it --rm -v \"$(pwd)/ansible/playbook:/playbooks\" -v \"%s:/host-key.pem\" " + \
                  "-v %s:/instance_var.yml -v \"%s:/junos.conf.j2\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user --extra-vars '%s' -i %s, configure_junos_j2.yml"
        ansible_cmd = ansible_cmd % (abs_key_path, param_file, abs_config_file, extra_vars, fxp0_addr)
      
    info_msg(ansible_cmd)
    os.system(ansible_cmd)

def config_instance(instance_var, junos_config_file, key_file):
    abs_key_path = os.path.abspath(key_file)
    abs_config_file = os.path.abspath(junos_config_file)
    if 'public_ip' not in instance_var:
        warning_msg('not public IP address on instance %s' % instance_var['instance_id'])
        #print instance_var
        return False
    fxp0_addr = instance_var['public_ip']
    debug_msg(yaml.dump(instance_var, default_flow_style=True))
    ansible_cmd = "docker run -it --rm -v \"$(pwd)/ansible/playbook:/playbooks\" -v \"%s:/host-key.pem\" " + \
                  "-v \"%s:/junos.conf\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, configure_junos.yml"
    ansible_cmd = ansible_cmd % (abs_key_path, abs_config_file, fxp0_addr)
    info_msg(ansible_cmd)
    os.system(ansible_cmd)

@click.command()
@click.option('--instance-id',  multiple=True, help='The ID of instance')
@click.option('--instance-name', multiple=True, help='The Name of instance')
@click.option('--vpc-id', help='VPC in which the instance is running')
@click.option('--jinja2', '-j', is_flag=True, help='Configuration file is a Jinja2 tempate file')
@click.option('--extra-vars', help='Pass extra variables to ansible playbooks')
@click.option('--key-file', prompt='Private key file to access vSRX instance', type=click.Path(), help='Private key file')
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose mode to get more information')
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
@click.argument('JUNOS-CONFIG-FILE')
def junos_config(junos_config_file, instance_id, instance_name, vpc_id, jinja2, 
                 extra_vars, key_file, verbose, profile, region):
    """Load Junos configuration file to vSRX instances"""
    if verbose:
        enable_verbose_mode()
    info_msg('Configuring Junos ...')
    if key_file != None and not os.path.isfile(key_file):
        error_msg('Key file "%s" does not exist' % key_file)
        sys.exit(1)
    if not os.path.isfile(junos_config_file):
        error_msg('Junos configuration file "%s" does not exist' % junos_config_file)
        sys.exit(1)
    session = boto3.Session(profile_name=profile, region_name=region)
    id_list_by_name = []
    if len(instance_name) > 0:
        id_list_by_name = instance_name_to_ids(session, instance_name, vpc_id)
    instance_var_index = {}
    instance_var_list = []
    for vsrx_instance_id in instance_id:
        if instance_id in instance_var_index:
            continue
        info_msg('Getting instance %s variables' % vsrx_instance_id)
        vsrx_var = get_instance_var(session, vsrx_instance_id)
        instance_var_list.append(vsrx_var)
        instance_var_index[instance_id] = vsrx_var
    for vsrx_instance_id in id_list_by_name:
        if instance_id in instance_var_index:
            continue
        info_msg('Getting instance %s variables' % vsrx_instance_id)
        vsrx_var = get_instance_var(session, vsrx_instance_id)
        instance_var_list.append(vsrx_var)
        instance_var_index[instance_id] = vsrx_var
    for vsrx_var in instance_var_list:
        if jinja2:
            config_instance_with_template(vsrx_var, junos_config_file, key_file, extra_vars)
        else:
            config_instance(vsrx_var, junos_config_file, key_file)



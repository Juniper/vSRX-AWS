import sys 
import os
import boto3
import click
import json
import datetime
import time
import re
import traceback
from util import *

def is_fpc_online(fxp0_addrs, key_file):
    debug_msg('Checking pic status ...')
    abs_key_path = os.path.abspath(key_file)
    addr_str = ','.join(fxp0_addrs)  
    ansible_cmd = "docker run -it --rm -v \"$(pwd)/ansible/playbook/:/playbooks\" -v \"%s:/host-key.pem\" " + \
                  "-e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, show_pic_status.yml"
    ansible_cmd = ansible_cmd % (abs_key_path, addr_str)
    debug_msg(ansible_cmd)
    fpc_info = os.popen(ansible_cmd).read()
    debug_msg(fpc_info)
    all_online = True
    for addr in fxp0_addrs:
        hit = re.search("%s\s+fpc\s+online" % addr, fpc_info)
        if hit:
            info_msg("%s fpc is online" % addr)
        else:
            all_online = False
            info_msg("%s fpc is offline" % addr)
    return all_online

@click.command()
@click.option('--instance-id', '-i', 'instance_id', multiple=True, help='The ID of instance')
@click.option('--key-file', prompt='Private key file to access vSRX instance', \
                type=click.Path(), help='Private key file')
@click.option('-v', '--verbose', is_flag=True, help='Enable verbose mode to get more information')
@click.option('--timeout', default=1200, help='Maximum time(seconds) to wait', show_default=True)
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
def wait(instance_id, key_file, verbose, timeout, profile, region):
    """Wait vSRX fpc online"""
    if verbose:
        enable_verbose_mode()
    if key_file != None and not os.path.isfile(key_file):
        error_msg('Key file "%s" does not exist' % key_file)
        sys.exit(1)
    session = boto3.Session(profile_name=profile, region_name=region)
    client = session.client('ec2')
    ec2 = session.resource('ec2')
    public_ip_list = []
    for vsrx_id in instance_id:
        instance = ec2.Instance(vsrx_id)
        public_ip = instance.public_ip_address
        debug_msg("instance %s public IP %s" %(vsrx_id, public_ip))
        public_ip_list.append(public_ip)
    all_online = False
    if len(public_ip_list) > 0:
        wait_start = int(time.time())
        expire_timestamp =  wait_start + timeout
        while int(time.time()) < expire_timestamp:
            all_online = is_fpc_online(public_ip_list, key_file)
            if all_online:
                break
            info_msg('Sleeping 60s')
            time.sleep(60)

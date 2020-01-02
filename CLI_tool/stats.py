import os
import sys
import boto3
import click
import json
import shutil
import re
import time
from util import *
from tabulate import tabulate
from botocore.exceptions import NoCredentialsError
import traceback

stream_mode = False
def get_instance_public_ip(ec2, instance_id):
    instance = ec2.Instance(instance_id)
    return instance.public_ip_address

def get_vsrx_stats(ip_list, key_file):
    abs_key_path = None
    if key_file != None:
        abs_key_path = os.path.abspath(key_file)
    ip_string = ','.join(ip_list)
    stats_dir = '/tmp/__vsrx_stats_%d.d' % os.getpid()
    os.mkdir(stats_dir, 0755);
    if abs_key_path != None:
        ansible_cmd = "docker run -it --rm -v \"$(pwd)/ansible/playbook:/playbooks\" -v \"%s:/host-key.pem\" " + \
                  "-v \"%s\":/tmp -e ANSIBLE_NET_SSH_KEYFILE=/host-key.pem juniper/pyez-ansible " + \
                  "ansible-playbook --user ec2-user -i %s, show_stats.yml"
        ansible_cmd = ansible_cmd % (abs_key_path, stats_dir, ip_string)
    else:
        ansible_cmd = "docker run -it --rm -v \"$(pwd)/ansible/playbook:/playbooks\" " + \
                   "-v %s:/tmp juniper/pyez-ansible " + \
                   "ansible-playbook --user ec2-user -i %s, show_stats.yml"
        ansible_cmd = ansible_cmd % (stats_dir, ip_string)
    debug_msg(ansible_cmd)
    if stream_mode == True:
        ansible_cmd += ' > /dev/null'
    os.system(ansible_cmd)
    stats_file = os.path.join(stats_dir, "vsrx_stats.json")
    if not os.path.isfile(stats_file):
        debug_msg('Not able to get statistics data')
        shutil.rmtree(stats_dir)
        return None
    with open(stats_file) as fd:
        stats_str = fd.read()
        stats_data = json.loads(stats_str)
    shutil.rmtree(stats_dir)
    return stats_data

def parse_vsrx_stats(stats_json):
    stats_result = {}
    for host, stats in stats_json.iteritems():
        host_stats = {}
        dp_cpu_util = None
        dp_memory_util = None
        session_util = None
        cp_memory_util = None
        cp_cpu_util = None
        net_in_bps = 0
        net_in_pps = 0
        net_out_bps = 0
        net_out_pps = 0
        if 'security_monitor' in stats and 'parsed_output' in stats['security_monitor']:
            max_session = int(stats['security_monitor']['parsed_output']['performance-summary-information']\
                           [0]['performance-summary-statistics'][0]['spu-max-flow-session'][0]['data'])
            used_session = int(stats['security_monitor']['parsed_output']['performance-summary-information']\
                           [0]['performance-summary-statistics'][0]['spu-current-flow-session'][0]['data'])
            dp_cpu_util = int(stats['security_monitor']['parsed_output']['performance-summary-information']\
                           [0]['performance-summary-statistics'][0]['spu-cpu-utilization'][0]['data'])
            dp_memory_util = int(stats['security_monitor']['parsed_output']['performance-summary-information']\
                         [0]['performance-summary-statistics'][0]['spu-memory-utilization'][0]['data'])
            session_util = used_session * 100 / max_session
        if 're_info' in stats and 'parsed_output' in stats['re_info']:
            cp_memory_util = int(stats['re_info']['parsed_output']['route-engine-information'][0]['route-engine']\
                        [0]['memory-control-plane-util'][0]['data'])
            cp_memory_util = int(stats['re_info']['parsed_output']['route-engine-information'][0]['route-engine']\
                        [0]['memory-control-plane-util'][0]['data'])
            cp_cpu_idle = int(stats['re_info']['parsed_output']['route-engine-information'][0]['route-engine']\
                        [0]['cpu-idle'][0]['data'])
            cp_cpu_util = 100 - cp_cpu_idle
        if 'interface_stats' in stats and 'parsed_output' in stats['interface_stats']:
            for iface in stats['interface_stats']['parsed_output']['interface-information'][0]['physical-interface']:
                iface_name = str(iface['name'][0]['data'])
                is_ge_interface = re.search("ge-", iface_name, re.MULTILINE)
                if is_ge_interface:
                    input_bps = int(iface['traffic-statistics'][0]['input-bps'][0]['data'])
                    output_bps = int(iface['traffic-statistics'][0]['output-bps'][0]['data'])
                    input_pps = int(iface['traffic-statistics'][0]['input-pps'][0]['data'])
                    output_pps = int(iface['traffic-statistics'][0]['output-pps'][0]['data'])
                    net_in_bps += input_bps
                    net_in_pps += input_pps
                    net_out_bps += output_bps
                    net_out_pps += output_pps
        host_stats['dp_cpu_util'] = dp_cpu_util
        host_stats['dp_memory_util'] = dp_memory_util
        host_stats['session_util'] = session_util
        host_stats['cp_memory_util'] = cp_memory_util
        host_stats['cp_cpu_util'] = cp_cpu_util
        host_stats['net_in_bps'] = net_in_bps
        host_stats['net_in_pps'] = net_in_pps
        host_stats['net_out_bps'] = net_out_bps
        host_stats['net_out_pps'] = net_out_pps
        stats_result[host] = host_stats
    return stats_result

def get_stats_value(stats, key):
    if key in stats and stats[key] != None:
        return stats[key]
    else:
        return '-'

def print_vsrx_stats(host_stats, vsrx_ids):
    table = []
    table.append(['INSTANCE_ID', 'CP_CPU(%)', 'CP_MEM(%)', 'DP_CPU(%)', 'DP_MEM(%)', 'SESSION(%)', 'NET_IN(kbps)', 'NET_OUT(kbps)'])
    if host_stats == None:
        return
    for host, stats in host_stats.iteritems():
        vsrx_id = vsrx_ids[host]
        dp_cpu_util = get_stats_value(stats, 'dp_cpu_util')
        dp_memory_util = get_stats_value(stats, 'dp_memory_util')
        session_util = get_stats_value(stats, 'session_util')
        cp_memory_util = get_stats_value(stats, 'cp_memory_util')
        cp_cpu_util = get_stats_value(stats, 'cp_cpu_util')
        net_in_bps = get_stats_value(stats, 'net_in_bps')
        if isinstance(net_in_bps, int):
            net_in_kbps = float(net_in_bps/1024)
        else:
            net_in_kbps = '-'
        net_in_pps = get_stats_value(stats, 'net_in_pps')
        net_out_bps = get_stats_value(stats, 'net_out_bps')
        if isinstance(net_out_bps, int):
            net_out_kbps = float(net_out_bps/1024)
        else:
            net_out_kbps = '-'
        net_out_pps = get_stats_value(stats, 'net_out_pps')
        table.append([vsrx_id,cp_cpu_util, cp_memory_util, dp_cpu_util, dp_memory_util, session_util, net_in_kbps, net_out_kbps])
    print(tabulate(table, headers="firstrow",  tablefmt="psql"))


@click.command()
@click.option('--instance-id', '-i', 'instance_id', multiple=True, help='The ID of instance')
@click.option('--key-file', prompt='Private key file to access vSRX instance', \
                type=click.Path(), help='Private key file')
@click.option('--stream', is_flag=True, help='Display streaming stats')
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
def stats(instance_id, key_file, stream, profile, region):
    """Display resource usage statistics of running vSRX instances"""
    global stream_mode
    if stream == True:
        disable_debug_msg()
        stream_mode = True
    session = boto3.Session(profile_name=profile, region_name=region)
    client = session.client('ec2')
    ec2 = session.resource('ec2')
    vsrx_ids = {}
    public_ip_list = []
    for vsrx_id in instance_id:
        try:
            public_ip = get_instance_public_ip(ec2, vsrx_id)
        except NoCredentialsError:
            error_msg('Unable to locate credentials')
            error_msg('Please configure AWS credentials')
            sys.exit(1)
        except:
            error_msg('Cannot get public IP address for instance %s' % vsrx_id)
            error_msg(traceback.format_exc())
            sys.exit(1)  
        debug_msg("instance %s public IP %s" %(vsrx_id, public_ip))
        vsrx_ids[public_ip] = vsrx_id
        public_ip_list.append(public_ip)
    display_cnt = 1
    while stream or display_cnt > 0:
        info_msg('Loading vSRX statistics...')
        raw_stats_data = get_vsrx_stats(public_ip_list, key_file)
        host_stats = None
        if raw_stats_data != None:
            host_stats = parse_vsrx_stats(raw_stats_data)
        if stream:
            click.clear()
        print_vsrx_stats(host_stats, vsrx_ids)
        if stream:
            time.sleep(15)
        display_cnt -= 1

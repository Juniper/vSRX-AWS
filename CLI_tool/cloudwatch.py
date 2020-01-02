import sys 
import os
import boto3
from botocore.exceptions import ClientError
import click
import json
import datetime
import time
import re
from util import *

line_widget_x = 0
line_widget_y = 0

def get_line_widget(stacked, metrics, region):
    global line_widget_x
    global line_widget_y
    widget = {}
    widget['type'] = 'metric'
    widget['x'] = line_widget_x
    widget['y'] = line_widget_y
    widget['width'] = 6
    widget['height'] = 6
    widget['properties'] = {}
    widget['properties']['view'] = "timeSeries"
    widget['properties']['stacked'] = stacked
    widget['properties']['metrics'] = metrics
    widget['properties']['region'] = region
    line_widget_x += 6
    if line_widget_x > 18:
        line_widget_x = 0
        line_widget_y += 6
    metric_names = []
    for metric in metrics:
       metric_names.append(metric[1])
    metric_name_str = ','.join(metric_names)
    info_msg('Adding line widget for metrics - ' + metric_name_str)
    return widget

def create_or_update_dashboard(session, region, dashboard_name, widgets):
    body   = {'widgets' : widgets}
    body_json = json.dumps(body)
    client = session.client("cloudwatch", region_name=region)
    response = client.put_dashboard(DashboardName = dashboard_name,
                         DashboardBody = body_json)
    debug_msg('put_dashboard response:' + json.dumps(response))
    
def configure_cloudwatch_dashbord(session, region, instance, metric_ns):
    widgets = []
    ge_interface_num = 0 
    instance_id = instance.instance_id
    info_msg('Creating CloudWatch dashboard for instance %s, namespace %s'\
               % (instance_id,metric_ns))
    if len(instance.network_interfaces) > 0:
        ge_interface_num = len(instance.network_interfaces) - 1
    dataplane_cpu_num = instance.cpu_options['CoreCount'] * \
                      instance.cpu_options['ThreadsPerCore'] - 1
    recpu_metrics = [[ metric_ns, "RECPUUtil", "Instance ID", instance_id]]
    widgets.append(get_line_widget(False, recpu_metrics, region))
    dpcpu_metrics = []
    for cpuno in range(dataplane_cpu_num):
        dp_cpuno = cpuno + 1
        metric_name = "DataPlaneCPU%dUtil" % dp_cpuno
        metric = [metric_ns, metric_name, "Instance ID", instance_id]
        dpcpu_metrics.append(metric)
    widgets.append(get_line_widget(True, dpcpu_metrics, region))

    remem_metrics = [[ metric_ns, "REMemoryUtil", "Instance ID", instance_id ]]
    widgets.append(get_line_widget(False, remem_metrics, region))

    dpmem_metrics = [[ metric_ns, "DataplaneHeapMemoryUtil", "Instance ID", instance_id ]]
    widgets.append(get_line_widget(False, dpmem_metrics, region))

    diskutil_metrics = [[ metric_ns, "DiskUtil", "Instance ID", instance_id ]]
    widgets.append(get_line_widget(False, diskutil_metrics, region))

    sessutil_metric = [[ metric_ns, "FlowSessionUtil", "Instance ID", instance_id ]]
    widgets.append(get_line_widget(False, sessutil_metric, region))

    for ge_id in range(ge_interface_num):
        gepps_metrics = []
        metric_name = "Ge00%dInputPPS" % ge_id
        gepps_metrics.append([metric_ns, metric_name, "Instance ID", instance_id])
        metric_name = "Ge00%dOutputPPS" % ge_id
        gepps_metrics.append([metric_ns, metric_name, "Instance ID", instance_id])
        widgets.append(get_line_widget(True, gepps_metrics, region))
        gekbps_metrics = []
        metric_name = "Ge00%dInputKBPS" % ge_id
        gekbps_metrics.append([metric_ns, metric_name, "Instance ID", instance_id])
        metric_name = "Ge00%dOutputKBPS" % ge_id
        gekbps_metrics.append([metric_ns, metric_name, "Instance ID", instance_id])
        widgets.append(get_line_widget(True, gekbps_metrics, region))

    dashboard_name = 'vsrx_%s' % instance_id
    create_or_update_dashboard(session, region, dashboard_name, widgets)
    info_msg("Created CloudWatch dashboard %s" % dashboard_name)


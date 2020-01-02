import sys 
import os
import boto3
import click
import json
from operator import attrgetter
from tabulate import tabulate
from dateutil.parser import parse
import datetime

@click.command()
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
@click.option('--json', 'json_output', is_flag=True, help='Display with JSON format')
def images(profile, region, json_output):
    """List vSRX images in AWS marketplace"""
    if profile != None:
        session = boto3.Session(profile_name=profile)
    else:
        session = boto3.Session()
    if region != None:
        client = session.client('ec2', region_name=region)
    else:
        client = session.client('ec2')
    image_owner = ['aws-marketplace']
    image_filter = [
        {
            'Name':'name',
            'Values':[
                '*vsrx3*'
            ]
        }
    ]
    response = client.describe_images(Owners = image_owner, Filters = image_filter)
    if 'Images' not in response:
        sys.exit('error get vSRX images from AWS marketplace')
    images = response['Images']
    images = sorted(images, key=lambda k: k['CreationDate'])
    if json_output == True:
        print json.dumps(images, indent = 4)
    else:
        table = []
        table.append(['IMAGE_ID', 'DESCRIPTION', 'CREATION_DATE', 'ARCHITECTURE'])
        for image in images:
            creation_datetime = parse(image['CreationDate'])
            table.append([image['ImageId'], image['Description'], creation_datetime, image['Architecture']])
        print(tabulate(table, headers="firstrow",  tablefmt="grid"))


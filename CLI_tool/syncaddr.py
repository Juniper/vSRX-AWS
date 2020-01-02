import os
import sys
import boto3
import click

def get_all_security_groups():
    pass
  
@click.command()
@click.option('--security-group', '-g', multiple=True, help='The ID of security group')
@click.option('--profile', help='Use a specific profile from credential file')
@click.option('--region', default='us-east-1', help='Specify AWS region', show_default=True)
@click.argument('instance-id')
def syncaddr(instance_id, security_group, profile, region):
    """Synchronize vSRX dynamic address from AWS security group"""
    session = boto3.Session(profile_name=profile, region_name=region)
    client = session.client('ec2')
    ec2 = session.resource('ec2')
    for group in ec2.security_groups.all():
        print group.id

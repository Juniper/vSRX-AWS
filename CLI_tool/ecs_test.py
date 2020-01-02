import os
import sys
import boto3

def register_addrsync_task(client, image, name, role_arn, log_group, region):
    definition = {}
    definition['family'] = 'addrsync-task-definition'
    definition['networkMode'] = 'awsvpc'
    definition['requiresCompatibilities'] = ['FARGATE']
    definition['cpu'] = '256'
    definition['memory'] = '512'
    definition['executionRoleArn'] = role_arn
    container = {}
    container['essential'] = True
    container['image'] = image
    container['name'] = name
    container['logConfiguration'] = {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group" : log_group,
            "awslogs-region": region,
            "awslogs-stream-prefix": "ecs"
        }
    }
    container['portMappings'] = [
        {
            "containerPort": 80, 
             "hostPort": 80,
             "protocol": "tcp"
        }
    ]
    definition['containerDefinitions'] = [container]
    response = client.register_task_definition(**definition)
    print response

def run_addrsync_task(client, task_name, vpc_id, groups, 
                interval, role_arn, subnet, security_group):
    task = {}
    task['taskDefinition'] = 'addrsync-task-definition'
    command = ['ipprobe', '-d', '/var/lib/nginx/html', '-i', str(interval)]
    if groups != None:
        for sg in groups:
            command.append('-g')
            command.append(sg)
    command.append(vpc_id)
    task['overrides'] = {
        'containerOverrides': [{
            'name': task_name,
            'command': command,
            'cpu': 256,
            'memory':512
        }],
        'taskRoleArn': role_arn
    }
    task['count'] = 1
    task['launchType'] = 'FARGATE'
    task['networkConfiguration'] = {
        'awsvpcConfiguration': {
            'subnets': [
                subnet
            ],
            'securityGroups': [
                security_group
            ],
            'assignPublicIp': 'ENABLED'
        }
    }
    response = client.run_task(**task)
    print response

session = boto3.Session(profile_name='saml')
client = session.client('ecs')
"""
register_addrsync_task(client, '<account_ID>.dkr.ecr.us-east-1.amazonaws.com/addrsync:latest',
      'addrsync', '<arn_of_role>',
      'addrsync', 'us-east-1')
"""
run_addrsync_task(client, 'addrsync', 'vpc-068c35a6409a957eb',
        None, 15, '<arn_of_role>', 
     'subnet-0fa27de913ebab9ae', 'sg-067f30261c90c73e4')


#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

"""S3 utils"""
import logging as log

import boto3
from botocore.exceptions import ClientError

from gd_threatfeed.errors import CloudFeedsError


def upload_data_to_s3(bucket: str, content: bytes, path: str):
    """
    Upload data to S3 storage

    :param bucket: Customer Bucket
    :param content: Feed content
    :param path: Feed path
    """
    try:
        s3_resource = boto3.resource('s3')
        obj = s3_resource.Object(bucket, path)
        obj.put(Body=content)
    except ClientError as exc:
        log.error("Error while uploading content to s3 %s", str(exc))
        raise CloudFeedsError('Failed to upload content in path %s' % path)


def download_to_memory(bucket: str, path: str):
    """Download s3 file into memory

    :param bucket: Customer Bucket
    :param path: File path
    """
    try:
        s3_resource = boto3.resource('s3')
        obj = s3_resource.Object(bucket, path)
        body = obj.get()['Body'].read()
        return body
    except ClientError as exc:
        if exc.response['Error']['Code'] != 'NoSuchKey':
            log.error("Error while downloading file: %s", str(exc))
            raise CloudFeedsError('Failed to download file %s' % path)


def download_manifest(bucket: str, path: str):

    """Download the manifest to memory
    :param bucket: Customer Bucket
    :param path: File path
    """

    body = download_to_memory(bucket, path)
    if not body:
        return b'<manifest></manifest>'
    return body

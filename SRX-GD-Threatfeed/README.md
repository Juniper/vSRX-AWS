

# SRX-GD-ThreatFeed  Overview

Amazon Web Services (AWS) GuardDuty is a continuous security monitoring service that identifies unexpected, potentially unauthorized, and malicious activity within your AWS environment. The `SRX-GD-Threatfeed` is an AWS Lamda function that sends threats detected by the AWS Guard Duty as a security feed to the VSRX firewalls in your AWS environment. The vSRX firewalls can access the feeds either by directly downloading it from the AWS S3 bucket, or if the firewall device is enrolled with ATP Cloud, the feed is pushed to the firewall device along with the ATP Cloud security intelligence (SecIntel) feeds. In turn, the vSRX firewall enables you to take actions on the feed and block or log connections to the threat sources identified in the feed.

The threats are sent as a security feed to the SRX Series devices in the your AWS environment. The device can access the feeds either by directly downloading it from the AWS S3 bucket or, if the SRX Series device is enrolled with Juniper ATP Cloud, the feed is pushed to the device along with the security intelligence (SecIntel) feeds.
For more information, see [Integrate AWS GuardDuty with vSRX Firewalls.](https://www.juniper.net/documentation/en_US/release-independent/sky-atp/topics/topic-map/sky-atp-guardduty-srx-integration.html)

## Prerequisite Knowledge
Installing and configuring the  `SRX-GD-ThreatFeed` requires knowledge of the following:

  - AWS GuardDuty, Lambda function, S3 bucket, DynamoDB and IAM

## Dependency third party packages

The following python packages are included in Pre-packaged ZIP file.

    attrs
    certifi
    chardet
    configparser
    contextlib2
    functools32
    idna
    importlib_metadata
    jsonschema
    pathlib2
    pyrsistent
    requests
    scandir
    setuptools
    six
    urllib3
    zipp

## Installation

For detailed installation steps, see [Integrate AWS GuardDuty with vSRX Firewalls.](https://www.juniper.net/documentation/en_US/release-independent/sky-atp/topics/topic-map/sky-atp-guardduty-srx-integration.html)

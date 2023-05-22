#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

from setuptools import setup, find_packages


with open('README.md') as f:
    readme = f.read()

with open('LICENSE') as f:
    license = f.read()

install_requires = [
    'requests==2.31.0',
    'jsonschema==3.2.0'
    ]

setup(
    name='guardduty',
    version='0.1.0',
    description='GuardDuty Package',
    long_description=readme,
    author='Juniper Cloud Security Services',
    author_email='secint-aws-guardduty@juniper.net',
    license=license,
    packages=find_packages(exclude=('tests', )),
    install_requires=install_requires,
)


#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

"""Constants for Gaurdduty"""

CC_TTL = 3456000  # 40 days
MIN_TTL = 86400  # 1 day
MAX_TTL = 31556952  # 1 year
UPDATE_INTERVAL = 300  # 30 minutes
MAX_UPDATE_INTERVAL = 86400  # 1 Day
DEFAULT_MANIFEST_UPDATE_INTERVAL = 60  # 1 minute
DEFAULT_MAX_ENTRIES = 10000
MIN_MAX_ENTRIES = 1000
MAX_MAX_ENTRIES = 100000
DEFAULT_SEVERITY_LEVEL = 8

DATA_TAG_ADD_N = b'#add\n'
DATA_TAG_DEL_N = b'#del\n'
DATA_TAG_END_N = b'#end\n'

IP_ADDR = 'ip_addr'
DOMAIN = 'dn'
THREAT_LEVEL = 'threat_level'
PROP = 'properties'
MANIFEST_FILE_NAME = 'manifest.xml'
IP_FEED = 'ip'
DNS_FEED = 'domain'

CC_CATEGORY = 'CC'
CC_DESC = 'Command and Control data schema'
CC_SCHEMA_VER = 'c66b370237'

OBJ_CODES = {IP_ADDR: 4, DOMAIN: 1, PROP: 8, THREAT_LEVEL: 9}
IP_OBJ_FIELDS = (IP_ADDR, THREAT_LEVEL)
URL_OBJ_FIELDS = (DOMAIN, THREAT_LEVEL)

ACTIONS_PATH = {'NETWORK_CONNECTION': ('networkConnectionAction.'
                                       'remoteIpDetails.ipAddressV4', IP_ADDR),
                'AWS_API_CALL': ('awsApiCallAction.remoteIpDetails.ipAddressV4',
                                 IP_ADDR),
                'DNS_REQUEST': ('dnsRequestAction.domain', DOMAIN),
                'PORT_PROBE': ('portProbeAction.portProbeDetails.*.'
                               'remoteIpDetails.ipAddressV4', IP_ADDR)}


OPEN_API_CC_URL = 'cc/file/{feed_type}/{feed_name}'

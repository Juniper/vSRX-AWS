
#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

"""Schema for Guardduty configuration"""

from gd_threatfeed import constants as const

SKY_CONF_SCHEMA = {
    'title': 'Guardduty configuration with SkyATP license',
    'type': 'object',
    'properties': {
        'token': {'type': 'string', 'title': 'Sky ATP token for Open API'},
        'base_url': {'type': 'string', 'title': 'OpenAPI base url'}
    },
    'required': ['token', 'base_url'],
}

NON_SKY_CONF_SCHEMA = {
    'title': 'Guardduty configuration without SkyATP license',
    'type': 'object',
    'properties': {
        'bucket': {'type': 'string', 'title': 'AWS S3 bucket name'},
        'feed_ttl': {'type': 'integer', 'title': 'CC category feeds TTL',
                     'minimum': const.MIN_TTL, 'maximum': const.MAX_TTL,
                     'default': const.CC_TTL},
        'update_interval': {'type': 'integer',
                            'title': 'Feed update interval',
                            'minimum': const.UPDATE_INTERVAL,
                            'maximum': const.MAX_UPDATE_INTERVAL,
                            'default': const.UPDATE_INTERVAL},
        'max_entries': {'type': 'integer', 'title': 'Max feed entries for feed',
                        'minimum': const.MIN_MAX_ENTRIES,
                        'maximum': const.MAX_MAX_ENTRIES,
                        'default': const.DEFAULT_MAX_ENTRIES}

    },
    'required': ['bucket', 'feed_ttl', 'update_interval', 'max_entries'],
}


CONF_SCHEMA = {
    '$schema': 'http://json-schema.org/draft-04/schema#',
    'title': 'Guaudduty configuration',
    'type': 'object',
    'properties': {
        'severity': {'type': 'integer', 'title': 'Guard duty event severity',
                     'minimum': 1, 'maximum': 10, 'default': 4},
        'feed_type': {'enum':  ['ip_addr', 'dn'], 'title': 'Feed type'}},
    'required': ['severity', 'feed_type'],
    'oneOf': [SKY_CONF_SCHEMA, NON_SKY_CONF_SCHEMA],
    'anyOf': [
        {'ip_feed': {'type': 'string', 'title': 'IP feed name',
                     'pattern': '^[a-zA-Z0-9\\_]{8,64}$'}},
        {'dns_feed': {'type': 'string', 'title': 'DNS feed name',
                      'pattern': '^[a-zA-Z0-9\\_]{8,64}$'}}
    ],
    'additionalProperties': True,
}

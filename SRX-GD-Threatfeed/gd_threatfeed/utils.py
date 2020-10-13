#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

"""Common utils"""
import os
import time
import logging as log
from functools import wraps

import jsonschema

from gd_threatfeed import constants as const
from gd_threatfeed import config

NUM_RETRIES = 5
INITIAL_SLEEP_TIME = 5


def _gen_dict_extract(target: str, var: dict):
    """Looks for a key in a nested dictionary.
    """
    if hasattr(var, 'items'):
        for key, value in var.items():
            if key == target:
                yield value
            if isinstance(value, dict):
                yield from _gen_dict_extract(target, value)
            elif isinstance(value, list):
                for item in value:
                    yield from _gen_dict_extract(target, item)


def get_by_path(input_dict, nested_key):
    """Get the value based on nested keys"""
    internal_dict_value = input_dict
    for k in nested_key:
        internal_dict_value = internal_dict_value.get(k, None)
        if internal_dict_value is None:
            log.warning("Invalid path: %s", ".".join(nested_key))
            return None
    return internal_dict_value


def get_event_details(data: dict, path: str, ftype: str):
    """
    Get event info

    :param data: Event dictionary
    :param path: Action path
    :param ftype: Feed type
    """
    res = set()
    log.debug("Get action data for action type = %s", data['actionType'])
    keys = path.split(".")
    if '*' in keys:
        split_idx = keys.index('*')
        parent, child = keys[:split_idx], keys[split_idx + 1:]
        val = get_by_path(data, parent)
        if isinstance(val, list):
            for item in val:
                val = get_by_path(item, child)
                if ftype == const.IP_ADDR:
                    log.debug('Received IP V4 address %s', val)
                    res.add((const.IP_ADDR, val, const.THREAT_LEVEL, 10))
                else:
                    log.debug('Received Domain %s', val)
                    res.add((const.DOMAIN, val, const.THREAT_LEVEL, 10))
        else:
            log.warning("Invalid path: %s ", path)
    else:
        val = get_by_path(data, keys)
        if ftype == const.IP_ADDR:
            log.debug('Received IP V4 address %s', val)
            res.add((const.IP_ADDR, val, const.THREAT_LEVEL, 10))
        else:
            log.debug('Received Domain %s', val)
            res.add((const.DOMAIN, val, const.THREAT_LEVEL, 10))
    return res


def validate_args(conf):
    """Validate arguments based on configuration"""
    try:
        jsonschema.validate(conf, config.CONF_SCHEMA)
    except jsonschema.ValidationError as err:
        log.error("Invalid Guardduty configuration: %s", str(err))
        return False
    return True


def validate_event(event, ftype, conf):
    """Validate event based on configuration"""
    valid = False
    if event['detail']['severity'] < conf['severity']:
        log.info('Ignoring event lesser than set threshold %d',
                 conf['severity'])
    elif ftype == const.IP_ADDR and not conf['ip_feed']:
        log.info("Ignoring ip feed event as its not configured")
    elif ftype == const.DOMAIN and not conf['dns_feed']:
        log.info("Ignoring domain feed event as its not configured")
    else:
        valid = True
    return valid


def retry_status(status):
    """Retry API call based on status value"""
    def wrapper(func):
        @wraps(func)
        def func_wrapper(*args, **kwargs):
            retries_left = NUM_RETRIES
            sleep_time = INITIAL_SLEEP_TIME
            resp, code = func(*args, **kwargs)
            while code == status and retries_left > 0:
                retries_left -= 1
                log.info("Retry status response %s, %d", resp, code)
                log.info('Retry status left %d and sleeping %d sec before make '
                         'another try', retries_left, sleep_time)
                time.sleep(sleep_time)
                sleep_time *= 2
                resp, code = func(*args, **kwargs)
            return resp, code
        return func_wrapper
    return wrapper


def get_lambda_config():

    conf = {'ip_feed': os.environ.get('IP_FEED'),
            'dns_feed': os.environ.get('DNS_FEED')}
    conf['severity'] = int(os.environ.get('SEVERITY_LEVEL',
                                          const.DEFAULT_SEVERITY_LEVEL))
    base_url = os.environ.get('SKY_OPENAPI_BASE_PATH')
    if base_url:
        conf['base_url'] = base_url
        conf['token'] = os.environ.get('SKY_APPLICATION_TOKEN')
    else:
        conf.update({'bucket': os.environ.get('S3_BUCKET'),
                     'feed_ttl': int(os.environ.get('FEED_TTL', const.CC_TTL)),
                     'update_interval': int(os.environ.get('FEED_UPDATE_INTERVAL',
                                                       const.UPDATE_INTERVAL)),
                     'max_entries': int(os.environ.get('MAX_ENTRIES',
                                                   const.DEFAULT_MAX_ENTRIES))})
    return conf

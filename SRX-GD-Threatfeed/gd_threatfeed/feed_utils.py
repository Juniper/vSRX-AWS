#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

"""Feed utils"""

import hashlib
import json
import ipaddress
import time
import itertools
import logging as log
from types import GeneratorType
from collections import namedtuple, OrderedDict
from xml.etree import ElementTree
from xml.dom import minidom


from gd_threatfeed import constants as const
from gd_threatfeed.errors import CloudFeedsError, IncorrectVersionError
from gd_threatfeed import s3_utils

FeedVersion = namedtuple('FeedVersion', 'major minor')


class FeedInfo:
    """Feed Info container.
    """

    def __init__(self, category=None, name=None, feed_type=None,
                 schema_version=const.CC_SCHEMA_VER, **kwargs):
        self.category = category
        self.name = name
        self.feed_type = feed_type
        self.schema_version = schema_version
        self.version = kwargs.get('version', None)
        self.content = kwargs.get('content', list())
        self.data_ts = kwargs.get('data_ts', int(time.time()))
        self.objects = kwargs.get('objects', None)

    def __repr__(self):
        return '{}:{}:{}:{}:{}'.format(self.category, self.name, self.feed_type,
                                       self.schema_version, self.version)


def get_feed_metadata(category: str, bucket: str, feed_name: str, feed_type: str):
    """Get feed metadata

    :param bucket: Customer S3 Bucket
    :param category: Feed category
    :param feed_name: Feed name
    :param feed_type: Feed type
    """
    feed = None
    try:
        body = s3_utils.download_manifest(bucket, const.MANIFEST_FILE_NAME)
        body = body.decode('latin1')
        root = ElementTree.fromstring(body)

        for f_node in root.iterfind(
                'category/feed[@name="{}"]'.format(feed_name)):
            meta = dict(category=category, schema_version=const.CC_SCHEMA_VER,
                        feed_type=feed_type)
            meta.update(**f_node.attrib)
            feed = FeedInfo(**meta)
            break
    except Exception as exc:
        log.error("Error while parsing manifest: %s", str(exc))
        raise CloudFeedsError('Failed to parse manifest')
    return feed


def get_prev_feed_data(bucket: str, feed_name: str):
    """Get the previous feed if exists

    :param bucket: Customer S3 Bucket
    :param feed_name: Feed name"""
    body = s3_utils.download_to_memory(bucket, feed_name)
    body = body.decode()
    _, body = body.split('\n', 1)
    res = {obj.strip().encode('latin1')
           for obj in body.split('\n') if obj and obj[0] == '{'}
    return res


def encode_plain_object(plain_obj):
    """Encode plain object.

    :param list|tuple plain_obj: A plain object to encode.
    """
    json_encode = json.JSONEncoder(sort_keys=True, separators=(',', ':')).encode
    props = {}
    res = {}
    tup_iter = iter(plain_obj)
    for tup in tup_iter:
        value = next(tup_iter)
        tup_c = const.OBJ_CODES.get(tup)
        if tup == const.THREAT_LEVEL:
            props[tup_c] = value
        else:
            if tup == const.IP_ADDR:
                try:
                    value = int(ipaddress.IPv4Address(value))
                except ValueError as err:
                    log.error("Invalid IP : %s", str(err))
            res[tup_c] = value
    if res:
        if props:
            prop_code = const.OBJ_CODES.get('properties')
            res[prop_code] = props
        return json_encode(res).encode('latin1')
    return None


def make_feed(feed_lines: list, version: str, schema_version: str,
              prev_version: str = None) -> GeneratorType:
    """Generate feed content.

    :param feed_lines: Items to be added.
    :param version: Feed version.
    :param schema_version: Data schema version.
    :param prev_version: previous feed version.
    """
    md5_sum = hashlib.md5()
    md5_sum_update = md5_sum.update

    def _md5_line(line: bytes):
        """Encode line to bytes updating md5 hash.
        """
        md5_sum_update(line)
        return line

    header = json.dumps({
        'version': version,
        'previous_version': prev_version,
        'schema_version': schema_version,
        'filter': {}}, separators=(',', ':'), sort_keys=True) + '\n'

    yield _md5_line(header.encode('latin1'))

    yield _md5_line(const.DATA_TAG_DEL_N)

    yield _md5_line(const.DATA_TAG_ADD_N)
    for line in feed_lines:
        yield _md5_line(line + b'\n')

    # End and checksum.
    yield _md5_line(const.DATA_TAG_END_N)
    yield (md5_sum.hexdigest() + '\n').encode('latin1')


def make_full_feed(feed: FeedInfo):
    """Make full feed data file.

    :param feed: Feed info object.
    """
    return b''.join(make_feed(feed.content, feed.version,
                              feed.schema_version))


def parse_version(version: str) -> FeedVersion:
    """Parse feed version
    Examples:
      '394480312.4' -> ('394480312.4')

    :param str version: Complex data version.
    :rtype: FeedVersion
    """

    if version is None:
        return FeedVersion(None, None)
    try:
        cv_split = version.split('.', 2)
        major, minor = cv_split
        return FeedVersion(major, minor)
    except (IndexError, ValueError, TypeError):
        raise IncorrectVersionError('Wrong version %s' % version)


def feed_next_version(prev_version: str = None):
    """Generates a new file version base on a previous one.

    :param prev_version: previous version
    """
    gmt = time.gmtime()
    cur_gmv = '%04d%02d%02d' % (gmt.tm_year, gmt.tm_mon, gmt.tm_mday)

    if not prev_version:
        return cur_gmv + '.1'

    prev_fv = parse_version(prev_version)
    if int(prev_fv.major) < int(cur_gmv):
        return cur_gmv + '.1'
    return '{}.{}'.format(prev_fv.major, int(prev_fv.minor) + 1)


def publish_object(category: str, feed_name: str, feed_type: str, in_data: set,
                   conf: dict):
    """
    Publish the content in S3

    :param category: Feed Category
    :param feed_name: Feed Name
    :param feed_type: Feed Type
    :param in_data: Feed content
    :param conf: Lambda config
    """
    res = None
    last_feed = get_feed_metadata(category, conf['bucket'], feed_name, feed_type)
    cur_feed = FeedInfo(category=category, name=feed_name,
                        schema_version=const.CC_SCHEMA_VER, feed_type=feed_type)
    for line in in_data:
        if line:
            enc_str = encode_plain_object(line)
            if enc_str is not None:
                cur_feed.content.append(enc_str)
    if not cur_feed.content and not last_feed:
        log.info('Empty feed content')
        res = None
    elif not cur_feed.content:
        log.info("There is no new %s found", feed_type)
        res = last_feed
    else:
        if last_feed:
            last_feed.content = get_prev_feed_data(conf['bucket'], feed_name)
            if set(last_feed.content).issubset(set(cur_feed.content)):
                log.info(
                    "New feed content is subset of existing content so "
                    "updating manifest with latest time")
                last_feed.data_ts = int(time.time())
                res = last_feed
        if not res:
            log.info("New %s feed count %d", feed_type, len(cur_feed.content))
            cur_feed.version = feed_next_version(
                last_feed and last_feed.version)
            if last_feed:
                log.info("Old %s feed count = %d", feed_type,
                         len(last_feed.content))
                cur_feed.content = list(OrderedDict.fromkeys(itertools.chain(
                    last_feed.content, cur_feed.content)))
            if len(cur_feed.content) > conf['max_entries']:
                diff = len(cur_feed.content) - conf['max_entries']
                log.info("Feed %s has reached max limit of %d", feed_name,
                         conf['max_entries'])
                cur_feed.content = cur_feed.content[diff:]
                log.info("Removed %d old entries from feed", diff)

            cur_feed.objects = len(cur_feed.content)

            feed_content = make_full_feed(cur_feed)
            s3_utils.upload_data_to_s3(conf['bucket'], feed_content, feed_name)
            res = cur_feed
            log.info("Total %s count %d", feed_type, len(cur_feed.content))
    return res


def create_manifest(feeds, conf):
    """
    Create manifest XML

    :param feeds: List of Feed Info Object
    :param conf: Lambda configuration
    """
    dom = minidom.Document()
    manifest_node = dom.createElement('manifest')
    manifest_node.setAttribute('update_interval',
                               str(const.DEFAULT_MANIFEST_UPDATE_INTERVAL))
    dom.appendChild(manifest_node)
    cat_node = dom.createElement('category')
    cat_node.setAttribute('options', '')
    cat_node.setAttribute('name', const.CC_CATEGORY)
    cat_node.setAttribute('description', const.CC_DESC)
    cat_node.setAttribute('ttl', str(conf['feed_ttl']))
    cat_node.setAttribute('update_interval', str(conf['update_interval']))

    config_node = dom.createElement('config')
    config_node.setAttribute('version', const.CC_SCHEMA_VER)

    c_url_node = dom.createElement('url')
    c_url_node.appendChild(dom.createTextNode('/cc_schema'))
    config_node.appendChild(c_url_node)
    cat_node.appendChild(config_node)
    for feed in feeds:
        if not feed:
            continue
        feed_node = dom.createElement('feed')
        feed_node.setAttribute('name', feed.name)
        feed_node.setAttribute('data_ts', str(feed.data_ts))
        feed_node.setAttribute('objects', str(feed.objects))
        feed_node.setAttribute('version', str(feed.version))
        feed_node.setAttribute('options', '')
        types = None
        if feed.feed_type == const.IP_ADDR:
            types = sorted(const.IP_OBJ_FIELDS)
        elif feed.feed_type == const.DOMAIN:
            types = sorted(const.URL_OBJ_FIELDS)
        feed_node.setAttribute('types', ' '.join(sorted(types)))
        feed_node.setAttribute('ttl', str(conf['feed_ttl']))
        feed_node.setAttribute('update_interval', str(conf['update_interval']))

        data_node = dom.createElement('data')
        d_url_node = dom.createElement('url')
        d_url_node.appendChild(dom.createTextNode("/" + feed.name))
        data_node.appendChild(d_url_node)
        feed_node.appendChild(data_node)
        cat_node.appendChild(feed_node)

    manifest_node.appendChild(cat_node)
    manifest_xml = dom.toprettyxml(indent='  ')
    ver = hashlib.md5(manifest_xml.encode('latin1')).hexdigest()
    manifest_xml = manifest_xml.replace(
        '<manifest', '<manifest version="%s"' % ver, 1)
    return manifest_xml

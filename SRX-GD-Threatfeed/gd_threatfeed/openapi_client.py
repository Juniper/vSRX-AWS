#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

"""Client to interact with OpenAPI API's"""
import os
import json
import logging

from requests import Session
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from gd_threatfeed import errors
from gd_threatfeed import utils

SUPPORTED_PROTOCOLS = {'HTTP', 'HTTPS'}
RETRY_CFG = {'total': 3, 'backoff_factor': 0.3,
             'status_forcelist': (500, 502, 503, 504), 'raise_on_status': True}
OPEN_API_CC_URL = 'cc/file/{feed_type}/{feed_name}'


class OpenAPIClient:
    """Client for OpenAPI"""

    def __init__(self, base_url, token):
        self.base_url = base_url
        self.token = token

    def _make_request(self, method: str, url: str, params: dict=None,
                      data: dict=None, files: dict=None):
        """Make HTTP request to the API server.

        :param method: HTTP method.
        :param url: Partial URL .
        :param params: Dictionary to be sent as the query string.
        :param data:  Dictionary to send as the body of the request.
        :param files: Files to send.

        """
        with Session() as session:
            full_url = os.path.join(self.base_url, url)
            logging.info("FULL URL %s", full_url)
            retries = Retry(**RETRY_CFG)
            headers = {'Authorization': self.token}
            openapi_adapter = HTTPAdapter(max_retries=retries)
            for protocol in SUPPORTED_PROTOCOLS:
                session.mount('%s://' % (protocol,), openapi_adapter)
            resp = session.request(method=method, url=full_url, params=params,
                                   data=data, headers=headers, files=files,
                                   verify=False)
            return resp.status_code, resp.headers, resp.content

    def _make_json_request(self, method: str, api_url: str, files: dict=None,
                           data: dict=None):
        """Make HTTP request to the API server. Parse JSON response body
        and return Python object.

        :param method: HTTP method.
        :param api_url: API URL
        :param data:  Dictionary to send as the body of the request.
        :param files: Files to send.
        """
        if data is not None:
            enc_data = {'params': json.dumps(data)}
            logging.info("Sending %s content to OpenAPI", enc_data)
        else:
            enc_data = None

        status, _, body = self._make_request(method, api_url, files=files,
                                             data=enc_data)
        return json.loads(body), status

    def is_feed_exists(self, feed_type: str, feed_name: str):
        """
        Check whether the feed is exist or not
        :param feed_type: Feed type
        :param feed_name: Feed name
        """
        url = OPEN_API_CC_URL.format(feed_type=feed_type, feed_name=feed_name)
        resp, _ = self._make_json_request('GET', url)
        logging.info("Feed exists API response %s", resp)
        return resp

    def upload_custom_feed(self, feed_type: str, feed_name: str,
                           feed_content: str):
        """Upload a custom feed to the Cloud Feeds server.
        :param feed_type: Feed type
        :param feed_name: Feed name
        :param feed_content: Feed content
        """
        url = OPEN_API_CC_URL.format(feed_type=feed_type, feed_name=feed_name)
        resp, _ = self.is_feed_exists(feed_type, feed_name)
        if 'err_id' not in resp and 'message' in resp:
            logging.info("Set http request method to PATCH")
            http_method = 'PATCH'
        elif 'err_id' in resp:
            http_method = 'POST'
            logging.info("Set http request method to POST")
        else:
            raise errors.CloudFeedsError("Invalid feed status")
        return self.upload_custom_feed_helper(http_method, url,
                                              files={'file': feed_content})

    @utils.retry_status(409)
    def upload_custom_feed_helper(self, method: str, url: str, files: dict):
        """Upload feed helper function
        :param method: Http method
        :param url: API URL
        :param files: File dictionary"""
        return self._make_json_request(method, url, files=files)

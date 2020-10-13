#  Copyright ©  2020 Juniper Networks, Inc., All Rights Reserved.

class CloudFeedsError(Exception):
    """Base error"""


class IncorrectVersionError(CloudFeedsError):
    """Wrong feed version detected."""

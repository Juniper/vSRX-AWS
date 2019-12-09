locals {
  parameters = {
    SshPublicKey          = "${file(var.public_key_path)}"
    JuniperConfigSecurityGroup = "${aws_security_group.JuniperConfigSecurityGroup.id}"
    AllowedSshIpAddress   = "${var.allowed_ssh_ipadd}"
    TerminationProtection = "${var.enable_term_protection}"
    TransitVPC            = "${aws_vpc.tvpc.id}"
    VPCPubSub11           = "${aws_subnet.VPCPubSub11.id}"
    vSRXInterface11PvtIP  = "${element(aws_network_interface.vSRXInterface11.private_ips,0)}"
    VPCPubSub21           = "${aws_subnet.VPCPubSub21.id}"
    vSRXInterface21PvtIP  = "${element(aws_network_interface.vSRXInterface21.private_ips,0)}"
    PubSubnet12           = "${var.pub_data_subnet_az1}"
    PubSubnet22           = "${var.pub_data_subnet_az2}"
    vSRXEip11             = "${aws_eip.vsrx1_data_eip.public_ip}"
    vSRXEip21             = "${aws_eip.vsrx2_data_eip.public_ip}"
    VSRXType              = "${var.vsrx_ec2_type}"
    PreferredPathTag      = "${var.preferred_path_tag}"
    SpokeTag              = "${var.vpc_spoke_tag}"
    SpokeTagValue         = "${var.vpc_spoke_tag_value}"
    BgpAsn                = "${var.bgp_asn}"
    S3Prefix              = "${var.s3_prefix_key_names}"
    AccountId             = "${var.accountid}"
  }

  params = {
    bogus = "bogus"
  }
}

locals {
  keys =   ["${split(",", var.primary_region ? join(",", keys(local.parameters)) : join(",", keys(local.params)))}"]
  values = ["${split(",", var.primary_region ? join(",", values(local.parameters)) : join(",", values(local.params)))}"]
}

resource "aws_cloudformation_stack" "lambdas" {
  name         = "akbhat-transit-vpc-lambdas"
  capabilities = ["CAPABILITY_IAM"]

#  parameters = "${var.primary_region ? local.parameters : local.params}"
  parameters = "${zipmap(local.keys,local.values)}"
#  parameters = "${zipmap(coalescelist(local.keys),coalescelist(local.values))}"


  template_body = "${var.primary_region ? file(var.cf_template) : file("bogus.template")}"

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

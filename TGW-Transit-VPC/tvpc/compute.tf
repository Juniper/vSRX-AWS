data "aws_ami" "vsrx3_ami" {
  most_recent = true
  owners = ["679593333241", "298183613488"]

  filter {
    name   = "name"
    values = ["${var.ami_name_filter}"]
  }
}

resource "aws_eip" "vsrx1_data_eip" {
  vpc = true
}

resource "aws_eip" "vsrx2_data_eip" {
  vpc = true
}

resource "aws_eip" "vSRXEip12" {
  vpc = true
}

resource "aws_eip" "vSRXEip22" {
  vpc = true
}

# vSRX1 management public IP address
resource "aws_eip_association" "mgmt_eip_assoc_vsrx1" {
  network_interface_id = "${aws_network_interface.vSRXInterface11.id}"
  allocation_id        = "${aws_eip.vSRXEip12.id}"

  depends_on = ["aws_internet_gateway.igw"]
}

# vSRX2 management public IP address
resource "aws_eip_association" "mgmt_eip_assoc_vsrx2" {
  network_interface_id = "${aws_network_interface.vSRXInterface21.id}"
  allocation_id        = "${aws_eip.vSRXEip22.id}"

  depends_on = ["aws_internet_gateway.igw"]
}

# These are assigned to the vSRX if load balancing is disabled
# In case of LB, these IPs are assigned directly to the NLB
# TODO: When NLB supports IPSec
resource "aws_eip_association" "data_eip_assoc_vsrx1" {
#  count                = "${1 - var.enable_load_balancing}"
  network_interface_id = "${aws_network_interface.vSRXInterface12.id}"
  allocation_id        = "${aws_eip.vsrx1_data_eip.id}"

  depends_on = ["aws_internet_gateway.igw"]
}

resource "aws_eip_association" "data_eip_assoc_vsrx2" {
#  count                = "${1 - var.enable_load_balancing}"
  network_interface_id = "${aws_network_interface.vSRXInterface22.id}"
  allocation_id        = "${aws_eip.vsrx2_data_eip.id}"

  depends_on = ["aws_internet_gateway.igw"]
}

resource "aws_key_pair" "vsrx_key" {
  key_name   = "vsrx-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW3fBHRMTQ3CUxWUnYD2XmjNjO8J6T038rYqjzUCNTYbWWCbH9sfdBu/GJpnh207hEB+PzRpKJnhsvPogb/wNNi0KzarWoUPKtqt0VQkpZg4fsIUcscyFiR3cb9pzKR4UOJzQo7ZTO0ulKqFeyrmDHM89bFMcC6ATz5lIvO5ZNukdtZ1+gnKqTLMoq8VcPYIllnOFNTiEpQyr+COmLMjNN7CVRqCmAo0vIw2mNZpA2hk/Nmstv7gxEGch2VNdJw6nOIaO9XXX+DcJagPoyJsjeuVb0yKi/DmEgPTZXhAsZ9Sgv8/pdj0vDf3O/G2LelohJ315q1p5h4pL2HGbVrnbf akbhat@ubuntu"
}

data "template_file" "vsrx3-conf1" {
#  count    = "${1 - var.enable_auto_scaling}"
  template = "${file("vsrx3-init4.tpl")}"

  vars {
    SshPublicKey = "${trimspace("${file(var.public_key_path)}")}"
    PrimaryPrivateMgmtIpAddress = "${element(aws_network_interface.vSRXInterface12.private_ips,0)}"
    PrimaryPrivateIngressIpAddress = "${element(aws_network_interface.vSRXInterface13.private_ips,0)}"
    PrimaryPrivateEgressIpAddress  = "${element(aws_network_interface.vSRXInterface14.private_ips,0)}"
#    LambdaSshPublicKey  = "${var.primary_region ? format("%s %s", "ssh-rsa",aws_cloudformation_stack.lambdas.outputs["VSRXPUBKEY"]) : file(var.public_key_path)}"
    LambdaSshPublicKey  = "${var.primary_region ? format("%s %s", "ssh-rsa",aws_cloudformation_stack.lambdas.outputs["VSRXPUBKEY"]) : "ssh-rsa SAFETODELETE"}"
  }
}

data "template_file" "vsrx3-conf2" {
#  count    = "${1 - var.enable_auto_scaling}"
  template = "${file("vsrx3-init4.tpl")}"

  vars {
    SshPublicKey = "${trimspace("${file(var.public_key_path)}")}"
    PrimaryPrivateMgmtIpAddress = "${element(aws_network_interface.vSRXInterface22.private_ips,0)}"
    PrimaryPrivateIngressIpAddress = "${element(aws_network_interface.vSRXInterface23.private_ips,0)}"
    PrimaryPrivateEgressIpAddress  = "${element(aws_network_interface.vSRXInterface24.private_ips,0)}"
    LambdaSshPublicKey  = "${var.primary_region ? format("%s %s", "ssh-rsa",aws_cloudformation_stack.lambdas.outputs["VSRXPUBKEY"]) : trimspace(file(var.public_key_path))}"
  }
}

resource "aws_instance" "VpcvSRX1" {
#  count         = "${1 - var.enable_auto_scaling}"
  ami           = "${data.aws_ami.vsrx3_ami.id}"
  ebs_optimized = true
  instance_type = "c4.xlarge"
#  key_name      = "${aws_key_pair.vsrx_key.key_name}"
  disable_api_termination = false

  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface11.id}"
    device_index         = 0
  }
  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface12.id}"
    device_index         = 1
  }
  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface13.id}"
    device_index         = 2
  }
  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface14.id}"
    device_index         = 3
  }

  user_data_base64        = "${base64encode(data.template_file.vsrx3-conf1.rendered)}"
#  primary_network_interface_id =

  depends_on = ["aws_internet_gateway.igw"]

  lifecycle { create_before_destroy = true }

  tags = {
    Name = "Transit VPC VSRX1"
  }
}

resource "aws_instance" "VpcvSRX2" {
#  count         = "${1 - var.enable_auto_scaling}"
  ami           = "${data.aws_ami.vsrx3_ami.id}"
  ebs_optimized = true
  instance_type = "c4.xlarge"
#  key_name      = "${aws_key_pair.vsrx_key.key_name}"
  disable_api_termination = false

  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface21.id}"
    device_index         = 0
  }
  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface22.id}"
    device_index         = 1
  }
  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface23.id}"
    device_index         = 2
  }
  network_interface {
    network_interface_id = "${aws_network_interface.vSRXInterface24.id}"
    device_index         = 3
  }

  user_data        = "${base64encode(data.template_file.vsrx3-conf2.rendered)}"
#  primary_network_interface_id =

  depends_on = ["aws_internet_gateway.igw"]

  lifecycle { create_before_destroy = true }

  tags = {
    Name = "Transit VPC VSRX2"
  }
}

################ Additional Data Subnets ######################
resource "aws_subnet" "VPCPubSub11" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "${var.pub_mgmt_subnet_az1}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "VPCPubSub12" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "${var.pub_data_subnet_az1}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "VPCPubSub21" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "${var.pub_mgmt_subnet_az2}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_subnet" "VPCPubSub22" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "${var.pub_data_subnet_az2}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_subnet" "vsrx1_data_subnet2" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "10.10.50.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "vsrx2_data_subnet2" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "10.10.60.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_subnet" "vsrx1_data_subnet3" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "10.10.70.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "vsrx2_data_subnet3" {
  vpc_id     = "${aws_vpc.tvpc.id}"
  cidr_block = "10.10.80.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_route_table_association" "VSRX1IngressSubnet" {
  subnet_id      = "${aws_subnet.vsrx1_data_subnet2.id}"
  route_table_id = "${aws_route_table.VPCIngressTGWRouteTable.id}"
}

resource "aws_route_table_association" "VSRX2IngressSubnet" {
  subnet_id      = "${aws_subnet.vsrx2_data_subnet2.id}"
  route_table_id = "${aws_route_table.VPCIngressTGWRouteTable.id}"
}

resource "aws_route_table_association" "VSRX1EgressSubnet" {
  subnet_id      = "${aws_subnet.vsrx1_data_subnet3.id}"
  route_table_id = "${aws_route_table.VPCEgressTGWRouteTable.id}"
}

resource "aws_route_table_association" "VSRX2EgressSubnet" {
  subnet_id      = "${aws_subnet.vsrx2_data_subnet3.id}"
  route_table_id = "${aws_route_table.VPCEgressTGWRouteTable.id}"
}

resource "aws_network_interface" "vSRXInterface11" {
  subnet_id       = "${aws_subnet.VPCPubSub11.id}"
  source_dest_check = false
#  security_groups = ["${aws_cloudformation_stack.lambdas.outputs["VSRXSecurityGroup"]}"]
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

resource "aws_network_interface" "vSRXInterface12" {
  subnet_id       = "${aws_subnet.VPCPubSub12.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

resource "aws_network_interface" "vSRXInterface13" {
  subnet_id       = "${aws_subnet.vsrx1_data_subnet2.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

resource "aws_network_interface" "vSRXInterface14" {
  subnet_id       = "${aws_subnet.vsrx1_data_subnet3.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

resource "aws_network_interface" "vSRXInterface21" {
  subnet_id       = "${aws_subnet.VPCPubSub21.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

resource "aws_network_interface" "vSRXInterface22" {
  subnet_id       = "${aws_subnet.VPCPubSub22.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

resource "aws_network_interface" "vSRXInterface23" {
  subnet_id       = "${aws_subnet.vsrx2_data_subnet2.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

resource "aws_network_interface" "vSRXInterface24" {
  subnet_id       = "${aws_subnet.vsrx2_data_subnet3.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.VSRXSecurityGroup.id}"]
}

##### TVPC Ingress and Egress RT
resource "aws_route_table" "VPCIngressTGWRouteTable" {
  vpc_id = "${aws_vpc.tvpc.id}" 

  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = "${aws_network_interface.vSRXInterface13.id}"
  }
}

resource "aws_route_table" "VPCEgressTGWRouteTable" {
  vpc_id = "${aws_vpc.tvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = "${aws_ec2_transit_gateway.tvpc_tgw.id}"
  }
}

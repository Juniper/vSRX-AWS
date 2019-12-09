resource "aws_ec2_transit_gateway" "tvpc_tgw" {
  description = "TVPC TGW"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags = {
    "transitvpc:spoke" = "false"
  }
}

resource "aws_ec2_transit_gateway_route_table" "ingress" {
  transit_gateway_id = "${aws_ec2_transit_gateway.tvpc_tgw.id}"
  tags = {
    Name = "Ingress RT"
  }
}

resource "aws_ec2_transit_gateway_route_table" "egress" {
  transit_gateway_id = "${aws_ec2_transit_gateway.tvpc_tgw.id}"
  tags = {
    Name = "Egress RT"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tvpc_egress" {
  subnet_ids         = ["${aws_subnet.vsrx1_data_subnet2.id}",
                        "${aws_subnet.vsrx2_data_subnet2.id}"]
  transit_gateway_id = "${aws_ec2_transit_gateway.tvpc_tgw.id}"
  vpc_id             = "${aws_vpc.tvpc.id}" 
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tvpc_egress.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.egress.id}"
}

resource "aws_ec2_transit_gateway_route" "route_to_tvpc" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tvpc_egress.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.ingress.id}"
}

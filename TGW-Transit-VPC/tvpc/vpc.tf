provider "aws" {
  region = "${var.region}"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "tvpc" {
  cidr_block = "${var.vpc_cidr}"

  tags = {
    Name = "Transit VPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.tvpc.id}"

  tags = {
    Name = "Transit VPC IGW"
  }
}

resource "aws_route_table" "VPCRouteTable" {
  vpc_id = "${aws_vpc.tvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name = "Transit VPC"
  }
}

resource "aws_route_table_association" "VPCPubSubnetRouteTableAssociation1" {
  subnet_id      = "${aws_subnet.VPCPubSub11.id}"
  route_table_id = "${aws_route_table.VPCRouteTable.id}"
}

resource "aws_route_table_association" "VPCPubSubnetRouteTableAssociation2" {
  subnet_id      = "${aws_subnet.VPCPubSub12.id}"
  route_table_id = "${aws_route_table.VPCRouteTable.id}"
}

resource "aws_route_table_association" "VPCPubSubnetRouteTableAssociation3" {
  subnet_id      = "${aws_subnet.VPCPubSub21.id}"
  route_table_id = "${aws_route_table.VPCRouteTable.id}"
}

resource "aws_route_table_association" "VPCPubSubnetRouteTableAssociation4" {
  subnet_id      = "${aws_subnet.VPCPubSub22.id}"
  route_table_id = "${aws_route_table.VPCRouteTable.id}"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = "${aws_vpc.tvpc.id}"
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = ["${aws_route_table.VPCRouteTable.id}"]
  policy = <<EOF
    {
          "Version":"2012-10-17",
          "Statement":[{
            "Effect":"Allow",
            "Principal": "*",
            "Action":["s3:*"],
            "Resource":["*"]
          }]
    }
  EOF
}

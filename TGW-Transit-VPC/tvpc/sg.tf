data "aws_prefix_list" "private_s3" {
  prefix_list_id = "${aws_vpc_endpoint.private_s3.prefix_list_id}"
}

#TODO: S3 VPC endpoint already in main.tf
resource "aws_vpc_endpoint" "private_s3" {
  vpc_id       = "${aws_vpc.tvpc.id}"
  service_name = "com.amazonaws.${var.region}.s3"
}

resource "aws_security_group" "VSRXSecurityGroup" {
  name        = "TVPC vSRX SSH & ICMP"
  description = "Allow SSH & ICMP traffic"
  vpc_id      = "${aws_vpc.tvpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_ssh_ipadd}"] 
  }

  ingress {
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "icmp"
    cidr_blocks = ["${var.allowed_ssh_ipadd}"] 
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "JuniperConfigSecurityGroup" {
  name        = "TVPC Automation SG Rules"
  description = "Transit VPC Automation Security Group Rules"
  vpc_id      = "${aws_vpc.tvpc.id}"
}

resource "aws_security_group_rule" "SSHtoVSRXSecurityGroup" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"

  source_security_group_id = "${aws_security_group.JuniperConfigSecurityGroup.id}"
  security_group_id        = "${aws_security_group.VSRXSecurityGroup.id}"   
}

resource "aws_security_group_rule" "SSHtoVSRX" {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = "${aws_security_group.VSRXSecurityGroup.id}"
  security_group_id = "${aws_security_group.JuniperConfigSecurityGroup.id}"
}

resource "aws_security_group_rule" "HTTPSToVPCEndpoint" {
  type              = "egress"
  to_port           = 443
  from_port         = 443
  protocol          = "tcp"
  prefix_list_ids   = ["${aws_vpc_endpoint.private_s3.prefix_list_id}"]
  security_group_id = "${aws_security_group.JuniperConfigSecurityGroup.id}"
}

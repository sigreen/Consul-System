# This file creates a set of resources in both Azure and AWS Cloud environments
# It utilizes images created with HashiCorp's Packer with  Consul pre-installed
# Be sure to set your variables properly in terraform.tfvars
# In full disclosure, I'm not a programmer, but I was able to put this together with examples
# and docs found on the interwebs

#############################
# AWS Linux Instance Creation
#############################

provider "aws" {
  version = "~> 2.5"
  region  = local.aws_region
}

####################################
# Pull AMI ID from the Packer Ouptut
####################################
locals {
  aws_to_json    = jsondecode(file("Image-Creation/aws-manifest.json"))
  aws_pull_build = element(tolist(local.aws_to_json.builds), 0)
  aws_region     = element((split(":", local.aws_pull_build["artifact_id"])), 0)
  aws_ami_id     = element(reverse(split(":", local.aws_pull_build["artifact_id"])), 0)
}

####################################
# Create AWS FQDN in hashidemos zone
####################################
data "aws_route53_zone" "selected" {
  name         = "hashidemos.io."
  private_zone = false
}
resource "aws_route53_record" "fqdn" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.owner}-consul.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.consul-server[0].public_ip, aws_instance.consul-server[1].public_ip, aws_instance.consul-server[2].public_ip]
}

###############################
# Create AWS Network Components
###############################
resource aws_vpc "consul-demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.owner}-vpc"
  }
}
resource aws_subnet "consul-demo" {
  vpc_id     = aws_vpc.consul-demo.id
  cidr_block = var.vpc_cidr
  tags = {
    name = "${var.owner}-subnet"
  }
}
resource aws_security_group "consul-demo" {
  name   = "${var.owner}-security-group"
  vpc_id = aws_vpc.consul-demo.id
  # Hopefully we all know what these are for
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Required ports for Consul
  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # opening up 8161 for AMQ
  ingress {
    from_port   = 8161
    to_port     = 8161
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # opening up 5672 for AMQ
  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # opening up 61616 for AMQ
  ingress {
    from_port   = 61616
    to_port     = 61616
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Anything can leave, unlike Hotel California
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name = "${var.owner}-security-group"
  }
}

resource aws_internet_gateway "consul-demo" {
  vpc_id = aws_vpc.consul-demo.id

  tags = {
    Name = "${var.owner}-internet-gateway"
  }
}
resource aws_route_table "consul-demo" {
  vpc_id = aws_vpc.consul-demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.consul-demo.id
  }
}
resource aws_route_table_association "consul-demo" {
  subnet_id      = aws_subnet.consul-demo.id
  route_table_id = aws_route_table.consul-demo.id
}

#############################################################################
# AWS Server Cluster Creation
# Note, in production it is highly recommended to go with 5 or 7 server nodes
# Three nodes doesn't protect against region/zone failure
#############################################################################

resource aws_instance "consul-server" {
  count                       = 3
  ami                         = local.aws_ami_id
  instance_type               = var.instance_type
  key_name                    = var.aws_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.consul-demo.id
  vpc_security_group_ids      = [aws_security_group.consul-demo.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  # Using user_data/template file to setup Consul server configuration files
  user_data = templatefile("files/server_template.tpl", { server_name_tag = "${var.owner}-consul-server-instance"})
  tags = {
    Name  = "${var.owner}-consul-server-instance"
    Owner = var.owner_tag
    Instance = "${var.owner}-consul-server-instance-${count.index}"
  }
}

###################################################################
# AWS Linux Client Creation
# Four clients were chosen to represent Earth, Air, Fire, and Water
# Client count would be a variable in most real scenarios
###################################################################
resource aws_instance "consul-client" {
  count                       = 4
  ami                         = local.aws_ami_id
  instance_type               = var.instance_type
  key_name                    = var.aws_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.consul-demo.id
  vpc_security_group_ids      = [aws_security_group.consul-demo.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  tags = {
    Name  = "${var.owner}-consul-client-instance-${count.index}"
    Owner = var.owner_tag
  }
}

###################################################################
# AMQ Server to run the ActiveMQ server function
###################################################################
resource aws_instance "activemq-server" {
  ami                         = local.aws_ami_id
  instance_type               = var.instance_type
  key_name                    = var.aws_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.consul-demo.id
  vpc_security_group_ids      = [aws_security_group.consul-demo.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  tags = {
    Name  = "${var.owner}-amq-instance"
    Owner = var.owner_tag
  }
}

#############################################################
# We're using remote-exec to setup the client configurations.
# user_data is preferred, but this is an option
#############################################################
resource null_resource "provisioning-clients" {
  for_each = { for client in aws_instance.consul-client : client.tags.Name => client }
  # Consul Client Configuration
  provisioner "file" {
    source      = "files/httpd.json"
    destination = "/tmp/httpd.json"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cat << EOF > /tmp/consul-client.hcl",
      "advertise_addr = \"${each.value.public_ip}\"",
      "server = false",
      "enable_script_checks = true",
      "bind_addr = \"${each.value.private_ip}\"",
      "retry_join = [\"${aws_instance.consul-server[0].public_ip}\",\"${aws_instance.consul-server[1].public_ip}\",\"${aws_instance.consul-server[2].public_ip}\"]",
      "client_addr = \"${each.value.private_ip}\"",
 #     "node_meta = [\"${aws_instance.consul-server[0].public_ip}\"]"
      "EOF",
      "sudo mv /tmp/consul-client.hcl /etc/consul/consul.d/consul-client.hcl",
      "sudo mv /tmp/httpd.json /etc/consul/consul.d/httpd.json",
      "nohup python3 -m http.server 8080 &",
      "sleep 60"
    ]
  }
  provisioner "file" {
    source      = "files/httpd.json"
    destination = "/etc/consul/consul.d/httpd.json"
  }
  # Fire Up Services
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl start consul",
    ]
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_key)
    host        = each.value.public_ip
  }
}

#############################################################
# We're using some remote-exec functionality to finalize some
# of the server bits aroudn the script used for the watch
#############################################################
resource null_resource "provisioning-servers" {
  for_each =  { for server in aws_instance.consul-server : server.tags.Instance => server }
  # Consul Client Configuration
  provisioner "file" {
    source      = "files/check-handler.py"
    destination = "/tmp/check-handler.py"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/check-handler.py /etc/consul/consul.d/check-handler.py",
      "sudo sed -i s/amq_public_address/${aws_instance.activemq-server.public_ip}/g /etc/consul/consul.d/check-handler.py",
      "sudo chmod a+x /etc/consul/consul.d/check-handler.py"
    ]
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_key)
    host        = each.value.public_ip
  }
}

#############################################################
# We're using remote-exec to setup activemq.
# user_data is preferred, but this is an option
#############################################################
resource null_resource "provisioning-activemq" {
  provisioner "file" {
    source      = "files/apache-activemq-5.16.0-bin.tar.gz"
    destination = "/tmp/apache-activemq.tar.gz"
  }
  # Fire Up Services
  provisioner "remote-exec" {
    inline = [
      "sudo tar -zxvf /tmp/apache-activemq.tar.gz -C /etc",
      "sudo sed -i s/localhost/${aws_instance.activemq-server.private_ip}/g /etc/apache-activemq-5.16.0/bin/env",
      "sudo sed -i s/127.0.0.1/${aws_instance.activemq-server.private_ip}/g /etc/apache-activemq-5.16.0/conf/jetty.xml",
      "nohup sudo /etc/apache-activemq-5.16.0/bin/activemq console &",
      "sleep 60"
    ]
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_key)
    host        = aws_instance.activemq-server.public_ip
  }
}


##########################################################
# Setting up AWS IAM Profiles and Roles for Cloud AutoJoin
##########################################################

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.owner
  role        = aws_iam_role.instance_role.name
}
resource "aws_iam_role" "instance_role" {
  name_prefix        = var.owner
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}
data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy" "metadata_access" {
  name   = "metadata_access"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.metadata_access.json
}
data "aws_iam_policy_document" "metadata_access" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
  }
}
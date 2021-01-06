#########################################################################
# This files creates the AWS image for Consul and creates a manifest file
# that is to be used for the creation of the Consul Systems
# It sure is nice to be able to add comments into this file...data
#########################################################################

# Local variables for the Packer Creation
variable "aws_region" {
  type = string
  default = ""
}

variable "aws_instance_type" {
  type = string
  default = ""
}

variable "owner" {
  type = string
  default = ""
}

variable "DD_API_KEY" {
  type = string
}

# Looking for the source image on which to pack my new image
source "amazon-ebs" "ubuntu-image" {
  ami_name = "${var.owner}_{{timestamp}}"
  region = "${var.aws_region}"
  instance_type = var.aws_instance_type
  tags = {
    Name = "${var.owner}-consul"
  }

  source_ami_filter {
      filter {
        key = "virtualization-type"
        value = "hvm"
      }
      filter {
        key = "name"
        value = "ubuntu/images/*ubuntu-bionic-18.04-amd64-server-*"
      }
      filter {
        key = "root-device-type"
        value = "ebs"
      }
      owners = ["099720109477"]
      most_recent = true
  }
  communicator = "ssh"
  ssh_username = "ubuntu"
}

# Here we are actually building the image with the files
build {
  sources = [
    "source.amazon-ebs.ubuntu-image"
  ]

  provisioner "file" {
    source      = "../files/dd_consul.yaml"
    destination = "/tmp/consul.yaml"
  }

  provisioner "file" {
    source      = "../files/dogtreat.yaml"
    destination = "/tmp/dogtreat.yaml"
  }

  provisioner "file" {
    source      = "../files/apache-activemq-5.16.0-bin.tar.gz"
    destination = "/tmp/activemq-bin.tar.gz"
  }

# installing Linux items including Docker and of course Consul images
  provisioner "shell" {
    inline = [
      "sleep 30",
      "sudo apt-get update",
      "sudo apt install unzip -y",
      "sudo apt install nfs-common -y",
      "sudo apt install default-jre -y",
      "tar -zxvf /tmp/activemq-bin.tar.gz",
    ]
  }

# Consul installation bits
  provisioner "shell"{
    inline = [
      "sudo /usr/local/bin/consul -autocomplete-install",
      "sudo useradd --system --home /etc/consul/consul.d --shell /bin/false consul",
      "sudo mkdir /etc/consul /etc/consul/consul.d /etc/consul/logs /var/lib/consul/ /var/run/consul/",
      "sudo chown -R consul:consul /etc/consul /var/lib/consul/ /var/run/consul/",
      "sudo chmod -R a+r /etc/consul/logs/",
      "sudo mv /tmp/consul.service /etc/systemd/system/consul.service",
      "sudo mv /tmp/consul-common.hcl /etc/consul/consul.d/consul-common.hcl"

    ]
  }

# Installing DataDog Agent
  provisioner "shell" {
      environment_vars = [ "datadog_key=${var.DD_API_KEY}" ]
      inline = [
      "echo \"Installing DataDog with key $datadog_key\"",
      "sudo DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$datadog_key bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)\"",
      "sudo mv /tmp/consul.yaml /etc/datadog-agent/conf.d/consul.d/consul.yaml",
      "cat /tmp/dogtreat.yaml | sudo tee -a /etc/datadog-agent/datadog.yaml",
      # Adding dd-agent as having read access to consul logs
      "sudo setfacl -m d:dd-agent:r /etc/consul/logs/",
    ]
  }
 post-processor "manifest" {
   output = "aws-manifest.json"
   strip_path = true
 }
}

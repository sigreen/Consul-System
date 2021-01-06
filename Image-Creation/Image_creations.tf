# This file setups the resources necessary for image creation and storage
# Image storage at AWS is fairly straightforward

# Packer Runners to build image - separating the resources to enable individual resource taints
# Each packer build generates a manifest file for the respective image that is used to feed System Build

resource "null_resource" "aws_packer_runner" {
  provisioner "local-exec" {
    command = "packer build -var owner=${var.owner} -var aws_region=${var.aws_region} -var aws_instance_type=${var.aws_instance_type} AWS_linux_image.pkr.hcl"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm aws-manifest.json"
  }
}

output "AWS_Region" {
  value = var.aws_region
}
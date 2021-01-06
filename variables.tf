########################
# AWS Specific Variables
########################

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region for AWS Components"
}

variable "owner" {
  type    = string
  default = "consul-demo"
}

variable "consul_region" {
  type        = string
  description = "Region of consul server (not AWS Region)"
  default     = "global"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC"
  default     = "192.168.100.0/24"
}

variable "instance_type" {
  type        = string
  description = "machine instance type"
  default     = "t3.micro"
}

variable "aws_key" {
  type        = string
  description = "aws security PEM key"
}

variable "owner_tag" {
  type        = string
  description = "infrastructure owner"
}

variable "ssh_key" {
  type        = string
  description = "private key"
}
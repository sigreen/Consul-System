# Variables for use in the Image Creation run
variable "owner" {
  type        = string
  description = "Owner tag to which the artifacts belong"
  default     = "nomad-demo"
}

#AWS Specific Variables
variable "aws_region" {
  type        = string
  description = "AWS Region for image"
  default     = "us-east-2"
}
variable "aws_instance_type" {
  type        = string
  description = "Instance Type for Image"
  default     = "t2.small"
}
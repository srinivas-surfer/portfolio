variable "region" { default = "ap-south-1" }
variable "instance_type" { default = "t2.micro" }
# Use an Ubuntu 22.04 AMI for your region
variable "ami_id" { description = "Ubuntu 22.04 AMI id" }
variable "key_name" { description = "Existing EC2 key pair name" }

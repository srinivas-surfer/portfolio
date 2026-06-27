variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  description = "Ubuntu 22.04 AMI ID for the selected region."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name."
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to connect over SSH."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "origin_http_cidr_blocks" {
  description = "CIDR blocks allowed to reach the EC2 HTTP origin on port 80. Restrict to CloudFront origin-facing ranges when possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

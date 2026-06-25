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

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to access Nginx Proxy Manager on port 81. Empty keeps the admin UI private."
  type        = list(string)
  default     = []
}

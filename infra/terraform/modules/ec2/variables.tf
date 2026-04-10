# Variables for the EC2 module.

variable "instance_type" {
  description = "EC2 instance size."
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to attach to the instance."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched."
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to the instance."
  type        = string
}

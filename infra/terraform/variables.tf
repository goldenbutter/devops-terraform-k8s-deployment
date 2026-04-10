# Root-level input variables.
# Override defaults with a terraform.tfvars file or -var flags.

variable "aws_region" {
  description = "AWS region where all resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance size. t2.micro is free-tier eligible."
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instance. Restrict to your IP for security."
  type        = string
  default     = "0.0.0.0/0"
}

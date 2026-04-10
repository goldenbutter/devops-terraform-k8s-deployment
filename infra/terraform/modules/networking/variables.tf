# Variables for the networking module.

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instance."
  type        = string
  default     = "0.0.0.0/0"
}

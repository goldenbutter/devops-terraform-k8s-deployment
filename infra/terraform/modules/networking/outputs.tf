# Networking module outputs consumed by the ec2 module.

output "security_group_id" {
  description = "ID of the security group attached to the EC2 instance."
  value       = aws_security_group.main.id
}

output "subnet_id" {
  description = "ID of the public subnet where the EC2 instance is launched."
  value       = aws_subnet.public.id
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

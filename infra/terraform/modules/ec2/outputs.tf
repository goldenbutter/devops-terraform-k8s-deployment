# EC2 module outputs.

output "public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = aws_instance.main.public_ip
}

output "instance_id" {
  description = "AWS instance ID."
  value       = aws_instance.main.id
}

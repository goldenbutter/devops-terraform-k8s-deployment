# Root-level outputs printed after "terraform apply".
# These are the values you need to SSH into the instance and
# access services running inside the kind cluster.

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance running the kind cluster."
  value       = module.ec2.public_ip
}

output "ec2_instance_id" {
  description = "AWS instance ID — useful for SSM Session Manager access."
  value       = module.ec2.instance_id
}

output "security_group_id" {
  description = "Security group attached to the EC2 instance."
  value       = module.networking.security_group_id
}

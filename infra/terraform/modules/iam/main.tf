# IAM module — creates an instance profile that grants the EC2 instance
# permission to use SSM Session Manager (for keyless SSH) and read-only
# access to ECR (in case you switch from Docker Hub to a private registry).

# IAM role that the EC2 instance assumes.
resource "aws_iam_role" "ec2_role" {
  name = "devops-k8s-ec2-role"

  # Allow the EC2 service to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "devops-terraform-k8s"
  }
}

# SSM managed policy lets you connect via Session Manager without
# opening SSH ports — a more secure alternative for production.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ECR read-only access so the instance can pull private container images
# if you later migrate from Docker Hub.
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance profile wraps the IAM role so it can be attached to an EC2 instance.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devops-k8s-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

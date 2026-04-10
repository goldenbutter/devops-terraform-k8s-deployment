# Networking module — creates a VPC, public subnet, internet gateway,
# route table, and security group. All resources live in a single AZ
# because the free-tier EC2 only needs one subnet.

# ---------------------------------------------------------------
# VPC with a /16 CIDR — 65 536 IPs, more than enough for the demo.
# ---------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "devops-k8s-vpc"
    Project = "devops-terraform-k8s"
  }
}

# ---------------------------------------------------------------
# Public subnet in the first AZ of the selected region.
# map_public_ip_on_launch gives instances a public IP automatically.
# ---------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "devops-k8s-public-subnet"
    Project = "devops-terraform-k8s"
  }
}

# ---------------------------------------------------------------
# Internet gateway + route table: allows outbound internet access
# for the EC2 instance (needed to pull Docker images and packages).
# ---------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "devops-k8s-igw"
    Project = "devops-terraform-k8s"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route sends all non-local traffic through the IGW.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "devops-k8s-public-rt"
    Project = "devops-terraform-k8s"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------
# Security group — inbound rules open the ports required by the
# demo stack (SSH, HTTP, app, Prometheus, Grafana, K8s NodePorts).
# Outbound is fully open so the instance can pull packages/images.
# ---------------------------------------------------------------
resource "aws_security_group" "main" {
  name        = "devops-k8s-sg"
  description = "Allow SSH, HTTP, app ports, and K8s NodePort range"
  vpc_id      = aws_vpc.main.id

  # SSH — restricted to the caller's IP range for security.
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP (80) and HTTPS (443) for web traffic.
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port (the Go API listens on 8080).
  ingress {
    description = "App port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus UI (9090).
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana UI (3000).
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range — kind services exposed via NodePort
  # use ports 30000-32767 by default.
  ingress {
    description = "K8s NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic for package installs and image pulls.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "devops-k8s-sg"
    Project = "devops-terraform-k8s"
  }
}

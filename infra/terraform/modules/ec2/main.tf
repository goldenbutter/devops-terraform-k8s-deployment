# EC2 module — launches a free-tier t2.micro instance with Amazon Linux 2023.
# The user-data script bootstraps Docker, kind, and kubectl, then creates
# a single-node Kubernetes cluster ready to receive deployments.

# Look up the latest Amazon Linux 2023 AMI owned by Amazon.
# Using a data source means Terraform always picks the newest patch
# without hardcoding an AMI ID that will go stale.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile

  # 30 GB gp3 root volume — AMI requires >=30 GB; enough for Docker images and kind.
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  # User-data runs once on first boot. It installs the full toolchain
  # and brings up a kind cluster automatically.
  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail

    # ---- Install Docker ----
    dnf update -y
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # ---- Install kubectl ----
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl

    # ---- Install kind ----
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
    install -o root -g root -m 0755 kind /usr/local/bin/kind
    rm -f kind

    # ---- Create a kind cluster ----
    # The extraPortMappings let you reach NodePort services from the host,
    # which is how Grafana (30300) and the API are exposed externally.
    cat <<'EOF' > /tmp/kind-config.yaml
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
      - role: control-plane
        extraPortMappings:
          - containerPort: 30300
            hostPort: 30300
            protocol: TCP
          - containerPort: 80
            hostPort: 80
            protocol: TCP
          - containerPort: 443
            hostPort: 443
            protocol: TCP
    EOF

    kind create cluster --name devops-cluster --config /tmp/kind-config.yaml

    # Copy kubeconfig so ec2-user can run kubectl without sudo.
    mkdir -p /home/ec2-user/.kube
    kind get kubeconfig --name devops-cluster > /home/ec2-user/.kube/config
    chown -R ec2-user:ec2-user /home/ec2-user/.kube

    # ---- Pull the application Docker image ----
    docker pull goldenbutter/devops-api:latest || true
  USERDATA

  tags = {
    Name    = "devops-k8s-instance"
    Project = "devops-terraform-k8s"
  }
}

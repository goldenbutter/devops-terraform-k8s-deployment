# Terraform Setup Guide

Step-by-step instructions for provisioning the AWS infrastructure and deploying the kind cluster on EC2.

## Prerequisites

1. **AWS Account** — Free tier is sufficient for t2.micro
2. **AWS CLI** — Installed and configured
3. **Terraform** — Version 1.5 or higher
4. **EC2 Key Pair** — For SSH access to the instance

## Step 1: Install and Configure AWS CLI

```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)

# Verify
aws sts get-caller-identity
```

## Step 2: Create an EC2 Key Pair

```bash
# Create a new key pair (save the .pem file securely)
aws ec2 create-key-pair \
  --key-name devops-k8s-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/devops-k8s-key.pem

chmod 400 ~/.ssh/devops-k8s-key.pem
```

## Step 3: Create terraform.tfvars

Create a variable file so you don't have to pass flags on every run:

```bash
cd infra/terraform

cat > terraform.tfvars <<EOF
aws_region       = "us-east-1"
instance_type    = "t2.micro"
key_name         = "devops-k8s-key"
allowed_ssh_cidr = "YOUR_PUBLIC_IP/32"
EOF
```

Find your public IP:

```bash
curl -s ifconfig.me
```

## Step 4: Initialize Terraform

```bash
cd infra/terraform

# Download provider plugins and initialize modules
terraform init

# Expected output:
# Initializing modules...
# Initializing provider plugins...
# Terraform has been successfully initialized!
```

## Step 5: Review the Plan

```bash
terraform plan

# Review the output carefully:
# - 1 VPC
# - 1 Subnet
# - 1 Internet Gateway
# - 1 Route Table + Association
# - 1 Security Group
# - 1 IAM Role + Instance Profile + 2 Policy Attachments
# - 1 EC2 Instance
# Total: ~10 resources
```

## Step 6: Apply

```bash
terraform apply

# Type "yes" when prompted
# Wait 2-3 minutes for the instance to launch

# Save the outputs
terraform output
# ec2_public_ip    = "54.xxx.xxx.xxx"
# ec2_instance_id  = "i-0abc123..."
# security_group_id = "sg-0abc123..."
```

## Step 7: SSH into the EC2 Instance

```bash
# Wait ~3 minutes for user-data to finish (Docker, kind, kubectl install)
ssh -i ~/.ssh/devops-k8s-key.pem ec2-user@$(terraform output -raw ec2_public_ip)

# Verify the kind cluster is running
kubectl get nodes
# NAME                           STATUS   ROLES           AGE   VERSION
# devops-cluster-control-plane   Ready    control-plane   2m    v1.29.x

# Verify Docker
docker ps
```

## Step 8: Deploy the Application on EC2

```bash
# On the EC2 instance:

# Pull the app image
docker pull goldenbutter/devops-api:latest

# Load it into kind
kind load docker-image goldenbutter/devops-api:latest --name devops-cluster

# Clone the repo for manifests (or scp them)
git clone https://github.com/goldenbutter/devops-terraform-k8s-deployment.git
cd devops-terraform-k8s-deployment

# Apply all manifests
kubectl apply -f deploy/k8s/base/
kubectl apply -f deploy/k8s/monitoring/prometheus/
kubectl apply -f deploy/k8s/monitoring/grafana/

# Verify
kubectl get pods
kubectl get svc
```

## Step 9: Access Services

From your local machine:

| Service    | URL                                            |
|------------|------------------------------------------------|
| API        | `http://<ec2-ip>:8080`                         |
| Prometheus | `http://<ec2-ip>:9090`                         |
| Grafana    | `http://<ec2-ip>:30300` (admin / admin)        |

## Step 10: Destroy Infrastructure

When you're done, tear everything down to avoid charges:

```bash
cd infra/terraform
terraform destroy

# Type "yes" when prompted
# All resources will be deleted
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `terraform init` fails | No AWS credentials | Run `aws configure` |
| SSH connection refused | User-data still running | Wait 3–5 minutes |
| `kind` not found on EC2 | User-data failed | Check `/var/log/cloud-init-output.log` |
| Security group blocks traffic | Wrong CIDR | Update `allowed_ssh_cidr` in tfvars |
| Instance won't launch | Key pair not found | Create key pair in the correct region |

## Cost Estimate

| Resource | Monthly Cost (Free Tier) |
|----------|--------------------------|
| EC2 t2.micro | $0 (750 hrs/month free) |
| EBS 20 GB gp3 | $0 (30 GB free) |
| Data transfer | $0 (< 1 GB) |
| **Total** | **$0** |

Free tier is valid for 12 months after account creation.

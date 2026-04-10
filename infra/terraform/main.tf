# Root module — composes the three child modules (networking, iam, ec2)
# and wires their outputs together. Running "terraform apply" from this
# directory provisions the full stack in one shot.

module "networking" {
  source           = "./modules/networking"
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

module "iam" {
  source = "./modules/iam"
}

module "ec2" {
  source               = "./modules/ec2"
  instance_type        = var.instance_type
  key_name             = var.key_name
  security_group_id    = module.networking.security_group_id
  subnet_id            = module.networking.subnet_id
  iam_instance_profile = module.iam.instance_profile_name
}

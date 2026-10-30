# ---------------------------------------------------------------
# The server, written down.
#
# In Week 06 this was steps 5 to 7 of STEPS.md: the Launch instance
# wizard, a key pair you downloaded, and a security group you edited
# by hand. None of that was in the repository. This file is.
# ---------------------------------------------------------------

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

variable "region" {
  description = "The AWS region to build in. Use the same one as Week 05."
  default     = "us-east-1"
}

variable "name" {
  description = "Prefix for everything this file creates."
  default     = "buildrbank"
}

provider "aws" {
  region = var.region
}

# --- the login key ---------------------------------------------------
# Terraform makes a brand new SSH key, puts the public half in AWS, and
# writes the private half next to this file. That file becomes your
# EC2_SSH_KEY secret - you never download a .pem from the console again.

resource "tls_private_key" "bank" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bank" {
  key_name   = "${var.name}-key"
  public_key = tls_private_key.bank.public_key_openssh
}

resource "local_file" "bank_pem" {
  filename        = "${path.module}/buildrbank-key.pem"
  content         = tls_private_key.bank.private_key_pem
  file_permission = "0400"
}

# --- the security group ----------------------------------------------
# Three doors, and the pipeline needs all three:
#   22    Ansible, and the pipeline's ssh-action, walk in here
#   8000  production - the container called "bank"
#   8001  the sandbox - the container called "bank-dev"

resource "aws_security_group" "bank" {
  name        = "${var.name}-sg"
  description = "BuildrBank: SSH, production slot, dev slot"

  ingress {
    description = "SSH for Ansible and for the pipeline"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "BuildrBank production"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "BuildrBank dev slot"
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- which Ubuntu ----------------------------------------------------
# Ask AWS, at run time, for the newest official Ubuntu 24.04 in whatever
# region you chose. A hard-coded AMI id goes stale and is wrong in every
# other region.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# --- the server ------------------------------------------------------
# t3.small, not t3.micro: BuildrBank loads an embedding model and an
# agent graph, and 1 GB is uncomfortably tight.

resource "aws_instance" "bank" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = aws_key_pair.bank.key_name
  vpc_security_group_ids = [aws_security_group.bank.id]

  tags = {
    Name = var.name
  }
}

# --- what you need next ----------------------------------------------

output "ip" {
  description = "The server's public address. This is your EC2_HOST secret."
  value       = aws_instance.bank.public_ip
}

output "prod_url" {
  description = "Where production answers, once the pipeline has deployed to main."
  value       = "http://${aws_instance.bank.public_ip}:8000"
}

output "dev_url" {
  description = "Where the sandbox answers, once the pipeline has deployed to dev."
  value       = "http://${aws_instance.bank.public_ip}:8001"
}

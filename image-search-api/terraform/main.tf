terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- VPC & Security ---
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "api_sg" {
  name        = "image-search-api-sg"
  description = "Allow inbound traffic for Image Search API (nginx + SSH)"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP — served by nginx; nginx proxies to FastAPI on 8000 internally
  ingress {
    description = "HTTP (nginx)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — reserved for Let's Encrypt / future TLS termination
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "image-search-api-sg"
  }
}

# --- Key Pair ---
resource "aws_key_pair" "deployer" {
  key_name   = "image-search-deployer-key"
  public_key = var.public_key
}

# --- EC2 Instance ---
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app_server" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  key_name             = aws_key_pair.deployer.key_name
  iam_instance_profile = aws_iam_instance_profile.app_profile.name

  vpc_security_group_ids = [aws_security_group.api_sg.id]

  user_data = templatefile("${path.module}/bootstrap.sh.tpl", {
    aws_region = var.aws_region
  })

  tags = {
    Name = "ImageSearchAPI"
  }
}

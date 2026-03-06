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

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail
              exec > /var/log/user-data.log 2>&1

              # ── System packages ──────────────────────────────────────
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release git awscli nginx

              # Disable the default nginx site now; we'll add ours after the app starts
              rm -f /etc/nginx/sites-enabled/default

              # ── Docker ───────────────────────────────────────────────
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
                | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              usermod -aG docker ubuntu
              systemctl enable --now docker

              # ── Clone repo ───────────────────────────────────────────
              APP_DIR=/opt/image-search
              git clone https://github.com/gagandeep/image-search "$APP_DIR" || \
                git -C "$APP_DIR" pull
              cd "$APP_DIR/image-search-api"

              # ── Pull env vars from SSM and write .env ────────────────
              # The EC2 IAM role grants read access; no AWS keys needed.
              AWS_REGION="${var.aws_region}"
              SSM_PREFIX="/image-search"

              write_param() {
                local key="$1"
                local value
                value=$(aws ssm get-parameter \
                  --region "$AWS_REGION" \
                  --name "$SSM_PREFIX/$key" \
                  --with-decryption \
                  --query Parameter.Value \
                  --output text)
                echo "$key=$value"
              }

              {
                write_param UNSPLASH_APP_ID
                write_param UNSPLASH_ACCESS_KEY
                write_param UNSPLASH_SECRET_KEY
                write_param PEXELS_API_KEY
                write_param PIXABAY_API_KEY
                write_param FREEPIK_API_KEY
                write_param POSTGRES_URL
                write_param TYPESENSE_HOST
                write_param TYPESENSE_PORT
                write_param TYPESENSE_API_KEY
                write_param REDIS_URL
                echo "USE_SSM=false"   # app reads .env; SSM already resolved here
              } > .env
              chmod 600 .env

              # ── Start the stack ──────────────────────────────────────
              docker compose up --build -d

              # ── Configure nginx (host) to proxy port 80 → 8000 ───────
              cat > /etc/nginx/sites-available/image-search << 'NGINXCONF'
# CORS: allow getaipage.com and all its subdomains.
map $http_origin $cors_origin {
    default                                        "";
    "~^https?://(.*\.)?getaipage\.com(:[0-9]+)?$" $http_origin;
}

server {
    listen      80;
    server_name images.innerkore.com;

    real_ip_header    X-Forwarded-For;
    set_real_ip_from  0.0.0.0/0;

    location / {
        # ── CORS preflight ────────────────────────────────────────
        if ($request_method = OPTIONS) {
            add_header 'Access-Control-Allow-Origin'      $cors_origin;
            add_header 'Access-Control-Allow-Credentials' 'true';
            add_header 'Access-Control-Allow-Methods'     'GET, POST, PUT, PATCH, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers'     'Authorization, Content-Type, Accept, Origin, X-Requested-With';
            add_header 'Access-Control-Max-Age'           '86400';
            add_header 'Content-Type'                     'text/plain; charset=utf-8';
            add_header 'Content-Length'                   '0';
            return 204;
        }

        # ── CORS on every real response ───────────────────────────
        add_header 'Access-Control-Allow-Origin'      $cors_origin                                          always;
        add_header 'Access-Control-Allow-Credentials' 'true'                                                always;
        add_header 'Access-Control-Allow-Methods'     'GET, POST, PUT, PATCH, DELETE, OPTIONS'              always;
        add_header 'Access-Control-Allow-Headers'     'Authorization, Content-Type, Accept, Origin, X-Requested-With' always;

        # ── Proxy to FastAPI running in Docker ────────────────────
        proxy_pass         http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_buffering    off;
        proxy_read_timeout 120s;
    }
}
NGINXCONF

              ln -sf /etc/nginx/sites-available/image-search /etc/nginx/sites-enabled/image-search
              nginx -t
              systemctl enable --now nginx
              systemctl reload nginx
              EOF

  tags = {
    Name = "ImageSearchAPI"
  }

  depends_on = [
    aws_ssm_parameter.unsplash_app_id,
    aws_ssm_parameter.unsplash_access_key,
    aws_ssm_parameter.unsplash_secret_key,
    aws_ssm_parameter.pexels_api_key,
    aws_ssm_parameter.pixabay_api_key,
    aws_ssm_parameter.freepik_api_key,
    aws_ssm_parameter.postgres_url,
    aws_ssm_parameter.typesense_host,
    aws_ssm_parameter.typesense_port,
    aws_ssm_parameter.typesense_api_key,
    aws_ssm_parameter.redis_url,
  ]
}

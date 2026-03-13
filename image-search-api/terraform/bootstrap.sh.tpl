#!/bin/bash
set -euo pipefail
exec > /var/log/user-data.log 2>&1

# ── System packages ──────────────────────────────────────────────────
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release git unzip nginx

# Disable the default nginx site; ours is added further below
rm -f /etc/nginx/sites-enabled/default

# ── AWS CLI v2 (no apt package on Ubuntu 22.04 ARM64) ────────────────
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# ── Docker ───────────────────────────────────────────────────────────
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

# ── Clone repo ───────────────────────────────────────────────────────
APP_DIR=/opt/image-search
git clone https://github.com/gagandeep/image-search "$APP_DIR" || \
  git -C "$APP_DIR" pull
cd "$APP_DIR/image-search-api"

# ── Pull env vars from SSM and write .env ────────────────────────────
# The EC2 IAM role grants read access; no AWS credentials needed.
AWS_REGION="${aws_region}"
SSM_PREFIX="/image-search"

write_param() {
  local key="$1"
  local value
  value=$(/usr/local/bin/aws ssm get-parameter \
    --region "$AWS_REGION" \
    --name "$SSM_PREFIX/$key" \
    --with-decryption \
    --query Parameter.Value \
    --output text)
  echo "$key=$value"
}

# Like write_param but silently skips if the SSM parameter does not exist.
optional_write_param() {
  local key="$1"
  local value
  value=$(/usr/local/bin/aws ssm get-parameter \
    --region "$AWS_REGION" \
    --name "$SSM_PREFIX/$key" \
    --with-decryption \
    --query Parameter.Value \
    --output text 2>/dev/null) || return 0
  [[ -n "$value" ]] && echo "$key=$value"
}

{
  write_param UNSPLASH_APP_ID
  write_param UNSPLASH_ACCESS_KEY
  write_param UNSPLASH_SECRET_KEY
  write_param PEXELS_API_KEY
  optional_write_param PIXABAY_API_KEY
  optional_write_param FREEPIK_API_KEY
  write_param POSTGRES_URL
  write_param TYPESENSE_HOST
  write_param TYPESENSE_PORT
  write_param TYPESENSE_API_KEY
  write_param REDIS_URL
  echo "USE_SSM=false"
} > .env
chmod 600 .env
chown ubuntu:ubuntu .env

# ── Start Docker stack ───────────────────────────────────────────────
docker compose up --build -d

# ── Configure host nginx → SSL on 443, redirect 80 → 443 ────────────
cat > /etc/nginx/sites-available/image-search << 'NGINXCONF'
# CORS: allow getaipage.com and all its subdomains.
map $http_origin $cors_origin {
    default                                        "";
    "~^https?://(.*\.)?getaipage\.com(:[0-9]+)?$" $http_origin;
}

# Redirect HTTP to HTTPS
server {
    listen      80;
    server_name images.innerkore.com;
    return 301 https://$host$request_uri;
}

server {
    listen      443 ssl;
    server_name images.innerkore.com;

    # Cloudflare Origin Certificate (bundled in repo at certs/)
    ssl_certificate     /opt/image-search/certs/innerkore_cloudflare.pem;
    ssl_certificate_key /opt/image-search/certs/innerkore_cloudflare.key;

    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    real_ip_header    X-Forwarded-For;
    set_real_ip_from  0.0.0.0/0;

    location / {
        # CORS preflight
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

        # CORS on every real response
        add_header 'Access-Control-Allow-Origin'      $cors_origin                                          always;
        add_header 'Access-Control-Allow-Credentials' 'true'                                                always;
        add_header 'Access-Control-Allow-Methods'     'GET, POST, PUT, PATCH, DELETE, OPTIONS'              always;
        add_header 'Access-Control-Allow-Headers'     'Authorization, Content-Type, Accept, Origin, X-Requested-With' always;

        # Proxy to FastAPI running in Docker (bound to localhost:8000)
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

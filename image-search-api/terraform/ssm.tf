# ---------------------------------------------------------------
# AWS SSM Parameter Store — image-search app configuration
# All parameters live under the /image-search prefix so the app
# can fetch them in one GetParametersByPath call.
# Sensitive values are stored as SecureString (KMS-encrypted).
# ---------------------------------------------------------------

locals {
  ssm_prefix = "/image-search"
}

# --- API Keys (SecureString) ---

resource "aws_ssm_parameter" "unsplash_api_key" {
  name        = "${local.ssm_prefix}/UNSPLASH_API_KEY"
  description = "Unsplash API key"
  type        = "SecureString"
  value       = var.unsplash_api_key

  tags = { App = "image-search" }
}

resource "aws_ssm_parameter" "pexels_api_key" {
  name        = "${local.ssm_prefix}/PEXELS_API_KEY"
  description = "Pexels API key"
  type        = "SecureString"
  value       = var.pexels_api_key

  tags = { App = "image-search" }
}

resource "aws_ssm_parameter" "pixabay_api_key" {
  name        = "${local.ssm_prefix}/PIXABAY_API_KEY"
  description = "Pixabay API key"
  type        = "SecureString"
  value       = var.pixabay_api_key

  tags = { App = "image-search" }
}

resource "aws_ssm_parameter" "freepik_api_key" {
  name        = "${local.ssm_prefix}/FREEPIK_API_KEY"
  description = "Freepik API key"
  type        = "SecureString"
  value       = var.freepik_api_key

  tags = { App = "image-search" }
}

resource "aws_ssm_parameter" "typesense_api_key" {
  name        = "${local.ssm_prefix}/TYPESENSE_API_KEY"
  description = "Typesense API key"
  type        = "SecureString"
  value       = var.typesense_api_key

  tags = { App = "image-search" }
}

# --- Database (SecureString — contains credentials) ---

resource "aws_ssm_parameter" "postgres_url" {
  name        = "${local.ssm_prefix}/POSTGRES_URL"
  description = "PostgreSQL async connection URL"
  type        = "SecureString"
  value       = var.postgres_url

  tags = { App = "image-search" }
}

# --- Infrastructure / non-secret (String) ---

resource "aws_ssm_parameter" "typesense_host" {
  name        = "${local.ssm_prefix}/TYPESENSE_HOST"
  description = "Typesense service hostname"
  type        = "String"
  value       = var.typesense_host

  tags = { App = "image-search" }
}

resource "aws_ssm_parameter" "typesense_port" {
  name        = "${local.ssm_prefix}/TYPESENSE_PORT"
  description = "Typesense service port"
  type        = "String"
  value       = tostring(var.typesense_port)

  tags = { App = "image-search" }
}

resource "aws_ssm_parameter" "redis_url" {
  name        = "${local.ssm_prefix}/REDIS_URL"
  description = "Redis connection URL"
  type        = "String"
  value       = var.redis_url

  tags = { App = "image-search" }
}

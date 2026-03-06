variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t4g.small"
}

variable "public_key" {
  description = "The public SSH key to inject into the EC2 instance for deployment"
  type        = string
}

# ---------------------------------------------------------------
# App environment variables — stored in SSM Parameter Store.
# Mark sensitive values with sensitive = true so Terraform never
# prints them in plan/apply output.
# ---------------------------------------------------------------

variable "unsplash_api_key" {
  description = "Unsplash API key"
  type        = string
  sensitive   = true
}

variable "pexels_api_key" {
  description = "Pexels API key"
  type        = string
  sensitive   = true
}

variable "pixabay_api_key" {
  description = "Pixabay API key"
  type        = string
  sensitive   = true
}

variable "freepik_api_key" {
  description = "Freepik API key"
  type        = string
  sensitive   = true
}

variable "postgres_url" {
  description = "PostgreSQL async connection URL (postgresql+asyncpg://...)"
  type        = string
  sensitive   = true
  default     = "postgresql+asyncpg://user:password@localhost:5432/unsplash"
}

variable "typesense_api_key" {
  description = "Typesense API key"
  type        = string
  sensitive   = true
  default     = "xyz"
}

variable "typesense_host" {
  description = "Typesense service hostname"
  type        = string
  default     = "typesense"
}

variable "typesense_port" {
  description = "Typesense service port"
  type        = number
  default     = 8108
}

variable "redis_url" {
  description = "Redis connection URL"
  type        = string
  default     = "redis://redis:6379/0"
}
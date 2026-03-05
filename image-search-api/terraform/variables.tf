variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "public_key" {
  description = "The public SSH key to inject into the EC2 instance for deployment"
  type        = string
}
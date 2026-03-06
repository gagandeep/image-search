output "instance_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "api_endpoint" {
  description = "The endpoint to access the FastAPI swagger UI"
  value       = "http://${aws_instance.app_server.public_ip}:8000/docs"
}

output "ssm_prefix" {
  description = "SSM Parameter Store path prefix used by the app"
  value       = "/image-search"
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the EC2 instance"
  value       = aws_iam_role.app_role.arn
}
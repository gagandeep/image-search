output "instance_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "api_endpoint" {
  description = "The endpoint to access the FastAPI swagger UI (via nginx)"
  value       = "http://${aws_instance.app_server.public_ip}/docs"
}

output "dns_record_value" {
  description = "Point images.innerkore.com A record to this IP"
  value       = aws_instance.app_server.public_ip
}

output "ssm_prefix" {
  description = "SSM Parameter Store path prefix used by the app"
  value       = "/image-search"
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the EC2 instance"
  value       = aws_iam_role.app_role.arn
}
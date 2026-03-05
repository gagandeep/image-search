output "instance_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "api_endpoint" {
  description = "The endpoint to access the FastAPI swagger UI"
  value       = "http://${aws_instance.app_server.public_ip}:8000/docs"
}
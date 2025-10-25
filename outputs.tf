output "ec2_public_ip" {
  description = "EC2 퍼블릭 IP"
  value       = aws_instance.hasura.public_ip
}

output "hasura_console_url" {
  description = "Hasura Console URL"
  value       = "http://${aws_instance.hasura.public_ip}:8080/console"
}

output "hasura_graphql_endpoint" {
  description = "Hasura GraphQL Endpoint"
  value       = "http://${aws_instance.hasura.public_ip}:8080/v1/graphql"
}

output "ssh_command" {
  description = "SSH 접속 명령어"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.hasura.public_ip}"
}


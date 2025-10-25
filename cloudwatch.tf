# CloudWatch 로그 그룹 - Hasura 애플리케이션 로그
resource "aws_cloudwatch_log_group" "hasura" {
  name              = "/aws/ec2/hasura"
  retention_in_days = 14

  tags = {
    Name = "hasura-logs"
  }
}

# CloudWatch 로그 그룹 - 시스템 로그
resource "aws_cloudwatch_log_group" "hasura_system" {
  name              = "/aws/ec2/hasura/system"
  retention_in_days = 7

  tags = {
    Name = "hasura-system-logs"
  }
}


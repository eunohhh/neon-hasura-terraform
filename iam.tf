# IAM Role for EC2
resource "aws_iam_role" "ec2" {
  name = "ec2-hasura-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "ec2-hasura-role"
  }
}

# Secrets Manager 읽기 권한 (Admin Secret + DB URL + JWT Secret)
resource "aws_iam_role_policy" "allow_sm_get" {
  name = "allow-secretsmanager-get"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [
        local.admin_secret_arn,
        local.db_secret_arn,
        local.jwt_secret_arn
      ]
    }]
  })
}

# SSM/Session Manager 사용을 위한 정책 연결
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent 정책 연결
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-hasura-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "ec2-hasura-profile"
  }
}


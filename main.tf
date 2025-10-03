# variables.tf
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2" # 서울 리전
}

variable "neon_database_url" {
  description = "Neon PostgreSQL 연결 URL"
  type        = string
  sensitive   = true
}

variable "hasura_admin_secret" {
  description = "Hasura 관리자 비밀번호"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "SSH 접속을 허용할 내 IP (예: 1.2.3.4/32)"
  type        = string
}

# main.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hasura-vpc"
  }
}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "hasura-igw"
  }
}

# 퍼블릭 서브넷
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "hasura-public-subnet"
  }
}

# 라우팅 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "hasura-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 보안 그룹
resource "aws_security_group" "hasura" {
  name        = "hasura-sg"
  description = "Hasura EC2 Security Group"
  vpc_id      = aws_vpc.main.id

  # SSH 접속 (내 IP만)
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Hasura GraphQL (HTTP)
  ingress {
    description = "Hasura GraphQL"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드 모두 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hasura-sg"
  }
}

# 키 페어 (기존 키 사용 또는 새로 생성)
resource "aws_key_pair" "hasura" {
  key_name   = "hasura-key"
  public_key = file("~/.ssh/id_rsa.pub") # 본인의 공개키 경로로 수정

  tags = {
    Name = "hasura-key"
  }
}

# 최신 Ubuntu 22.04 ARM64 AMI 조회
data "aws_ami" "ubuntu_arm64" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 인스턴스
resource "aws_instance" "hasura" {
  ami           = data.aws_ami.ubuntu_arm64.id
  instance_type = "t4g.micro"
  
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.hasura.id]
  key_name                    = aws_key_pair.hasura.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    neon_database_url   = var.neon_database_url
    hasura_admin_secret = var.hasura_admin_secret
  })

  tags = {
    Name = "hasura-server"
  }
}

# outputs.tf
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
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

# 현재 AWS 계정 정보
data "aws_caller_identity" "me" {}

# Local 변수 정의
locals {
  region             = var.aws_region
  admin_secret_name  = "hasura/admin_secret"
  db_secret_name     = "hasura/database_url"
  jwt_secret_name    = "hasura/jwt_secret"
  admin_secret_arn   = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.me.account_id}:secret:${local.admin_secret_name}-*"
  db_secret_arn      = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.me.account_id}:secret:${local.db_secret_name}-*"
  jwt_secret_arn     = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.me.account_id}:secret:${local.jwt_secret_name}-*"
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

  # SSH 접속 (내 IP들만)
  dynamic "ingress" {
    for_each = var.my_ip
    content {
      description = "SSH from my IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Hasura GraphQL (HTTP) - 허용된 IP들만 접근 가능
  dynamic "ingress" {
    for_each = length(var.allowed_ips) > 0 ? var.allowed_ips : var.my_ip
    content {
      description = "Hasura GraphQL from allowed IP"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
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

# 키 페어
resource "aws_key_pair" "hasura" {
  key_name   = "hasura-key"
  public_key = file(var.ssh_public_key_path)

  tags = {
    Name = "hasura-key"
  }
  
  lifecycle {
    create_before_destroy = false
    prevent_destroy       = false
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
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region        = local.region
    admin_secret_name = local.admin_secret_name
    db_secret_name    = local.db_secret_name
    jwt_secret_name   = local.jwt_secret_name
    cors_domains      = join(",", var.cors_domains)
  })

  tags = {
    Name = "hasura-server"
  }
}

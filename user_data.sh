#!/bin/bash
set -e

# 로그 파일 설정
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Hasura 설치 시작 ==="

# 시스템 업데이트
apt-get update
apt-get upgrade -y

# Docker 설치
echo "Docker 설치 중..."
apt-get install -y ca-certificates curl gnupg lsb-release

# Docker GPG 키 추가
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Docker 저장소 추가
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker 설치
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 서비스 시작 및 활성화
systemctl start docker
systemctl enable docker

# ubuntu 사용자를 docker 그룹에 추가
usermod -aG docker ubuntu

# Docker Compose 설치 (standalone)
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Docker 설치 완료"

# Hasura 디렉토리 생성
mkdir -p /home/ubuntu/hasura
cd /home/ubuntu/hasura

# docker-compose.yml 생성
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  hasura:
    image: hasura/graphql-engine:v2.48.5
    ports:
      - "8080:8080"
    restart: always
    environment:
      ## Neon PostgreSQL 연결
      HASURA_GRAPHQL_DATABASE_URL: ${neon_database_url}
      
      ## Hasura 설정
      HASURA_GRAPHQL_ENABLE_CONSOLE: "true"
      HASURA_GRAPHQL_ADMIN_SECRET: ${hasura_admin_secret}
      HASURA_GRAPHQL_UNAUTHORIZED_ROLE: "anonymous"
      
      ## 개발 모드 설정
      HASURA_GRAPHQL_DEV_MODE: "true"
      HASURA_GRAPHQL_ENABLED_LOG_TYPES: startup, http-log, webhook-log, websocket-log, query-log
      
      ## CORS 설정 (모든 origin 허용 - 프로덕션에서는 수정 필요)
      HASURA_GRAPHQL_CORS_DOMAIN: "*"
      
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 5
EOF

# 권한 설정
chown -R ubuntu:ubuntu /home/ubuntu/hasura

# Hasura 시작
echo "Hasura 컨테이너 시작 중..."
docker-compose up -d

# 컨테이너 상태 확인
sleep 10
docker-compose ps

echo "=== Hasura 설치 완료 ==="
echo "Hasura Console: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/console"
echo "관리자 비밀번호로 로그인하세요"
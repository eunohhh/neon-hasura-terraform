#!/bin/bash
set -euo pipefail

# 로그 파일 설정
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Hasura 설치 시작 ==="

# 시스템 업데이트
apt-get update
apt-get upgrade -y

# Docker 및 AWS CLI, jq 설치
echo "필수 패키지 설치 중..."
apt-get install -y ca-certificates curl gnupg lsb-release awscli jq

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

echo "Docker 설치 완료"

# AWS 리전 및 시크릿 정보
REGION="${aws_region}"
ADMIN_SECRET_NAME="${admin_secret_name}"
DB_SECRET_NAME="${db_secret_name}"

echo "Secrets Manager에서 시크릿 조회 중..."

# 관리자 비밀번호 조회
ADMIN_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$ADMIN_SECRET_NAME" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text)

# DB URL 조회
DB_URL=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_NAME" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text)

# 만약 시크릿이 JSON 형태라면 jq로 파싱
# ADMIN_SECRET=$(echo "$ADMIN_SECRET" | jq -r .password)
# DB_URL=$(echo "$DB_URL" | jq -r .url)

echo "시크릿 조회 완료"

# Hasura를 Docker로 직접 실행
echo "Hasura 컨테이너 시작 중..."
docker run -d \
  --name hasura \
  --restart always \
  -p 8080:8080 \
  -e HASURA_GRAPHQL_DATABASE_URL="$DB_URL" \
  -e HASURA_GRAPHQL_ENABLE_CONSOLE="true" \
  -e HASURA_GRAPHQL_ADMIN_SECRET="$ADMIN_SECRET" \
  -e HASURA_GRAPHQL_JWT_SECRET="{\"type\":\"HS256\",\"key\":\"$ADMIN_SECRET\"}" \
  -e HASURA_GRAPHQL_UNAUTHORIZED_ROLE="anonymous" \
  -e HASURA_GRAPHQL_DEV_MODE="false" \
  -e HASURA_GRAPHQL_ENABLED_LOG_TYPES="startup, http-log, webhook-log, websocket-log, query-log" \
  -e HASURA_GRAPHQL_CORS_DOMAIN="https://hasura-brothers.vercel.app,https://www.hasurabrothers.com,http://localhost:3000,https://localhost:3000" \
  -e HASURA_GRAPHQL_DISABLE_INTROSPECTION="false" \
  -e HASURA_GRAPHQL_ENABLE_TELEMETRY="false" \
  hasura/graphql-engine:v2.48.5

# 컨테이너 상태 확인
sleep 10
docker ps

echo "=== Hasura 설치 완료 ==="
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Hasura Console: http://$PUBLIC_IP:8080/console"
echo "관리자 비밀번호는 Secrets Manager에서 안전하게 관리됩니다"
# Hasura + Neon DB Terraform 구성 가이드

## 📋 사전 준비

### 1. Neon DB 준비
1. [neon.tech](https://neon.tech) 가입
2. 새 프로젝트 생성
3. Connection string 복사
   - 형식: `postgresql://[user]:[password]@[endpoint]/[dbname]?sslmode=require`

### 2. SSH 키 준비
```bash
# SSH 키가 없다면 생성
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# 공개키 확인
cat ~/.ssh/id_rsa.pub
```

### 3. 내 IP 확인
```bash
# 현재 내 공인 IP 확인
curl ifconfig.me
# 출력 예: 123.456.789.012
```

## 🚀 설치 및 실행

### 1. 프로젝트 디렉토리 생성
```bash
mkdir hasura-terraform
cd hasura-terraform
```

### 2. Terraform 파일 생성
다음 파일들을 생성하세요:
- `main.tf` (Artifact 1)
- `user_data.sh` (Artifact 2)

### 3. AWS Secrets Manager 설정
```bash
# Hasura Admin Secret 생성 (32자 이상)
aws secretsmanager create-secret \
  --name hasura/admin_secret \
  --secret-string "your-32-character-admin-secret-here" \
  --region ap-northeast-2

# Database URL 생성
aws secretsmanager create-secret \
  --name hasura/database_url \
  --secret-string "postgresql://user:password@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require" \
  --region ap-northeast-2

# JWT Secret 생성 (32자 이상)
aws secretsmanager create-secret \
  --name hasura/jwt_secret \
  --secret-string "your-32-character-jwt-secret-here" \
  --region ap-northeast-2
```

### 4. terraform.tfvars 파일 생성
```bash
cat > terraform.tfvars <<EOF
aws_region = "ap-northeast-2"  # 서울 리전

# 내 IP 주소 (SSH 접속용, /32 붙이기)
my_ip = "123.456.789.012/32"

# Hasura 접근을 허용할 IP 목록 (선택사항)
# allowed_ips = [
#   "123.456.789.012/32",  # 집 IP
#   "203.123.456.789/32", # 회사 IP
#   "1.2.3.4/32"         # 다른 장소 IP
# ]

# 임시로 모든 IP 허용 (개발용)
allowed_ips = ["0.0.0.0/0"]
EOF
```

⚠️ **중요**: `terraform.tfvars` 파일은 `.gitignore`에 추가하세요!

### 5. Terraform 초기화
```bash
terraform init
```

### 6. 실행 계획 확인
```bash
terraform plan -out=myplan.tfplan
```

### 7. 인프라 배포
```bash
terraform apply myplan.tfplan
```

`yes` 입력 후 약 3-5분 대기

### 8. 출력 정보 확인
```bash
terraform output
```

출력 예시:
```
ec2_public_ip = "13.125.123.456"
hasura_console_url = "http://13.125.123.456:8080/console"
hasura_graphql_endpoint = "http://13.125.123.456:8080/v1/graphql"
ssh_command = "ssh -i ~/.ssh/id_rsa ubuntu@13.125.123.456"
```

## ✅ 동작 확인

### 1. Hasura Console 접속
브라우저에서 `terraform output hasura_console_url` 결과 URL 접속
- 관리자 비밀번호 입력 (`hasura_admin_secret` 값)

### 2. SSH 접속 (선택사항)
```bash
# 출력된 ssh_command 사용
ssh -i ~/.ssh/id_rsa ubuntu@<EC2_PUBLIC_IP>

# 컨테이너 상태 확인
cd ~/hasura
docker-compose ps
docker-compose logs -f
```

## 🧪 테스트

### 1. 간단한 테이블 생성
Hasura Console에서:
1. DATA 탭 → "Public" 스키마 선택
2. "Create Table" 클릭
3. 테이블 이름: `users`
4. 컬럼 추가:
   - `id` (Integer, auto-increment, primary key)
   - `name` (Text)
   - `email` (Text)
5. "Add Table" 클릭

### 2. GraphQL 쿼리 테스트
API 탭에서:
```graphql
mutation {
  insert_users_one(object: {name: "오은", email: "test@example.com"}) {
    id
    name
    email
  }
}
```

```graphql
query {
  users {
    id
    name
    email
  }
}
```

## 💰 비용 절약

### 사용 후 인프라 삭제
```bash
terraform destroy
```

`yes` 입력하면 모든 AWS 리소스 삭제

### 다시 시작
```bash
terraform apply
```

## 🔧 커스터마이징

### Hasura 버전 변경
`user_data.sh`에서:
```yaml
image: hasura/graphql-engine:v2.38.0  # 버전 변경
```

### 포트 변경
`main.tf`의 Security Group에서:
```hcl
from_port   = 8080  # 원하는 포트로 변경
to_port     = 8080
```

### 리전 변경
`terraform.tfvars`에서:
```hcl
aws_region = "us-east-1"  # 다른 리전으로 변경
```

## 📝 파일 구조
```
hasura-terraform/
├── main.tf              # 메인 Terraform 설정
├── user_data.sh         # EC2 초기화 스크립트
├── terraform.tfvars     # 변수 값 (절대 커밋하지 말 것!)
├── .gitignore          # Git 무시 파일
└── README.md           # 이 가이드
```

## 📊 CloudWatch 로그 모니터링

### 로그 그룹
- `/aws/ec2/hasura` - Hasura 애플리케이션 로그 (14일 보존)
- `/aws/ec2/hasura/system` - 시스템 로그 (7일 보존)

### 수집되는 로그
- **Hasura 로그**: Docker 컨테이너 로그
- **시스템 로그**: syslog, auth.log, user-data.log
- **메트릭**: CPU, 메모리, 디스크, 네트워크 사용량

### CloudWatch에서 확인
1. **AWS Console → CloudWatch → Logs → Log groups**
2. **AWS Console → CloudWatch → Metrics → CWAgent**

### 로그 검색 예시
```bash
# Hasura 에러 로그 검색
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
```

## 🔒 보안 설정

### CORS 도메인 제한
- 허용된 도메인만 Hasura에 접근 가능
- `user_data.sh`에서 `HASURA_GRAPHQL_CORS_DOMAIN` 설정

### IP 접근 제한
- `terraform.tfvars`에서 `allowed_ips` 설정
- 특정 IP에서만 Hasura 포트(8080) 접근 가능

### JWT Secret 분리 관리
- AWS Secrets Manager에서 별도 관리
- Admin Secret과 JWT Secret 분리

## 🎯 다음 단계

1. **HTTPS 설정**: ALB + ACM 인증서 추가
2. **도메인 연결**: Route53으로 도메인 연결
3. **백업**: Neon의 자동 백업 기능 활용
4. **CI/CD**: GitHub Actions로 자동 배포
5. **알람 설정**: CloudWatch 알람으로 이상 상황 감지

## ❓ 문제 해결

### Hasura가 시작되지 않을 때
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<EC2_IP>
sudo docker logs hasura
sudo docker ps -a
```

### EC2 접속이 안 될 때
- Security Group에서 내 IP가 올바른지 확인
- `terraform.tfvars`의 `my_ip` 값 확인 (끝에 `/32` 붙었는지)

### Neon DB 연결 오류
- Secrets Manager에서 `hasura/database_url` 값 확인
- Neon 프로젝트가 활성 상태인지 확인
- Compute 시간 한도 초과 여부 확인

### CloudWatch 로그가 안 보일 때
```bash
# CloudWatch Agent 상태 확인
sudo systemctl status amazon-cloudwatch-agent

# 로그 파일 확인
sudo tail -f /var/log/hasura.log
```

### JWT Secret 오류
- Secrets Manager에서 `hasura/jwt_secret` 값이 32자 이상인지 확인
- IAM 권한이 올바른지 확인

## 📚 참고 자료

- [Hasura 공식 문서](https://hasura.io/docs/latest/index/)
- [Neon 문서](https://neon.tech/docs/introduction)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
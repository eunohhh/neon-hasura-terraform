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

### 3. terraform.tfvars 파일 생성
```bash
cat > terraform.tfvars <<EOF
aws_region = "ap-northeast-2"  # 서울 리전

# Neon DB 연결 URL (본인의 URL로 교체)
neon_database_url = "postgresql://user:password@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"

# Hasura 관리자 비밀번호 (원하는 강력한 비밀번호 설정)
hasura_admin_secret = "your-super-secret-password-here"

# 내 IP 주소 (SSH 접속용, /32 붙이기)
my_ip = "123.456.789.012/32"
EOF
```

⚠️ **중요**: `terraform.tfvars` 파일은 `.gitignore`에 추가하세요!

### 4. Terraform 초기화
```bash
terraform init
```

### 5. 실행 계획 확인
```bash
terraform plan -out=myplan.tfplan
```

### 6. 인프라 배포
```bash
terraform apply myplan.tfplan
```

`yes` 입력 후 약 3-5분 대기

### 7. 출력 정보 확인
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

## 🎯 다음 단계

1. **HTTPS 설정**: ALB + ACM 인증서 추가
2. **도메인 연결**: Route53으로 도메인 연결
3. **모니터링**: CloudWatch 로그 설정
4. **백업**: Neon의 자동 백업 기능 활용
5. **CI/CD**: GitHub Actions로 자동 배포

## ❓ 문제 해결

### Hasura가 시작되지 않을 때
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<EC2_IP>
cd ~/hasura
docker-compose logs -f
```

### EC2 접속이 안 될 때
- Security Group에서 내 IP가 올바른지 확인
- `terraform.tfvars`의 `my_ip` 값 확인 (끝에 `/32` 붙었는지)

### Neon DB 연결 오류
- Connection string이 올바른지 확인
- Neon 프로젝트가 활성 상태인지 확인
- `?sslmode=require` 파라미터 확인

## 📚 참고 자료

- [Hasura 공식 문서](https://hasura.io/docs/latest/index/)
- [Neon 문서](https://neon.tech/docs/introduction)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
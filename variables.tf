variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2" # 서울 리전
}

variable "my_ip" {
  description = "SSH 접속을 허용할 내 IP 목록 (예: [\"1.2.3.4/32\", \"5.6.7.8/32\"])"
  type        = list(string)
}

variable "allowed_ips" {
  description = "Hasura 접근을 허용할 IP 목록"
  type        = list(string)
  default     = []
}

variable "cors_domains" {
  description = "Hasura CORS 허용 도메인 목록"
  type        = list(string)
  default     = ["http://localhost:3000", "https://localhost:3000"]
}

variable "ssh_public_key_path" {
  description = "SSH 공개키 파일 경로"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}


# Neovim Snippets Collection

llm-snippets 리포지토리를 기반으로 만든 Neovim용 스니펫 모음입니다.

## 포함된 스니펫
- **Terraform**: AWS 리소스 및 설정 템플릿
- **YAML**: Terraform instruction, Docker Compose, Kubernetes, GitHub Actions, Ansible

## 설치

1. 스니펫 파일이 이미 `~/.config/nvim/snippets/terraform.lua`에 생성되어 있습니다.
2. LuaSnip 설정이 `lua/plugins/user.lua`에 자동으로 추가되어 있습니다.
3. Neovim을 재시작하면 스니펫이 자동으로 로드됩니다.

## 사용법

`.tf` 파일에서 스니펫 트리거를 입력하고 `Tab`을 눌러 확장할 수 있습니다.

## 사용 가능한 스니펫

| 트리거 | 설명 |
|---------|------|
| `tfaws` | AWS provider (기본 region: ap-northeast-2) |
| `tfaws_profile` | AWS provider with profile |
| `tfreqp_aws` | Terraform required_providers for AWS |
| `tfbackend_s3` | S3 backend 설정 |
| `tfterraform_backend_s3` | Terraform block with S3 backend |
| `tfaws_all` | 전체 설정 (terraform + required_providers + S3 backend + AWS provider) |
| `tfvar` | Variable 정의 템플릿 |
| `tfout` | Output 정의 템플릿 |
| `tfres` | 일반 리소스 템플릿 |
| `tfdata` | 일반 data source 템플릿 |
| `tfmod` | Module block with version |
| `tflocals_tags` | 공통 태그 locals block |
| `tfvpc` | AWS VPC 리소스 |
| `tfsubnet` | AWS Subnet 리소스 |
| `tfsg` | AWS Security Group 리소스 |
| `tfec2` | AWS EC2 Instance 리소스 |
| `tfrds` | AWS RDS Instance 리소스 |

## YAML 스니펫

**Location**: `snippets/yaml.lua`

### 사용 가능한 트리거

| 트리거 | 설명 |
|---------|------|
| `tf_import_task` | Terraform import 작업 instruction template |
| `tf_refactor_task` | Terraform refactor 작업 instruction template |
| `yaml_task` | 일반적인 YAML 작업 템플릿 |
| `docker_compose` | Docker Compose 파일 템플릿 |
| `k8s_deployment` | Kubernetes Deployment 템플릿 |
| `k8s_service` | Kubernetes Service 템플릿 |
| `github_actions` | GitHub Actions workflow 템플릿 |
| `ansible_playbook` | Ansible playbook 템플릿 |

## 기본값

- **AWS Region**: `ap-northeast-2`
- **S3 Backend Bucket**: `dealertire-terraform-state-bucket`
- **S3 Backend Key**: `tirepick-prod/database/terraform.tfstate`
- **AWS Provider Version**: `5.99.1`
- **Project Tags**: `tirepick` (Project), `prod` (Environment)

## 사용 예시

### 완전한 Terraform 설정 (`tfaws_all`)
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.99.1"
    }
  }
  backend "s3" {
    bucket       = "dealertire-terraform-state-bucket"
    key          = "tirepick-prod/database/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}
```

### VPC 생성 (`tfvpc`)
```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "main-vpc"
  })
}
```

### Docker Compose 예시 (`docker_compose`)
```yaml
version: '3.8'
services:
  app:
    image: nginx:latest
    container_name: my-app
    ports:
      - "8080:80"
    environment:
      - ENV_VAR=value
    volumes:
      - ./data:/app/data
    restart: unless-stopped
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  app-data:
    driver: local
```

### Kubernetes Deployment 예시 (`k8s_deployment`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        ports:
        - containerPort: 8080
        env:
        - name: ENV_VAR
          value: "value"
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
          requests:
            memory: "256Mi"
            cpu: "250m"
```

## 커스터마이징

스니펫을 수정하려면 `~/.config/nvim/snippets/terraform.lua` 파일을 편집하고 Neovim을 재시작하거나 `:LuaSnipUnlinkCurrent` 후 `:source %`를 실행하세요.

## 참고

- 원본: [llm-snippets repository](https://github.com/Klassikcat/llm-snippets)
- 스니펫 엔진: [LuaSnip](https://github.com/L3MON4D3/LuaSnip)
- 에디터: Neovim with AstroNvim
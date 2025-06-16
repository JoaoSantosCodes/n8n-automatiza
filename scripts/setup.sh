#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para logging
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
    esac
    
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Função para validar pré-requisitos
check_prerequisites() {
    log "INFO" "Verificando pré-requisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl não encontrado"
        exit 1
    fi
    
    # Verificar helm
    if ! command -v helm &> /dev/null; then
        log "ERROR" "helm não encontrado"
        exit 1
    fi
    
    # Verificar terraform
    if ! command -v terraform &> /dev/null; then
        log "ERROR" "terraform não encontrado"
        exit 1
    fi
    
    # Verificar aws cli
    if ! command -v aws &> /dev/null; then
        log "ERROR" "aws cli não encontrado"
        exit 1
    fi
    
    # Verificar git
    if ! command -v git &> /dev/null; then
        log "ERROR" "git não encontrado"
        exit 1
    fi
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para configurar AWS
setup_aws() {
    log "INFO" "Configurando AWS..."
    
    # Solicitar credenciais
    read -p "Digite o AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -p "Digite o AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    read -p "Digite a região AWS (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    # Configurar AWS CLI
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    aws configure set default.region "$AWS_REGION"
    
    # Verificar configuração
    if ! aws sts get-caller-identity &> /dev/null; then
        log "ERROR" "Falha na configuração da AWS"
        exit 1
    fi
    
    log "INFO" "AWS configurada com sucesso"
}

# Função para configurar Git
setup_git() {
    log "INFO" "Configurando Git..."
    
    # Solicitar informações
    read -p "Digite seu nome para o Git: " GIT_NAME
    read -p "Digite seu email para o Git: " GIT_EMAIL
    
    # Configurar Git
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    
    log "INFO" "Git configurado com sucesso"
}

# Função para configurar Terraform
setup_terraform() {
    log "INFO" "Configurando Terraform..."
    
    # Criar diretório terraform
    mkdir -p terraform
    cd terraform
    
    # Inicializar Terraform
    cat > main.tf << EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
  
  backend "s3" {
    bucket         = "n8n-enterprise-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
EOF
    
    # Criar arquivo de variáveis
    cat > variables.tf << EOF
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "n8n-production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}
EOF
    
    # Inicializar Terraform
    terraform init
    
    cd ..
    
    log "INFO" "Terraform configurado com sucesso"
}

# Função para configurar Kubernetes
setup_kubernetes() {
    log "INFO" "Configurando Kubernetes..."
    
    # Criar namespaces
    kubectl create namespace n8n
    kubectl create namespace monitoring
    kubectl create namespace sonarqube
    
    # Configurar RBAC
    cat > kubernetes/base/rbac.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: n8n-sa
  namespace: n8n
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: n8n-role
  namespace: n8n
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: n8n-rolebinding
  namespace: n8n
subjects:
- kind: ServiceAccount
  name: n8n-sa
  namespace: n8n
roleRef:
  kind: Role
  name: n8n-role
  apiGroup: rbac.authorization.k8s.io
EOF
    
    kubectl apply -f kubernetes/base/rbac.yaml
    
    log "INFO" "Kubernetes configurado com sucesso"
}

# Função para configurar Helm
setup_helm() {
    log "INFO" "Configurando Helm..."
    
    # Adicionar repositórios
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
    
    # Atualizar repositórios
    helm repo update
    
    log "INFO" "Helm configurado com sucesso"
}

# Função para configurar monitoramento
setup_monitoring() {
    log "INFO" "Configurando monitoramento..."
    
    # Instalar Prometheus
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set grafana.enabled=true \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
    
    # Instalar OpenTelemetry Collector
    helm install otel-collector open-telemetry/opentelemetry-collector \
        --namespace monitoring \
        --values helm/values-otel.yaml
    
    log "INFO" "Monitoramento configurado com sucesso"
}

# Função para configurar CI/CD
setup_cicd() {
    log "INFO" "Configurando CI/CD..."
    
    # Criar diretório para GitHub Actions
    mkdir -p .github/workflows
    
    # Criar workflow de CI
    cat > .github/workflows/ci.yaml << EOF
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '16'
    - name: Install dependencies
      run: npm ci
    - name: Run tests
      run: npm test
    - name: Run linter
      run: npm run lint
    
  sonarqube:
    runs-on: ubuntu-latest
    needs: test
    steps:
    - uses: actions/checkout@v2
    - name: SonarQube Scan
      uses: sonarsource/sonarqube-scan-action@master
      env:
        SONAR_TOKEN: \${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: \${{ secrets.SONAR_HOST_URL }}
EOF
    
    # Criar workflow de CD
    cat > .github/workflows/cd.yaml << EOF
name: CD

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: \${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: \${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push Docker image
      env:
        ECR_REGISTRY: \${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: n8n-enterprise
        IMAGE_TAG: \${{ github.ref_name }}
      run: |
        docker build -t \$ECR_REGISTRY/\$ECR_REPOSITORY:\$IMAGE_TAG .
        docker push \$ECR_REGISTRY/\$ECR_REPOSITORY:\$IMAGE_TAG
    
    - name: Update Kubernetes deployment
      run: |
        aws eks update-kubeconfig --name n8n-production
        kubectl set image deployment/n8n n8n=\$ECR_REGISTRY/\$ECR_REPOSITORY:\$IMAGE_TAG -n n8n
EOF
    
    log "INFO" "CI/CD configurado com sucesso"
}

# Função para configurar documentação
setup_docs() {
    log "INFO" "Configurando documentação..."
    
    # Criar README.md
    cat > README.md << EOF
# n8n Enterprise

Ambiente enterprise para n8n com as seguintes funcionalidades:

- GPT Service
- HashiCorp Vault
- OpenTelemetry
- Federation Controller
- AI Analytics
- ArgoCD
- SonarQube
- Monitoramento completo
- CI/CD automatizado

## Pré-requisitos

- kubectl
- helm
- terraform
- aws cli
- git

## Instalação

1. Clone o repositório
2. Execute \`./scripts/setup.sh\`
3. Siga as instruções

## Uso

- \`./scripts/install.sh\`: Instala todos os componentes
- \`./scripts/update.sh\`: Atualiza componentes
- \`./scripts/backup.sh\`: Realiza backup
- \`./scripts/restore.sh\`: Restaura backup
- \`./scripts/monitor.sh\`: Monitora ambiente
- \`./scripts/rollback.sh\`: Realiza rollback

## Contribuição

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes.

## Licença

MIT
EOF
    
    # Criar CONTRIBUTING.md
    cat > CONTRIBUTING.md << EOF
# Contribuindo

1. Fork o projeto
2. Crie sua feature branch (\`git checkout -b feature/AmazingFeature\`)
3. Commit suas mudanças (\`git commit -m 'Add some AmazingFeature'\`)
4. Push para a branch (\`git push origin feature/AmazingFeature\`)
5. Abra um Pull Request

## Padrões de código

- Use ESLint
- Escreva testes
- Documente suas mudanças
- Siga o padrão de commits convencional
EOF
    
    # Criar LICENSE
    cat > LICENSE << EOF
MIT License

Copyright (c) 2024 n8n Enterprise

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    
    log "INFO" "Documentação configurada com sucesso"
}

# Função principal
main() {
    check_prerequisites
    
    # Perguntar se deseja continuar
    read -p "Isso irá configurar todo o ambiente n8n enterprise. Continuar? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    setup_aws
    setup_git
    setup_terraform
    setup_kubernetes
    setup_helm
    setup_monitoring
    setup_cicd
    setup_docs
    
    log "INFO" "Configuração concluída com sucesso!"
    log "INFO" "Execute './scripts/install.sh' para instalar os componentes"
}

# Executar script
main "$@" 
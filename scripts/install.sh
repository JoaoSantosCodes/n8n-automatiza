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
    
    # Verificar argocd
    if ! command -v argocd &> /dev/null; then
        log "ERROR" "argocd não encontrado"
        exit 1
    fi
    
    # Verificar aws cli
    if ! command -v aws &> /dev/null; then
        log "ERROR" "aws cli não encontrado"
        exit 1
    fi
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para configurar AWS
setup_aws() {
    log "INFO" "Configurando AWS..."
    
    # Verificar credenciais
    if ! aws sts get-caller-identity &> /dev/null; then
        log "ERROR" "Credenciais AWS inválidas"
        exit 1
    fi
    
    # Criar bucket para Terraform state
    aws s3api create-bucket \
        --bucket n8n-enterprise-terraform-state \
        --region us-east-1
    
    # Habilitar versionamento
    aws s3api put-bucket-versioning \
        --bucket n8n-enterprise-terraform-state \
        --versioning-configuration Status=Enabled
    
    # Criar tabela DynamoDB para lock
    aws dynamodb create-table \
        --table-name terraform-state-lock \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region us-east-1
    
    log "INFO" "AWS configurada com sucesso"
}

# Função para configurar infraestrutura
setup_infrastructure() {
    log "INFO" "Configurando infraestrutura com Terraform..."
    
    cd terraform
    
    # Inicializar Terraform
    terraform init
    
    # Aplicar configuração
    terraform apply -auto-approve
    
    # Atualizar kubeconfig
    aws eks update-kubeconfig --name n8n-production --region us-east-1
    
    cd ..
    
    log "INFO" "Infraestrutura configurada com sucesso"
}

# Função para configurar Helm
setup_helm() {
    log "INFO" "Configurando Helm..."
    
    # Adicionar repositórios
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    
    # Atualizar repositórios
    helm repo update
    
    log "INFO" "Helm configurado com sucesso"
}

# Função para configurar ArgoCD
setup_argocd() {
    log "INFO" "Configurando ArgoCD..."
    
    # Criar namespace
    kubectl create namespace argocd
    
    # Instalar ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Esperar pods estarem prontos
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd
    
    # Aplicar configuração
    kubectl apply -f argocd/application.yaml
    
    # Obter senha inicial
    local password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log "INFO" "Senha inicial do ArgoCD: $password"
    
    log "INFO" "ArgoCD configurado com sucesso"
}

# Função para configurar SonarQube
setup_sonarqube() {
    log "INFO" "Configurando SonarQube..."
    
    # Adicionar repositório Helm
    helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
    helm repo update
    
    # Instalar SonarQube
    helm install sonarqube sonarqube/sonarqube \
        --namespace sonarqube \
        --create-namespace \
        --set persistence.enabled=true
    
    # Esperar pod estar pronto
    kubectl wait --for=condition=ready pod -l app=sonarqube -n sonarqube
    
    log "INFO" "SonarQube configurado com sucesso"
}

# Função para configurar Renovate
setup_renovate() {
    log "INFO" "Configurando Renovate..."
    
    # Criar secret com token do GitHub
    kubectl create secret generic renovate-token \
        --from-literal=RENOVATE_TOKEN=$GITHUB_TOKEN \
        -n n8n
    
    # Aplicar configuração
    kubectl apply -f kubernetes/base/renovate/
    
    log "INFO" "Renovate configurado com sucesso"
}

# Função para instalar componentes n8n
install_components() {
    log "INFO" "Instalando componentes n8n..."
    
    # Criar namespace
    kubectl create namespace n8n
    
    # Aplicar configurações base
    kubectl apply -k kubernetes/base/
    
    # Instalar Helm chart
    helm install n8n-enterprise helm/ \
        --namespace n8n \
        --values helm/values.yaml
    
    log "INFO" "Componentes instalados com sucesso"
}

# Função para verificar instalação
verify_installation() {
    log "INFO" "Verificando instalação..."
    
    # Verificar pods
    kubectl get pods -n n8n
    kubectl get pods -n argocd
    kubectl get pods -n sonarqube
    
    # Verificar serviços
    kubectl get svc -n n8n
    
    # Verificar ingress
    kubectl get ingress -n n8n
    
    # Verificar Helm releases
    helm list -n n8n
    
    # Verificar aplicações ArgoCD
    argocd app list
    
    log "INFO" "Verificação concluída"
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
    
    # Solicitar token do GitHub
    read -p "Digite o token do GitHub para o Renovate: " GITHUB_TOKEN
    
    setup_aws
    setup_infrastructure
    setup_helm
    setup_argocd
    setup_sonarqube
    setup_renovate
    install_components
    verify_installation
    
    log "INFO" "Instalação concluída com sucesso!"
    log "INFO" "Acesse o ArgoCD em: https://argocd.seu-dominio.com"
    log "INFO" "Acesse o n8n em: https://n8n.seu-dominio.com"
    log "INFO" "Acesse o SonarQube em: https://sonarqube.seu-dominio.com"
}

# Executar script
main "$@" 
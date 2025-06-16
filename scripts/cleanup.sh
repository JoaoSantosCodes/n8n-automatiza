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
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para limpar namespaces
cleanup_namespaces() {
    log "INFO" "Limpando namespaces..."
    
    # Lista de namespaces para remover
    local namespaces=("n8n" "monitoring" "sonarqube" "argocd")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log "INFO" "Removendo namespace $ns..."
            kubectl delete namespace "$ns"
        fi
    done
    
    log "INFO" "Namespaces removidos"
}

# Função para limpar Helm releases
cleanup_helm() {
    log "INFO" "Limpando Helm releases..."
    
    # Remover todas as releases
    helm list --all-namespaces | tail -n +2 | awk '{print $1}' | while read -r release; do
        log "INFO" "Removendo release $release..."
        helm uninstall "$release" --namespace $(helm list --all-namespaces | grep "$release" | awk '{print $2}')
    done
    
    # Remover repositórios
    helm repo remove hashicorp
    helm repo remove open-telemetry
    helm repo remove prometheus-community
    helm repo remove grafana
    helm repo remove sonarqube
    
    log "INFO" "Helm releases removidas"
}

# Função para limpar infraestrutura AWS
cleanup_aws() {
    log "INFO" "Limpando recursos AWS..."
    
    # Destruir recursos do Terraform
    cd terraform
    terraform destroy -auto-approve
    cd ..
    
    # Remover bucket do Terraform state
    aws s3 rb s3://n8n-enterprise-terraform-state --force
    
    # Remover tabela DynamoDB
    aws dynamodb delete-table --table-name terraform-state-lock
    
    # Remover bucket de backups
    aws s3 rb s3://n8n-enterprise-backups --force
    
    log "INFO" "Recursos AWS removidos"
}

# Função para limpar arquivos locais
cleanup_local() {
    log "INFO" "Limpando arquivos locais..."
    
    # Remover diretórios
    rm -rf terraform/
    rm -rf kubernetes/
    rm -rf helm/
    rm -rf .github/
    rm -rf scripts/
    
    # Remover arquivos
    rm -f README.md
    rm -f CONTRIBUTING.md
    rm -f LICENSE
    rm -f .gitignore
    
    log "INFO" "Arquivos locais removidos"
}

# Função para limpar configurações
cleanup_config() {
    log "INFO" "Limpando configurações..."
    
    # Limpar kubeconfig
    kubectl config delete-context n8n-production
    kubectl config delete-cluster n8n-production
    kubectl config delete-user n8n-production
    
    # Limpar AWS CLI
    aws configure --profile default set aws_access_key_id ""
    aws configure --profile default set aws_secret_access_key ""
    aws configure --profile default set region ""
    
    log "INFO" "Configurações removidas"
}

# Função principal
main() {
    check_prerequisites
    
    # Perguntar se deseja continuar
    read -p "ATENÇÃO: Isso irá remover TODOS os recursos e dados do ambiente n8n enterprise. Esta ação é IRREVERSÍVEL. Continuar? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    # Perguntar se deseja fazer backup
    read -p "Deseja realizar backup antes de limpar? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./backup.sh
    fi
    
    cleanup_namespaces
    cleanup_helm
    cleanup_aws
    cleanup_config
    
    # Perguntar se deseja remover arquivos locais
    read -p "Deseja remover todos os arquivos locais? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_local
    fi
    
    log "INFO" "Limpeza concluída com sucesso!"
}

# Executar script
main "$@" 
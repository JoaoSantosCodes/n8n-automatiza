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
    
    # Verificar aws cli
    if ! command -v aws &> /dev/null; then
        log "ERROR" "aws cli não encontrado"
        exit 1
    fi
    
    # Verificar vault
    if ! command -v vault &> /dev/null; then
        log "ERROR" "vault cli não encontrado"
        exit 1
    fi
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para baixar backup do S3
download_from_s3() {
    local backup_timestamp=$1
    local bucket="n8n-enterprise-backups"
    local temp_dir="/tmp/n8n_restore_${backup_timestamp}"
    
    log "INFO" "Baixando backup do S3..."
    
    # Criar diretório temporário
    mkdir -p "$temp_dir"
    
    # Baixar backup
    aws s3 cp "s3://${bucket}/backup_${backup_timestamp}.tar.gz" "${temp_dir}/backup.tar.gz"
    
    # Extrair backup
    cd "$temp_dir"
    tar xzf backup.tar.gz
    rm backup.tar.gz
    
    echo "$temp_dir"
}

# Função para restaurar n8n
restore_n8n() {
    local backup_dir=$1
    log "INFO" "Restaurando n8n..."
    
    # Restaurar workflows
    kubectl exec -n n8n $(kubectl get pod -l app=n8n -n n8n -o jsonpath="{.items[0].metadata.name}") -- \
        rm -rf /root/.n8n/*
    kubectl cp "$backup_dir/n8n/workflows.tar.gz" n8n/$(kubectl get pod -l app=n8n -n n8n -o jsonpath="{.items[0].metadata.name}"):/tmp/
    kubectl exec -n n8n $(kubectl get pod -l app=n8n -n n8n -o jsonpath="{.items[0].metadata.name}") -- \
        tar xzf /tmp/workflows.tar.gz -C /
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/n8n/configmaps.yaml"
    kubectl apply -f "$backup_dir/n8n/secrets.yaml"
    
    # Reiniciar pod
    kubectl rollout restart deployment n8n -n n8n
    
    log "INFO" "n8n restaurado com sucesso"
}

# Função para restaurar Vault
restore_vault() {
    local backup_dir=$1
    log "INFO" "Restaurando Vault..."
    
    # Restaurar snapshot
    vault operator raft snapshot restore "$backup_dir/vault/vault.snap"
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/vault/statefulset.yaml"
    kubectl apply -f "$backup_dir/vault/configmaps.yaml"
    kubectl apply -f "$backup_dir/vault/secrets.yaml"
    
    log "INFO" "Vault restaurado com sucesso"
}

# Função para restaurar OpenTelemetry
restore_otel() {
    local backup_dir=$1
    log "INFO" "Restaurando OpenTelemetry..."
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/otel/deployment.yaml"
    kubectl apply -f "$backup_dir/otel/configmaps.yaml"
    
    log "INFO" "OpenTelemetry restaurado com sucesso"
}

# Função para restaurar GPT Service
restore_gpt() {
    local backup_dir=$1
    log "INFO" "Restaurando GPT Service..."
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/gpt/deployment.yaml"
    kubectl apply -f "$backup_dir/gpt/configmaps.yaml"
    kubectl apply -f "$backup_dir/gpt/secrets.yaml"
    
    log "INFO" "GPT Service restaurado com sucesso"
}

# Função para restaurar Federation Controller
restore_federation() {
    local backup_dir=$1
    log "INFO" "Restaurando Federation Controller..."
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/federation/deployment.yaml"
    kubectl apply -f "$backup_dir/federation/configmaps.yaml"
    kubectl apply -f "$backup_dir/federation/secrets.yaml"
    
    log "INFO" "Federation Controller restaurado com sucesso"
}

# Função para restaurar AI Analytics
restore_ai_analytics() {
    local backup_dir=$1
    log "INFO" "Restaurando AI Analytics..."
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/ai-analytics/deployment.yaml"
    kubectl apply -f "$backup_dir/ai-analytics/configmaps.yaml"
    kubectl apply -f "$backup_dir/ai-analytics/secrets.yaml"
    
    log "INFO" "AI Analytics restaurado com sucesso"
}

# Função para restaurar ArgoCD
restore_argocd() {
    local backup_dir=$1
    log "INFO" "Restaurando ArgoCD..."
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/argocd/applications.yaml"
    kubectl apply -f "$backup_dir/argocd/secrets.yaml"
    kubectl apply -f "$backup_dir/argocd/configmaps.yaml"
    
    # Sincronizar aplicações
    argocd app sync -l argocd.argoproj.io/instance=n8n-enterprise
    
    log "INFO" "ArgoCD restaurado com sucesso"
}

# Função para restaurar SonarQube
restore_sonarqube() {
    local backup_dir=$1
    log "INFO" "Restaurando SonarQube..."
    
    # Restaurar banco de dados
    kubectl cp "$backup_dir/sonarqube/database.sql" sonarqube/$(kubectl get pod -l app=sonarqube -n sonarqube -o jsonpath="{.items[0].metadata.name}"):/tmp/
    kubectl exec -n sonarqube $(kubectl get pod -l app=sonarqube -n sonarqube -o jsonpath="{.items[0].metadata.name}") -- \
        psql -U sonarqube -f /tmp/database.sql
    
    # Restaurar configurações
    kubectl apply -f "$backup_dir/sonarqube/deployment.yaml"
    kubectl apply -f "$backup_dir/sonarqube/configmaps.yaml"
    kubectl apply -f "$backup_dir/sonarqube/secrets.yaml"
    
    log "INFO" "SonarQube restaurado com sucesso"
}

# Função para verificar restauração
verify_restore() {
    log "INFO" "Verificando restauração..."
    
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

# Função para limpar arquivos temporários
cleanup() {
    local temp_dir=$1
    log "INFO" "Limpando arquivos temporários..."
    rm -rf "$temp_dir"
    log "INFO" "Limpeza concluída"
}

# Função principal
main() {
    local backup_timestamp=$1
    
    if [ -z "$backup_timestamp" ]; then
        log "ERROR" "Timestamp do backup não fornecido"
        echo "Uso: $0 YYYYMMDD_HHMMSS"
        exit 1
    fi
    
    check_prerequisites
    
    # Perguntar se deseja continuar
    read -p "Isso irá restaurar todo o ambiente n8n enterprise para o backup $backup_timestamp. Continuar? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    local temp_dir=$(download_from_s3 "$backup_timestamp")
    local backup_dir="${temp_dir}/tmp/n8n_backup_${backup_timestamp}"
    
    restore_n8n "$backup_dir"
    restore_vault "$backup_dir"
    restore_otel "$backup_dir"
    restore_gpt "$backup_dir"
    restore_federation "$backup_dir"
    restore_ai_analytics "$backup_dir"
    restore_argocd "$backup_dir"
    restore_sonarqube "$backup_dir"
    
    verify_restore
    cleanup "$temp_dir"
    
    log "INFO" "Restauração concluída com sucesso!"
}

# Executar script
main "$@" 
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

# Função para backup do n8n
backup_n8n() {
    local backup_dir=$1
    log "INFO" "Realizando backup do n8n..."
    
    # Criar diretório
    mkdir -p "$backup_dir/n8n"
    
    # Backup dos workflows
    kubectl exec -n n8n $(kubectl get pod -l app=n8n -n n8n -o jsonpath="{.items[0].metadata.name}") -- \
        tar czf - /root/.n8n > "$backup_dir/n8n/workflows.tar.gz"
    
    # Backup das credenciais
    kubectl get secret -n n8n -o yaml > "$backup_dir/n8n/secrets.yaml"
    
    # Backup das configurações
    kubectl get configmap -n n8n -o yaml > "$backup_dir/n8n/configmaps.yaml"
    
    log "INFO" "Backup do n8n concluído"
}

# Função para backup do Vault
backup_vault() {
    local backup_dir=$1
    log "INFO" "Realizando backup do Vault..."
    
    # Criar diretório
    mkdir -p "$backup_dir/vault"
    
    # Backup do Vault
    vault operator raft snapshot save "$backup_dir/vault/vault.snap"
    
    # Backup das configurações
    kubectl get statefulset vault -n n8n -o yaml > "$backup_dir/vault/statefulset.yaml"
    kubectl get configmap -n n8n -l app=vault -o yaml > "$backup_dir/vault/configmaps.yaml"
    kubectl get secret -n n8n -l app=vault -o yaml > "$backup_dir/vault/secrets.yaml"
    
    log "INFO" "Backup do Vault concluído"
}

# Função para backup do OpenTelemetry
backup_otel() {
    local backup_dir=$1
    log "INFO" "Realizando backup do OpenTelemetry..."
    
    # Criar diretório
    mkdir -p "$backup_dir/otel"
    
    # Backup das configurações
    kubectl get deployment otel-collector -n n8n -o yaml > "$backup_dir/otel/deployment.yaml"
    kubectl get configmap -n n8n -l app=otel-collector -o yaml > "$backup_dir/otel/configmaps.yaml"
    
    log "INFO" "Backup do OpenTelemetry concluído"
}

# Função para backup do GPT Service
backup_gpt() {
    local backup_dir=$1
    log "INFO" "Realizando backup do GPT Service..."
    
    # Criar diretório
    mkdir -p "$backup_dir/gpt"
    
    # Backup das configurações
    kubectl get deployment gpt-service -n n8n -o yaml > "$backup_dir/gpt/deployment.yaml"
    kubectl get configmap -n n8n -l app=gpt-service -o yaml > "$backup_dir/gpt/configmaps.yaml"
    kubectl get secret -n n8n -l app=gpt-service -o yaml > "$backup_dir/gpt/secrets.yaml"
    
    log "INFO" "Backup do GPT Service concluído"
}

# Função para backup do Federation Controller
backup_federation() {
    local backup_dir=$1
    log "INFO" "Realizando backup do Federation Controller..."
    
    # Criar diretório
    mkdir -p "$backup_dir/federation"
    
    # Backup das configurações
    kubectl get deployment federation-controller -n n8n -o yaml > "$backup_dir/federation/deployment.yaml"
    kubectl get configmap -n n8n -l app=federation-controller -o yaml > "$backup_dir/federation/configmaps.yaml"
    kubectl get secret -n n8n -l app=federation-controller -o yaml > "$backup_dir/federation/secrets.yaml"
    
    log "INFO" "Backup do Federation Controller concluído"
}

# Função para backup do AI Analytics
backup_ai_analytics() {
    local backup_dir=$1
    log "INFO" "Realizando backup do AI Analytics..."
    
    # Criar diretório
    mkdir -p "$backup_dir/ai-analytics"
    
    # Backup das configurações
    kubectl get deployment ai-analytics -n n8n -o yaml > "$backup_dir/ai-analytics/deployment.yaml"
    kubectl get configmap -n n8n -l app=ai-analytics -o yaml > "$backup_dir/ai-analytics/configmaps.yaml"
    kubectl get secret -n n8n -l app=ai-analytics -o yaml > "$backup_dir/ai-analytics/secrets.yaml"
    
    log "INFO" "Backup do AI Analytics concluído"
}

# Função para backup do ArgoCD
backup_argocd() {
    local backup_dir=$1
    log "INFO" "Realizando backup do ArgoCD..."
    
    # Criar diretório
    mkdir -p "$backup_dir/argocd"
    
    # Backup das configurações
    kubectl get application -n argocd -o yaml > "$backup_dir/argocd/applications.yaml"
    kubectl get secret -n argocd -o yaml > "$backup_dir/argocd/secrets.yaml"
    kubectl get configmap -n argocd -o yaml > "$backup_dir/argocd/configmaps.yaml"
    
    log "INFO" "Backup do ArgoCD concluído"
}

# Função para backup do SonarQube
backup_sonarqube() {
    local backup_dir=$1
    log "INFO" "Realizando backup do SonarQube..."
    
    # Criar diretório
    mkdir -p "$backup_dir/sonarqube"
    
    # Backup do banco de dados
    kubectl exec -n sonarqube $(kubectl get pod -l app=sonarqube -n sonarqube -o jsonpath="{.items[0].metadata.name}") -- \
        pg_dump -U sonarqube > "$backup_dir/sonarqube/database.sql"
    
    # Backup das configurações
    kubectl get deployment sonarqube -n sonarqube -o yaml > "$backup_dir/sonarqube/deployment.yaml"
    kubectl get configmap -n sonarqube -o yaml > "$backup_dir/sonarqube/configmaps.yaml"
    kubectl get secret -n sonarqube -o yaml > "$backup_dir/sonarqube/secrets.yaml"
    
    log "INFO" "Backup do SonarQube concluído"
}

# Função para enviar backup para S3
upload_to_s3() {
    local backup_dir=$1
    local bucket="n8n-enterprise-backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    log "INFO" "Enviando backup para S3..."
    
    # Compactar backup
    tar czf "${backup_dir}.tar.gz" "$backup_dir"
    
    # Enviar para S3
    aws s3 cp "${backup_dir}.tar.gz" "s3://${bucket}/backup_${timestamp}.tar.gz"
    
    # Limpar arquivos temporários
    rm -rf "$backup_dir" "${backup_dir}.tar.gz"
    
    log "INFO" "Backup enviado para S3 com sucesso"
}

# Função para limpar backups antigos
cleanup_old_backups() {
    local bucket="n8n-enterprise-backups"
    local retention_days=30
    
    log "INFO" "Limpando backups antigos..."
    
    # Listar e deletar backups mais antigos que retention_days
    aws s3 ls "s3://${bucket}/" | while read -r line; do
        createDate=$(echo "$line" | awk {'print $1" "$2'})
        createDate=$(date -d "$createDate" +%s)
        olderThan=$(date -d "-${retention_days} days" +%s)
        
        if [[ $createDate -lt $olderThan ]]; then
            fileName=$(echo "$line" | awk {'print $4'})
            aws s3 rm "s3://${bucket}/${fileName}"
            log "INFO" "Backup antigo removido: ${fileName}"
        fi
    done
    
    log "INFO" "Limpeza de backups antigos concluída"
}

# Função principal
main() {
    check_prerequisites
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/tmp/n8n_backup_${timestamp}"
    
    backup_n8n "$backup_dir"
    backup_vault "$backup_dir"
    backup_otel "$backup_dir"
    backup_gpt "$backup_dir"
    backup_federation "$backup_dir"
    backup_ai_analytics "$backup_dir"
    backup_argocd "$backup_dir"
    backup_sonarqube "$backup_dir"
    
    upload_to_s3 "$backup_dir"
    cleanup_old_backups
    
    log "INFO" "Processo de backup concluído com sucesso!"
}

# Executar script
main "$@" 
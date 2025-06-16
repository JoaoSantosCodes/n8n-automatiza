#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para log
log() {
    echo -e "${2:-$YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Função para rollback do GPT Service
rollback_gpt() {
    log "Iniciando rollback do GPT Service"
    
    # Backup da configuração atual
    kubectl get deployment gpt-service -n n8n -o yaml > backups/gpt-service-$(date +%Y%m%d_%H%M%S).yaml
    
    # Rollback do deployment
    kubectl rollout undo deployment/gpt-service -n n8n
    
    # Verifica status
    kubectl rollout status deployment/gpt-service -n n8n
}

# Função para rollback do Vault
rollback_vault() {
    log "Iniciando rollback do Vault"
    
    # Backup da configuração atual
    kubectl get statefulset vault -n n8n -o yaml > backups/vault-$(date +%Y%m%d_%H%M%S).yaml
    
    # Rollback do statefulset
    kubectl rollout undo statefulset/vault -n n8n
    
    # Verifica status
    kubectl rollout status statefulset/vault -n n8n
}

# Função para rollback do OpenTelemetry
rollback_otel() {
    log "Iniciando rollback do OpenTelemetry Collector"
    
    # Backup da configuração atual
    kubectl get deployment otel-collector -n n8n -o yaml > backups/otel-collector-$(date +%Y%m%d_%H%M%S).yaml
    
    # Rollback do deployment
    kubectl rollout undo deployment/otel-collector -n n8n
    
    # Verifica status
    kubectl rollout status deployment/otel-collector -n n8n
}

# Função para rollback da Federation
rollback_federation() {
    log "Iniciando rollback do Federation Controller"
    
    # Backup da configuração atual
    kubectl get deployment federation-controller -n n8n -o yaml > backups/federation-controller-$(date +%Y%m%d_%H%M%S).yaml
    
    # Rollback do deployment
    kubectl rollout undo deployment/federation-controller -n n8n
    
    # Verifica status
    kubectl rollout status deployment/federation-controller -n n8n
}

# Função para rollback do AI Analytics
rollback_ai_analytics() {
    log "Iniciando rollback do AI Analytics"
    
    # Backup da configuração atual
    kubectl get deployment predictive-analytics -n n8n -o yaml > backups/predictive-analytics-$(date +%Y%m%d_%H%M%S).yaml
    
    # Rollback do deployment
    kubectl rollout undo deployment/predictive-analytics -n n8n
    
    # Verifica status
    kubectl rollout status deployment/predictive-analytics -n n8n
}

# Função para verificar estado dos serviços
check_services() {
    log "Verificando estado dos serviços após rollback"
    
    # Lista todos os pods
    kubectl get pods -n n8n
    
    # Verifica endpoints
    for service in gpt-service vault otel-collector federation-controller predictive-analytics; do
        kubectl get endpoints $service -n n8n
    done
}

# Função principal
main() {
    local component=$1
    local version=$2
    
    # Cria diretório de backup se não existir
    mkdir -p backups
    
    case ${component} in
        "gpt")
            rollback_gpt
            ;;
        "vault")
            rollback_vault
            ;;
        "otel")
            rollback_otel
            ;;
        "federation")
            rollback_federation
            ;;
        "ai-analytics")
            rollback_ai_analytics
            ;;
        "all")
            rollback_gpt
            rollback_vault
            rollback_otel
            rollback_federation
            rollback_ai_analytics
            ;;
        *)
            echo "Uso: $0 [gpt|vault|otel|federation|ai-analytics|all] [version]"
            echo "Exemplos:"
            echo "  $0 gpt v1.0.0"
            echo "  $0 vault"
            echo "  $0 all"
            exit 1
            ;;
    esac
    
    # Verifica estado final
    check_services
}

# Executa função principal
main "$@" 
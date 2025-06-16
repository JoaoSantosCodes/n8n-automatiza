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

# Função para backup de configurações
backup_configs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="backups/config_${timestamp}"
    
    log "Criando backup das configurações em ${backup_dir}"
    
    mkdir -p "${backup_dir}"
    cp -r kubernetes/base/* "${backup_dir}/"
    cp docker-compose.yml "${backup_dir}/"
    cp .env "${backup_dir}/"
    
    echo "${backup_dir}"
}

# Função para rollback de versão específica
rollback_version() {
    local version=$1
    
    log "Iniciando rollback para versão ${version}"
    
    # Verifica se a versão existe
    if ! git rev-parse --verify ${version} >/dev/null 2>&1; then
        log "Versão ${version} não encontrada" "$RED"
        return 1
    }
    
    # Backup atual
    local backup_dir=$(backup_configs)
    
    # Checkout da versão
    if git checkout ${version}; then
        log "Checkout para versão ${version} realizado com sucesso" "$GREEN"
        
        # Atualiza dependências
        if [ -f "requirements.txt" ]; then
            pip install -r requirements.txt
        fi
        
        # Aplica configurações do Kubernetes
        kubectl apply -k kubernetes/base/
        
        # Reinicia serviços
        docker-compose down
        docker-compose up -d
        
        log "Rollback concluído com sucesso" "$GREEN"
        return 0
    else
        log "Falha no checkout para versão ${version}" "$RED"
        return 1
    fi
}

# Função para rollback de componente específico
rollback_component() {
    local component=$1
    local version=$2
    
    log "Iniciando rollback do componente ${component} para versão ${version}"
    
    case ${component} in
        "ai-analytics")
            kubectl rollout undo deployment/predictive-analytics -n n8n
            ;;
        "vault")
            kubectl rollout undo statefulset/vault -n n8n
            ;;
        "opentelemetry")
            kubectl rollout undo deployment/otel-collector -n n8n
            ;;
        "gpt")
            kubectl rollout undo deployment/gpt-service -n n8n
            ;;
        "federation")
            kubectl rollout undo deployment/federation-controller -n n8n
            ;;
        *)
            log "Componente ${component} não reconhecido" "$RED"
            return 1
            ;;
    esac
    
    log "Rollback do componente ${component} concluído" "$GREEN"
}

# Função para restaurar backup
restore_backup() {
    local backup_dir=$1
    
    if [ ! -d "${backup_dir}" ]; then
        log "Diretório de backup ${backup_dir} não encontrado" "$RED"
        return 1
    }
    
    log "Restaurando backup de ${backup_dir}"
    
    # Restaura configurações
    cp -r "${backup_dir}"/* kubernetes/base/
    cp "${backup_dir}/docker-compose.yml" ./
    cp "${backup_dir}/.env" ./
    
    # Aplica configurações
    kubectl apply -k kubernetes/base/
    
    # Reinicia serviços
    docker-compose down
    docker-compose up -d
    
    log "Restauração concluída com sucesso" "$GREEN"
}

# Função para verificar estado dos serviços
check_services() {
    log "Verificando estado dos serviços"
    
    # Verifica pods
    kubectl get pods -n n8n
    
    # Verifica serviços do Docker
    docker-compose ps
    
    # Verifica endpoints
    curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz
    local n8n_status=$?
    
    curl -s -o /dev/null -w "%{http_code}" http://localhost:8200/v1/sys/health
    local vault_status=$?
    
    if [ ${n8n_status} -eq 200 ] && [ ${vault_status} -eq 200 ]; then
        log "Todos os serviços estão funcionando" "$GREEN"
        return 0
    else
        log "Alguns serviços não estão respondendo corretamente" "$RED"
        return 1
    fi
}

# Função principal
main() {
    local action=$1
    local target=$2
    local version=$3
    
    case ${action} in
        "version")
            rollback_version ${target}
            ;;
        "component")
            rollback_component ${target} ${version}
            ;;
        "restore")
            restore_backup ${target}
            ;;
        "check")
            check_services
            ;;
        *)
            echo "Uso: $0 [version|component|restore|check] [target] [version]"
            echo "Exemplos:"
            echo "  $0 version v1.0.0"
            echo "  $0 component ai-analytics v1.1.0"
            echo "  $0 restore backups/config_20240101_120000"
            echo "  $0 check"
            exit 1
            ;;
    esac
}

# Executa função principal
main "$@" 
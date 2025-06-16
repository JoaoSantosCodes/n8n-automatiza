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

# Função para descompactar backup
extract_backup() {
    local backup_file=$1
    local extract_dir="temp_restore"
    
    log "Descompactando backup ${backup_file}"
    
    mkdir -p "${extract_dir}"
    tar -xzf "${backup_file}" -C "${extract_dir}"
    
    echo "${extract_dir}"
}

# Função para restaurar banco de dados
restore_database() {
    local backup_dir=$1
    
    log "Iniciando restauração do banco de dados"
    
    # Restaura PostgreSQL
    PGPASSWORD=$DB_PASSWORD pg_restore -h $DB_HOST -U $DB_USER -d n8n -c "${backup_dir}/database/n8n.dump"
    
    # Restaura Redis
    redis-cli -h $REDIS_HOST -a $REDIS_PASSWORD FLUSHALL
    redis-cli -h $REDIS_HOST -a $REDIS_PASSWORD --rdb "${backup_dir}/database/dump.rdb"
    
    log "Restauração do banco de dados concluída" "$GREEN"
}

# Função para restaurar Vault
restore_vault() {
    local backup_dir=$1
    
    log "Iniciando restauração do Vault"
    
    # Para o Vault
    kubectl scale statefulset vault -n n8n --replicas=0
    
    # Aguarda pods pararem
    kubectl wait --for=delete pod -l app=vault -n n8n --timeout=300s
    
    # Restaura snapshot
    kubectl cp "${backup_dir}/vault/vault.snap" n8n/vault-0:/tmp/
    kubectl exec -n n8n vault-0 -- vault operator raft snapshot restore /tmp/vault.snap
    
    # Reinicia Vault
    kubectl scale statefulset vault -n n8n --replicas=3
    
    # Aguarda pods estarem prontos
    kubectl wait --for=condition=ready pod -l app=vault -n n8n --timeout=300s
    
    log "Restauração do Vault concluída" "$GREEN"
}

# Função para restaurar configurações
restore_configs() {
    local backup_dir=$1
    
    log "Iniciando restauração das configurações"
    
    # Restaura ConfigMaps
    kubectl apply -f "${backup_dir}/configs/configmaps.yaml"
    
    # Restaura Secrets
    kubectl apply -f "${backup_dir}/configs/secrets.yaml"
    
    # Restaura manifestos do Kubernetes
    kubectl apply -k "${backup_dir}/configs/"
    
    log "Restauração das configurações concluída" "$GREEN"
}

# Função para restaurar workflows
restore_workflows() {
    local backup_dir=$1
    
    log "Iniciando restauração dos workflows"
    
    # Restaura workflows
    curl -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @"${backup_dir}/workflows/workflows.json" \
        http://localhost:5678/rest/workflows/import
    
    # Restaura credenciais
    curl -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @"${backup_dir}/workflows/credentials.json" \
        http://localhost:5678/rest/credentials/import
    
    log "Restauração dos workflows concluída" "$GREEN"
}

# Função para verificar estado dos serviços
check_services() {
    log "Verificando estado dos serviços após restauração"
    
    # Verifica pods
    kubectl get pods -n n8n
    
    # Verifica serviços
    kubectl get services -n n8n
    
    # Verifica endpoints
    for service in n8n vault otel-collector federation-controller gpt-service; do
        kubectl get endpoints $service -n n8n
    done
    
    # Testa endpoints
    curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz
    local n8n_status=$?
    
    if [ ${n8n_status} -eq 200 ]; then
        log "Serviços restaurados com sucesso" "$GREEN"
        return 0
    else
        log "Alguns serviços podem não estar funcionando corretamente" "$RED"
        return 1
    fi
}

# Função para limpar arquivos temporários
cleanup() {
    local temp_dir=$1
    
    log "Limpando arquivos temporários"
    
    rm -rf "${temp_dir}"
    
    log "Limpeza concluída" "$GREEN"
}

# Função principal
main() {
    local backup_file=$1
    
    if [ -z "${backup_file}" ]; then
        echo "Uso: $0 <arquivo_backup.tar.gz>"
        exit 1
    fi
    
    if [ ! -f "${backup_file}" ]; then
        log "Arquivo de backup não encontrado: ${backup_file}" "$RED"
        exit 1
    fi
    
    # Extrai backup
    local extract_dir=$(extract_backup "${backup_file}")
    
    # Restaura componentes
    restore_database "${extract_dir}"
    restore_vault "${extract_dir}"
    restore_configs "${extract_dir}"
    restore_workflows "${extract_dir}"
    
    # Verifica serviços
    check_services
    
    # Limpa arquivos temporários
    cleanup "${extract_dir}"
    
    log "Restauração completa concluída" "$GREEN"
}

# Carrega variáveis de ambiente
source .env

# Executa função principal
main "$@" 
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

# Função para testar componentes
test_component() {
    local component=$1
    local endpoint=$2
    local expected_status=$3

    log "Testando $component em $endpoint"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" $endpoint)
    
    if [ "$response" == "$expected_status" ]; then
        log "✓ $component OK" "$GREEN"
        return 0
    else
        log "✗ $component FALHOU (Status: $response)" "$RED"
        return 1
    fi
}

# Função para testar banco de dados
test_database() {
    log "Testando conexão com PostgreSQL"
    
    if psql -h localhost -U n8n -d n8n -c '\q' 2>/dev/null; then
        log "✓ PostgreSQL OK" "$GREEN"
        return 0
    else
        log "✗ PostgreSQL FALHOU" "$RED"
        return 1
    fi
}

# Função para testar Redis
test_redis() {
    log "Testando conexão com Redis"
    
    if redis-cli ping | grep -q 'PONG'; then
        log "✓ Redis OK" "$GREEN"
        return 0
    else
        log "✗ Redis FALHOU" "$RED"
        return 1
    fi
}

# Função para testar workflows
test_workflows() {
    log "Testando execução de workflows"
    
    # Teste de workflow básico via API
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        http://localhost:5678/api/v1/workflows/health)
    
    if [ "$(echo $response | jq -r '.status')" == "ok" ]; then
        log "✓ Workflows OK" "$GREEN"
        return 0
    else
        log "✗ Workflows FALHOU" "$RED"
        return 1
    fi
}

# Função para testar backup
test_backup() {
    log "Testando sistema de backup"
    
    if ./backup.sh test; then
        log "✓ Backup OK" "$GREEN"
        return 0
    else
        log "✗ Backup FALHOU" "$RED"
        return 1
    fi
}

# Função para testar métricas
test_metrics() {
    log "Testando coleta de métricas"
    
    response=$(curl -s http://localhost:9090/api/v1/query?query=up)
    
    if [ "$(echo $response | jq -r '.status')" == "success" ]; then
        log "✓ Métricas OK" "$GREEN"
        return 0
    else
        log "✗ Métricas FALHOU" "$RED"
        return 1
    fi
}

# Função para testar autenticação
test_auth() {
    log "Testando autenticação Keycloak"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/auth)
    
    if [ "$response" == "200" ]; then
        log "✓ Keycloak OK" "$GREEN"
        return 0
    else
        log "✗ Keycloak FALHOU" "$RED"
        return 1
    fi
}

# Função para gerar relatório
generate_report() {
    local total=$1
    local passed=$2
    local failed=$((total - passed))
    
    echo
    log "=== Relatório de Testes ==="
    log "Total de testes: $total"
    log "Testes passados: $passed" "$GREEN"
    log "Testes falhos: $failed" "$RED"
    
    if [ $failed -eq 0 ]; then
        log "✓ Todos os testes passaram!" "$GREEN"
        return 0
    else
        log "✗ Alguns testes falharam" "$RED"
        return 1
    fi
}

# Função principal
main() {
    log "Iniciando testes automatizados"
    
    local tests_total=0
    local tests_passed=0
    
    # Array de testes
    declare -A tests=(
        ["n8n"]="http://localhost:5678/healthz|200"
        ["keycloak"]="http://localhost:8080/auth/realms/n8n|200"
        ["prometheus"]="http://localhost:9090/-/healthy|200"
        ["grafana"]="http://localhost:3001/api/health|200"
        ["pushgateway"]="http://localhost:9091/-/healthy|200"
    )
    
    # Executar testes de componentes
    for component in "${!tests[@]}"; do
        IFS='|' read -r endpoint status <<< "${tests[$component]}"
        ((tests_total++))
        test_component "$component" "$endpoint" "$status" && ((tests_passed++))
    done
    
    # Testes adicionais
    ((tests_total++))
    test_database && ((tests_passed++))
    
    ((tests_total++))
    test_redis && ((tests_passed++))
    
    ((tests_total++))
    test_workflows && ((tests_passed++))
    
    ((tests_total++))
    test_backup && ((tests_passed++))
    
    ((tests_total++))
    test_metrics && ((tests_passed++))
    
    ((tests_total++))
    test_auth && ((tests_passed++))
    
    # Gerar relatório
    generate_report $tests_total $tests_passed
}

# Executar testes
main "$@" 
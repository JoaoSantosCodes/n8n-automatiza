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
    
    # Verificar curl
    if ! command -v curl &> /dev/null; then
        log "ERROR" "curl não encontrado"
        exit 1
    fi
    
    # Verificar jq
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq não encontrado"
        exit 1
    fi
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para verificar pods
check_pods() {
    local namespace=$1
    log "INFO" "Verificando pods no namespace $namespace..."
    
    # Obter status dos pods
    local pods=$(kubectl get pods -n $namespace -o json)
    local total_pods=$(echo "$pods" | jq '.items | length')
    local running_pods=$(echo "$pods" | jq '[.items[] | select(.status.phase == "Running")] | length')
    local failed_pods=$(echo "$pods" | jq '[.items[] | select(.status.phase == "Failed")] | length')
    local pending_pods=$(echo "$pods" | jq '[.items[] | select(.status.phase == "Pending")] | length')
    
    log "INFO" "Total de pods: $total_pods"
    log "INFO" "Pods rodando: $running_pods"
    
    if [ $failed_pods -gt 0 ]; then
        log "ERROR" "Pods com falha: $failed_pods"
        echo "$pods" | jq -r '.items[] | select(.status.phase == "Failed") | .metadata.name'
    fi
    
    if [ $pending_pods -gt 0 ]; then
        log "WARN" "Pods pendentes: $pending_pods"
        echo "$pods" | jq -r '.items[] | select(.status.phase == "Pending") | .metadata.name'
    fi
}

# Função para verificar recursos
check_resources() {
    local namespace=$1
    log "INFO" "Verificando recursos no namespace $namespace..."
    
    # Obter uso de CPU e memória
    kubectl top pods -n $namespace
}

# Função para verificar logs
check_logs() {
    local namespace=$1
    local minutes=${2:-5}
    log "INFO" "Verificando logs dos últimos $minutes minutos no namespace $namespace..."
    
    # Obter todos os pods
    local pods=$(kubectl get pods -n $namespace -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $pods; do
        log "INFO" "Logs do pod $pod:"
        kubectl logs --since=${minutes}m $pod -n $namespace
        echo
    done
}

# Função para verificar endpoints
check_endpoints() {
    log "INFO" "Verificando endpoints..."
    
    # n8n
    local n8n_url="https://n8n.seu-dominio.com/healthz"
    local response=$(curl -s -o /dev/null -w "%{http_code}" $n8n_url)
    if [ $response -eq 200 ]; then
        log "INFO" "n8n está respondendo (HTTP $response)"
    else
        log "ERROR" "n8n não está respondendo corretamente (HTTP $response)"
    fi
    
    # Vault
    local vault_url="https://vault.seu-dominio.com/v1/sys/health"
    local response=$(curl -s -o /dev/null -w "%{http_code}" $vault_url)
    if [ $response -eq 200 ]; then
        log "INFO" "Vault está respondendo (HTTP $response)"
    else
        log "ERROR" "Vault não está respondendo corretamente (HTTP $response)"
    fi
    
    # SonarQube
    local sonar_url="https://sonarqube.seu-dominio.com/api/system/status"
    local response=$(curl -s -o /dev/null -w "%{http_code}" $sonar_url)
    if [ $response -eq 200 ]; then
        log "INFO" "SonarQube está respondendo (HTTP $response)"
    else
        log "ERROR" "SonarQube não está respondendo corretamente (HTTP $response)"
    fi
    
    # ArgoCD
    local argocd_url="https://argocd.seu-dominio.com/api/v1/applications"
    local response=$(curl -s -o /dev/null -w "%{http_code}" $argocd_url)
    if [ $response -eq 200 ]; then
        log "INFO" "ArgoCD está respondendo (HTTP $response)"
    else
        log "ERROR" "ArgoCD não está respondendo corretamente (HTTP $response)"
    fi
}

# Função para verificar certificados
check_certificates() {
    log "INFO" "Verificando certificados..."
    
    # Listar todos os certificados
    kubectl get certificates -A
    
    # Verificar status dos certificados
    local expired_certs=$(kubectl get certificates -A -o json | jq '[.items[] | select(.status.conditions[] | select(.type == "Ready" and .status == "False"))] | length')
    
    if [ $expired_certs -gt 0 ]; then
        log "ERROR" "Existem $expired_certs certificados expirados ou com problemas"
    else
        log "INFO" "Todos os certificados estão válidos"
    fi
}

# Função para verificar backups
check_backups() {
    local bucket="n8n-enterprise-backups"
    log "INFO" "Verificando backups no S3..."
    
    # Listar backups
    aws s3 ls "s3://${bucket}/" | sort -r
    
    # Verificar último backup
    local last_backup=$(aws s3 ls "s3://${bucket}/" | sort -r | head -n1)
    if [ -z "$last_backup" ]; then
        log "ERROR" "Nenhum backup encontrado"
    else
        local backup_date=$(echo "$last_backup" | awk '{print $1" "$2}')
        local now=$(date +%s)
        local backup_time=$(date -d "$backup_date" +%s)
        local diff_hours=$(( ($now - $backup_time) / 3600 ))
        
        if [ $diff_hours -gt 24 ]; then
            log "WARN" "Último backup tem mais de 24 horas ($diff_hours horas)"
        else
            log "INFO" "Último backup realizado há $diff_hours horas"
        fi
    fi
}

# Função para verificar métricas do Prometheus
check_prometheus_metrics() {
    log "INFO" "Verificando métricas do Prometheus..."
    
    # URL do Prometheus
    local prometheus_url="http://prometheus-server.monitoring:9090"
    
    # Verificar uptime dos serviços
    local queries=(
        'up{job="n8n"}'
        'up{job="vault"}'
        'up{job="otel-collector"}'
        'up{job="gpt-service"}'
        'up{job="federation-controller"}'
        'up{job="ai-analytics"}'
    )
    
    for query in "${queries[@]}"; do
        local response=$(curl -s "${prometheus_url}/api/v1/query?query=${query}")
        local job=$(echo "$query" | cut -d'{' -f2 | cut -d'}' -f1 | cut -d'"' -f2)
        local value=$(echo "$response" | jq -r '.data.result[0].value[1]')
        
        if [ "$value" = "1" ]; then
            log "INFO" "$job está up"
        else
            log "ERROR" "$job está down"
        fi
    done
}

# Função para verificar alertas
check_alerts() {
    log "INFO" "Verificando alertas..."
    
    # Verificar alertas do Prometheus
    local alerts=$(curl -s "http://prometheus-server.monitoring:9090/api/v1/alerts")
    local firing_alerts=$(echo "$alerts" | jq '[.data.alerts[] | select(.state == "firing")] | length')
    
    if [ $firing_alerts -gt 0 ]; then
        log "ERROR" "Existem $firing_alerts alertas ativos"
        echo "$alerts" | jq -r '.data.alerts[] | select(.state == "firing") | .labels.alertname + ": " + .annotations.description'
    else
        log "INFO" "Não há alertas ativos"
    fi
}

# Função para monitoramento contínuo
monitor_continuous() {
    local interval=${1:-300} # Default 5 minutos
    
    while true; do
        clear
        log "INFO" "Iniciando verificação (intervalo: $interval segundos)"
        
        check_pods "n8n"
        check_pods "argocd"
        check_pods "sonarqube"
        check_resources "n8n"
        check_endpoints
        check_prometheus_metrics
        check_alerts
        
        log "INFO" "Próxima verificação em $interval segundos"
        sleep $interval
    done
}

# Função principal
main() {
    local action=$1
    local namespace=${2:-"n8n"}
    local interval=${3:-300}
    
    check_prerequisites
    
    case $action in
        "pods")
            check_pods "$namespace"
            ;;
        "resources")
            check_resources "$namespace"
            ;;
        "logs")
            check_logs "$namespace"
            ;;
        "endpoints")
            check_endpoints
            ;;
        "certs")
            check_certificates
            ;;
        "backups")
            check_backups
            ;;
        "metrics")
            check_prometheus_metrics
            ;;
        "alerts")
            check_alerts
            ;;
        "continuous")
            monitor_continuous "$interval"
            ;;
        *)
            echo "Uso: $0 {pods|resources|logs|endpoints|certs|backups|metrics|alerts|continuous} [namespace] [interval]"
            echo "Exemplos:"
            echo "  $0 pods n8n"
            echo "  $0 logs argocd 10"
            echo "  $0 continuous 300"
            exit 1
            ;;
    esac
}

# Executar script
main "$@" 
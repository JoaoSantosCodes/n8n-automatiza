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
    }
    
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
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para backup
backup() {
    local component=$1
    local version=$2
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="backups/${component}_${version}_${timestamp}"
    
    log "INFO" "Iniciando backup do componente $component versão $version"
    
    # Criar diretório de backup
    mkdir -p "$backup_dir"
    
    case $component in
        "n8n")
            # Backup do n8n
            kubectl get deployment n8n -n n8n -o yaml > "$backup_dir/deployment.yaml"
            kubectl get configmap n8n-config -n n8n -o yaml > "$backup_dir/configmap.yaml"
            kubectl get secret n8n-secrets -n n8n -o yaml > "$backup_dir/secrets.yaml"
            ;;
            
        "gpt")
            # Backup do GPT Service
            kubectl get deployment gpt-service -n n8n -o yaml > "$backup_dir/deployment.yaml"
            kubectl get configmap gpt-config -n n8n -o yaml > "$backup_dir/configmap.yaml"
            ;;
            
        "vault")
            # Backup do Vault
            kubectl get statefulset vault -n n8n -o yaml > "$backup_dir/statefulset.yaml"
            kubectl get configmap vault-config -n n8n -o yaml > "$backup_dir/configmap.yaml"
            vault operator raft snapshot save "$backup_dir/vault.snap"
            ;;
            
        "otel")
            # Backup do OpenTelemetry
            kubectl get deployment otel-collector -n n8n -o yaml > "$backup_dir/deployment.yaml"
            kubectl get configmap otel-collector-config -n n8n -o yaml > "$backup_dir/configmap.yaml"
            ;;
            
        "federation")
            # Backup da Federation
            kubectl get deployment federation-controller -n n8n -o yaml > "$backup_dir/deployment.yaml"
            kubectl get configmap federation-config -n n8n -o yaml > "$backup_dir/configmap.yaml"
            ;;
            
        "ai-analytics")
            # Backup do AI Analytics
            kubectl get deployment ai-analytics -n n8n -o yaml > "$backup_dir/deployment.yaml"
            kubectl get configmap ai-analytics-config -n n8n -o yaml > "$backup_dir/configmap.yaml"
            ;;
            
        "infrastructure")
            # Backup da infraestrutura
            terraform state pull > "$backup_dir/terraform.tfstate"
            cp terraform/main.tf "$backup_dir/"
            cp terraform/variables.tf "$backup_dir/"
            ;;
            
        "helm")
            # Backup das releases Helm
            helm list -n n8n -o yaml > "$backup_dir/helm_releases.yaml"
            cp -r helm/* "$backup_dir/"
            ;;
            
        "argocd")
            # Backup do ArgoCD
            kubectl get application -n argocd -o yaml > "$backup_dir/applications.yaml"
            cp -r argocd/* "$backup_dir/"
            ;;
            
        *)
            log "ERROR" "Componente $component não suportado"
            exit 1
            ;;
    esac
    
    # Compactar backup
    tar -czf "${backup_dir}.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log "INFO" "Backup concluído: ${backup_dir}.tar.gz"
}

# Função para rollback
rollback() {
    local component=$1
    local version=$2
    local backup_file=$(find backups -name "${component}_${version}_*.tar.gz" | sort -r | head -n1)
    
    if [ -z "$backup_file" ]; then
        log "ERROR" "Backup não encontrado para $component versão $version"
        exit 1
    fi
    
    log "INFO" "Iniciando rollback do componente $component para versão $version"
    
    # Extrair backup
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"
    local backup_dir=$(ls "$temp_dir")
    
    case $component in
        "n8n")
            kubectl apply -f "$temp_dir/$backup_dir/deployment.yaml"
            kubectl apply -f "$temp_dir/$backup_dir/configmap.yaml"
            kubectl apply -f "$temp_dir/$backup_dir/secrets.yaml"
            ;;
            
        "gpt")
            kubectl apply -f "$temp_dir/$backup_dir/deployment.yaml"
            kubectl apply -f "$temp_dir/$backup_dir/configmap.yaml"
            ;;
            
        "vault")
            kubectl apply -f "$temp_dir/$backup_dir/statefulset.yaml"
            kubectl apply -f "$temp_dir/$backup_dir/configmap.yaml"
            vault operator raft snapshot restore "$temp_dir/$backup_dir/vault.snap"
            ;;
            
        "otel")
            kubectl apply -f "$temp_dir/$backup_dir/deployment.yaml"
            kubectl apply -f "$temp_dir/$backup_dir/configmap.yaml"
            ;;
            
        "federation")
            kubectl apply -f "$temp_dir/$backup_dir/deployment.yaml"
            kubectl apply -f "$temp_dir/$backup_dir/configmap.yaml"
            ;;
            
        "ai-analytics")
            kubectl apply -f "$temp_dir/$backup_dir/deployment.yaml"
            kubectl apply -f "$temp_dir/$backup_dir/configmap.yaml"
            ;;
            
        "infrastructure")
            terraform init
            terraform state push "$temp_dir/$backup_dir/terraform.tfstate"
            terraform apply -auto-approve
            ;;
            
        "helm")
            # Rollback das releases Helm
            while IFS= read -r release; do
                name=$(echo "$release" | yq e '.name' -)
                revision=$(echo "$release" | yq e '.revision' -)
                helm rollback "$name" "$revision" -n n8n
            done < "$temp_dir/$backup_dir/helm_releases.yaml"
            ;;
            
        "argocd")
            kubectl apply -f "$temp_dir/$backup_dir/applications.yaml"
            argocd app sync -l argocd.argoproj.io/instance=n8n-enterprise
            ;;
            
        *)
            log "ERROR" "Componente $component não suportado"
            exit 1
            ;;
    esac
    
    # Limpar arquivos temporários
    rm -rf "$temp_dir"
    
    log "INFO" "Rollback concluído com sucesso"
}

# Função para verificar status
check_status() {
    local component=$1
    
    log "INFO" "Verificando status do componente $component"
    
    case $component in
        "n8n")
            kubectl get deployment n8n -n n8n
            ;;
            
        "gpt")
            kubectl get deployment gpt-service -n n8n
            ;;
            
        "vault")
            kubectl get statefulset vault -n n8n
            vault status
            ;;
            
        "otel")
            kubectl get deployment otel-collector -n n8n
            ;;
            
        "federation")
            kubectl get deployment federation-controller -n n8n
            ;;
            
        "ai-analytics")
            kubectl get deployment ai-analytics -n n8n
            ;;
            
        "infrastructure")
            terraform show
            ;;
            
        "helm")
            helm list -n n8n
            ;;
            
        "argocd")
            argocd app list
            ;;
            
        *)
            log "ERROR" "Componente $component não suportado"
            exit 1
            ;;
    esac
}

# Função principal
main() {
    local action=$1
    local component=$2
    local version=$3
    
    check_prerequisites
    
    case $action in
        "backup")
            backup "$component" "$version"
            ;;
            
        "rollback")
            rollback "$component" "$version"
            ;;
            
        "status")
            check_status "$component"
            ;;
            
        *)
            log "ERROR" "Ação $action não suportada"
            echo "Uso: $0 {backup|rollback|status} {n8n|gpt|vault|otel|federation|ai-analytics|infrastructure|helm|argocd} [version]"
            exit 1
            ;;
    esac
}

# Executar script
main "$@" 
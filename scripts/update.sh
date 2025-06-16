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
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para atualizar repositórios Helm
update_helm_repos() {
    log "INFO" "Atualizando repositórios Helm..."
    
    helm repo update
    
    log "INFO" "Repositórios Helm atualizados"
}

# Função para atualizar n8n
update_n8n() {
    local version=$1
    log "INFO" "Atualizando n8n para versão $version..."
    
    # Realizar backup antes da atualização
    ./backup.sh
    
    # Atualizar Helm chart
    helm upgrade n8n-enterprise helm/ \
        --namespace n8n \
        --values helm/values.yaml \
        --set n8n.image.tag=$version
    
    # Verificar status
    kubectl rollout status deployment/n8n -n n8n
    
    log "INFO" "n8n atualizado com sucesso"
}

# Função para atualizar Vault
update_vault() {
    local version=$1
    log "INFO" "Atualizando Vault para versão $version..."
    
    # Realizar backup antes da atualização
    ./backup.sh
    
    # Atualizar Helm chart
    helm upgrade vault hashicorp/vault \
        --namespace n8n \
        --values helm/values-vault.yaml \
        --set image.tag=$version
    
    # Verificar status
    kubectl rollout status statefulset/vault -n n8n
    
    log "INFO" "Vault atualizado com sucesso"
}

# Função para atualizar OpenTelemetry
update_otel() {
    local version=$1
    log "INFO" "Atualizando OpenTelemetry para versão $version..."
    
    # Atualizar Helm chart
    helm upgrade otel-collector open-telemetry/opentelemetry-collector \
        --namespace n8n \
        --values helm/values-otel.yaml \
        --set image.tag=$version
    
    # Verificar status
    kubectl rollout status deployment/otel-collector -n n8n
    
    log "INFO" "OpenTelemetry atualizado com sucesso"
}

# Função para atualizar GPT Service
update_gpt() {
    local version=$1
    log "INFO" "Atualizando GPT Service para versão $version..."
    
    # Atualizar deployment
    kubectl set image deployment/gpt-service -n n8n \
        gpt-service=gpt-service:$version
    
    # Verificar status
    kubectl rollout status deployment/gpt-service -n n8n
    
    log "INFO" "GPT Service atualizado com sucesso"
}

# Função para atualizar Federation Controller
update_federation() {
    local version=$1
    log "INFO" "Atualizando Federation Controller para versão $version..."
    
    # Atualizar deployment
    kubectl set image deployment/federation-controller -n n8n \
        federation-controller=federation-controller:$version
    
    # Verificar status
    kubectl rollout status deployment/federation-controller -n n8n
    
    log "INFO" "Federation Controller atualizado com sucesso"
}

# Função para atualizar AI Analytics
update_ai_analytics() {
    local version=$1
    log "INFO" "Atualizando AI Analytics para versão $version..."
    
    # Atualizar deployment
    kubectl set image deployment/ai-analytics -n n8n \
        ai-analytics=ai-analytics:$version
    
    # Verificar status
    kubectl rollout status deployment/ai-analytics -n n8n
    
    log "INFO" "AI Analytics atualizado com sucesso"
}

# Função para atualizar ArgoCD
update_argocd() {
    local version=$1
    log "INFO" "Atualizando ArgoCD para versão $version..."
    
    # Atualizar manifests
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$version/manifests/install.yaml
    
    # Verificar status
    kubectl rollout status deployment/argocd-server -n argocd
    kubectl rollout status deployment/argocd-repo-server -n argocd
    kubectl rollout status deployment/argocd-application-controller -n argocd
    
    log "INFO" "ArgoCD atualizado com sucesso"
}

# Função para atualizar SonarQube
update_sonarqube() {
    local version=$1
    log "INFO" "Atualizando SonarQube para versão $version..."
    
    # Realizar backup antes da atualização
    ./backup.sh
    
    # Atualizar Helm chart
    helm upgrade sonarqube sonarqube/sonarqube \
        --namespace sonarqube \
        --values helm/values-sonarqube.yaml \
        --set image.tag=$version
    
    # Verificar status
    kubectl rollout status deployment/sonarqube -n sonarqube
    
    log "INFO" "SonarQube atualizado com sucesso"
}

# Função para atualizar infraestrutura
update_infrastructure() {
    log "INFO" "Atualizando infraestrutura..."
    
    # Atualizar Terraform
    cd terraform
    terraform init -upgrade
    terraform plan
    terraform apply -auto-approve
    cd ..
    
    log "INFO" "Infraestrutura atualizada com sucesso"
}

# Função para verificar atualizações
check_updates() {
    log "INFO" "Verificando atualizações disponíveis..."
    
    # Verificar atualizações do Helm
    helm repo update
    
    # Listar atualizações disponíveis
    helm list --all-namespaces | tail -n +2 | while read -r line; do
        local release=$(echo "$line" | awk '{print $1}')
        local chart=$(echo "$line" | awk '{print $9}')
        local version=$(echo "$line" | awk '{print $10}')
        local namespace=$(echo "$line" | awk '{print $2}')
        
        log "INFO" "Release: $release, Chart: $chart, Versão atual: $version, Namespace: $namespace"
        helm search repo $chart --versions | head -n 2
    done
}

# Função para rollback em caso de falha
rollback() {
    local component=$1
    local version=$2
    log "WARN" "Iniciando rollback do $component para versão $version..."
    
    case $component in
        "n8n")
            helm rollback n8n-enterprise -n n8n $version
            ;;
        "vault")
            helm rollback vault -n n8n $version
            ;;
        "otel")
            helm rollback otel-collector -n n8n $version
            ;;
        "gpt")
            kubectl rollout undo deployment/gpt-service -n n8n
            ;;
        "federation")
            kubectl rollout undo deployment/federation-controller -n n8n
            ;;
        "ai-analytics")
            kubectl rollout undo deployment/ai-analytics -n n8n
            ;;
        "argocd")
            kubectl rollout undo deployment/argocd-server -n argocd
            kubectl rollout undo deployment/argocd-repo-server -n argocd
            kubectl rollout undo deployment/argocd-application-controller -n argocd
            ;;
        "sonarqube")
            helm rollback sonarqube -n sonarqube $version
            ;;
        *)
            log "ERROR" "Componente $component não suportado para rollback"
            exit 1
            ;;
    esac
    
    log "INFO" "Rollback concluído"
}

# Função principal
main() {
    local action=$1
    local component=$2
    local version=$3
    
    check_prerequisites
    
    case $action in
        "check")
            check_updates
            ;;
        "update")
            if [ -z "$component" ] || [ -z "$version" ]; then
                log "ERROR" "Componente e versão são obrigatórios para atualização"
                echo "Uso: $0 update {n8n|vault|otel|gpt|federation|ai-analytics|argocd|sonarqube|infrastructure} VERSION"
                exit 1
            fi
            
            # Perguntar se deseja continuar
            read -p "Isso irá atualizar o componente $component para a versão $version. Continuar? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            
            update_helm_repos
            
            case $component in
                "n8n")
                    update_n8n "$version"
                    ;;
                "vault")
                    update_vault "$version"
                    ;;
                "otel")
                    update_otel "$version"
                    ;;
                "gpt")
                    update_gpt "$version"
                    ;;
                "federation")
                    update_federation "$version"
                    ;;
                "ai-analytics")
                    update_ai_analytics "$version"
                    ;;
                "argocd")
                    update_argocd "$version"
                    ;;
                "sonarqube")
                    update_sonarqube "$version"
                    ;;
                "infrastructure")
                    update_infrastructure
                    ;;
                *)
                    log "ERROR" "Componente $component não suportado"
                    exit 1
                    ;;
            esac
            ;;
        "rollback")
            if [ -z "$component" ] || [ -z "$version" ]; then
                log "ERROR" "Componente e versão são obrigatórios para rollback"
                echo "Uso: $0 rollback {n8n|vault|otel|gpt|federation|ai-analytics|argocd|sonarqube} VERSION"
                exit 1
            fi
            rollback "$component" "$version"
            ;;
        *)
            echo "Uso: $0 {check|update|rollback} [component] [version]"
            echo "Exemplos:"
            echo "  $0 check"
            echo "  $0 update n8n 1.0.0"
            echo "  $0 rollback vault 1.12.0"
            exit 1
            ;;
    esac
}

# Executar script
main "$@" 
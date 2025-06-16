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
    
    # Verificar openssl
    if ! command -v openssl &> /dev/null; then
        log "ERROR" "openssl não encontrado"
        exit 1
    fi
    
    # Verificar helm
    if ! command -v helm &> /dev/null; then
        log "ERROR" "helm não encontrado"
        exit 1
    fi
    
    log "INFO" "Todos os pré-requisitos encontrados"
}

# Função para instalar cert-manager
install_cert_manager() {
    log "INFO" "Instalando cert-manager..."
    
    # Adicionar repositório Helm
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # Instalar cert-manager
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --set prometheus.enabled=true \
        --set webhook.timeoutSeconds=30
    
    # Esperar pods estarem prontos
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager
    
    log "INFO" "cert-manager instalado com sucesso"
}

# Função para configurar ClusterIssuer
setup_cluster_issuer() {
    local email=$1
    log "INFO" "Configurando ClusterIssuer..."
    
    # Criar ClusterIssuer para Let's Encrypt
    cat > kubernetes/base/cert-manager/cluster-issuer.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $email
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    kubectl apply -f kubernetes/base/cert-manager/cluster-issuer.yaml
    
    log "INFO" "ClusterIssuer configurado com sucesso"
}

# Função para criar certificado
create_certificate() {
    local domain=$1
    local namespace=$2
    local issuer=${3:-"letsencrypt-prod"}
    
    log "INFO" "Criando certificado para $domain..."
    
    # Criar certificado
    cat > kubernetes/base/cert-manager/certificates/$domain.yaml << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${domain/./-}-tls
  namespace: $namespace
spec:
  secretName: ${domain/./-}-tls
  issuerRef:
    name: $issuer
    kind: ClusterIssuer
  commonName: $domain
  dnsNames:
  - $domain
EOF
    
    kubectl apply -f kubernetes/base/cert-manager/certificates/$domain.yaml
    
    log "INFO" "Certificado criado com sucesso"
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
        kubectl get certificates -A -o json | jq -r '.items[] | select(.status.conditions[] | select(.type == "Ready" and .status == "False")) | .metadata.name'
    else
        log "INFO" "Todos os certificados estão válidos"
    fi
}

# Função para renovar certificado
renew_certificate() {
    local domain=$1
    local namespace=$2
    
    log "INFO" "Renovando certificado para $domain..."
    
    # Deletar secret do certificado
    kubectl delete secret ${domain/./-}-tls -n $namespace
    
    # Deletar certificado
    kubectl delete certificate ${domain/./-}-tls -n $namespace
    
    # Recriar certificado
    create_certificate "$domain" "$namespace"
    
    log "INFO" "Certificado renovado com sucesso"
}

# Função para backup de certificados
backup_certificates() {
    local backup_dir="/tmp/cert-backup-$(date +%Y%m%d-%H%M%S)"
    log "INFO" "Realizando backup dos certificados em $backup_dir..."
    
    # Criar diretório de backup
    mkdir -p "$backup_dir"
    
    # Backup dos certificados
    kubectl get certificates -A -o yaml > "$backup_dir/certificates.yaml"
    
    # Backup dos secrets
    kubectl get secrets -A -o yaml | grep -A 10000 'kind: Secret' > "$backup_dir/secrets.yaml"
    
    # Backup das configurações do cert-manager
    kubectl get clusterissuer -o yaml > "$backup_dir/clusterissuer.yaml"
    
    # Compactar backup
    tar czf "${backup_dir}.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log "INFO" "Backup concluído: ${backup_dir}.tar.gz"
}

# Função para restaurar certificados
restore_certificates() {
    local backup_file=$1
    
    if [ ! -f "$backup_file" ]; then
        log "ERROR" "Arquivo de backup não encontrado: $backup_file"
        exit 1
    fi
    
    log "INFO" "Restaurando certificados de $backup_file..."
    
    # Criar diretório temporário
    local temp_dir=$(mktemp -d)
    
    # Extrair backup
    tar xzf "$backup_file" -C "$temp_dir"
    
    # Restaurar configurações
    kubectl apply -f "$temp_dir"/*/clusterissuer.yaml
    kubectl apply -f "$temp_dir"/*/certificates.yaml
    kubectl apply -f "$temp_dir"/*/secrets.yaml
    
    # Limpar
    rm -rf "$temp_dir"
    
    log "INFO" "Restauração concluída com sucesso"
}

# Função principal
main() {
    local action=$1
    shift
    
    check_prerequisites
    
    case $action in
        "install")
            install_cert_manager
            ;;
        "setup-issuer")
            if [ -z "$1" ]; then
                log "ERROR" "Email é obrigatório"
                echo "Uso: $0 setup-issuer EMAIL"
                exit 1
            fi
            setup_cluster_issuer "$1"
            ;;
        "create")
            if [ -z "$1" ] || [ -z "$2" ]; then
                log "ERROR" "Domínio e namespace são obrigatórios"
                echo "Uso: $0 create DOMAIN NAMESPACE [ISSUER]"
                exit 1
            fi
            create_certificate "$1" "$2" "$3"
            ;;
        "check")
            check_certificates
            ;;
        "renew")
            if [ -z "$1" ] || [ -z "$2" ]; then
                log "ERROR" "Domínio e namespace são obrigatórios"
                echo "Uso: $0 renew DOMAIN NAMESPACE"
                exit 1
            fi
            renew_certificate "$1" "$2"
            ;;
        "backup")
            backup_certificates
            ;;
        "restore")
            if [ -z "$1" ]; then
                log "ERROR" "Arquivo de backup é obrigatório"
                echo "Uso: $0 restore BACKUP_FILE"
                exit 1
            fi
            restore_certificates "$1"
            ;;
        *)
            echo "Uso: $0 {install|setup-issuer|create|check|renew|backup|restore} [args...]"
            echo "Exemplos:"
            echo "  $0 install"
            echo "  $0 setup-issuer admin@example.com"
            echo "  $0 create example.com default letsencrypt-prod"
            echo "  $0 check"
            echo "  $0 renew example.com default"
            echo "  $0 backup"
            echo "  $0 restore /path/to/backup.tar.gz"
            exit 1
            ;;
    esac
}

# Executar script
main "$@" 
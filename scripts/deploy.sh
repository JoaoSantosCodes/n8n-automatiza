#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Iniciando deploy do n8n Enterprise...${NC}"

# Verificar se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl não encontrado. Por favor, instale o kubectl primeiro.${NC}"
    exit 1
fi

# Verificar se helm está instalado
if ! command -v helm &> /dev/null; then
    echo -e "${RED}helm não encontrado. Por favor, instale o helm primeiro.${NC}"
    exit 1
fi

# Criar namespace se não existir
echo -e "${YELLOW}Criando namespace n8n...${NC}"
kubectl create namespace n8n --dry-run=client -o yaml | kubectl apply -f -

# Adicionar repositórios Helm necessários
echo -e "${YELLOW}Adicionando repositórios Helm...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Instalar Prometheus
echo -e "${YELLOW}Instalando Prometheus...${NC}"
helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace n8n \
    -f kubernetes/base/monitoring/prometheus-values.yaml

# Instalar Grafana
echo -e "${YELLOW}Instalando Grafana...${NC}"
helm upgrade --install grafana grafana/grafana \
    --namespace n8n \
    -f kubernetes/base/monitoring/grafana-values.yaml

# Instalar métricas de negócio
echo -e "${YELLOW}Instalando coletor de métricas de negócio...${NC}"
kubectl apply -f kubernetes/base/monitoring/business-metrics-deployment.yaml

# Configurar Keycloak
echo -e "${YELLOW}Configurando Keycloak...${NC}"
kubectl apply -f kubernetes/base/keycloak-deployment.yaml
kubectl apply -f kubernetes/base/keycloak-service.yaml

# Configurar backup
echo -e "${YELLOW}Configurando sistema de backup...${NC}"
kubectl apply -f kubernetes/base/backup/backup-pvc.yaml
kubectl apply -f kubernetes/base/backup/backup-cronjob.yaml

# Aplicar configurações do n8n
echo -e "${YELLOW}Aplicando configurações do n8n...${NC}"
kubectl apply -k kubernetes/base

# Aguardar pods estarem prontos
echo -e "${YELLOW}Aguardando pods iniciarem...${NC}"
kubectl wait --for=condition=ready pod -l app=n8n -n n8n --timeout=300s
kubectl wait --for=condition=ready pod -l app=postgres -n n8n --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n n8n --timeout=300s
kubectl wait --for=condition=ready pod -l app=keycloak -n n8n --timeout=300s
kubectl wait --for=condition=ready pod -l app=business-metrics -n n8n --timeout=300s

# Verificar status
echo -e "${YELLOW}Verificando status dos pods...${NC}"
kubectl get pods -n n8n

# Obter URLs de acesso
DOMAIN=$(kubectl get ingress -n n8n n8n -o jsonpath='{.spec.rules[0].host}')
echo -e "${GREEN}Deploy concluído!${NC}"
echo -e "${GREEN}n8n está disponível em: https://${DOMAIN}${NC}"
echo -e "${GREEN}Grafana está disponível em: https://${DOMAIN}/grafana${NC}"
echo -e "${GREEN}Keycloak está disponível em: https://${DOMAIN}/auth${NC}"

# Obter senhas
GRAFANA_PASSWORD=$(kubectl get secret --namespace n8n grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
KEYCLOAK_PASSWORD=$(kubectl get secret --namespace n8n keycloak-secrets -o jsonpath="{.data.admin_password}" | base64 --decode)

echo -e "${GREEN}Senha do Grafana: ${GRAFANA_PASSWORD}${NC}"
echo -e "${GREEN}Senha do Keycloak: ${KEYCLOAK_PASSWORD}${NC}"

# Instruções adicionais
echo -e "\n${YELLOW}Próximos passos:${NC}"
echo "1. Configure o Keycloak com seu domínio em: https://${DOMAIN}/auth"
echo "2. Crie um cliente OAuth2 no Keycloak para o n8n"
echo "3. Configure as credenciais AWS para backup em: kubectl edit secret aws-secrets -n n8n"
echo "4. Verifique os dashboards do Grafana em: https://${DOMAIN}/grafana"
echo "5. Configure alertas no Grafana conforme necessário" 
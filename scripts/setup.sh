#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Iniciando setup do ambiente n8n...${NC}"

# Verificar se o Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker não encontrado. Por favor, instale o Docker primeiro.${NC}"
    exit 1
fi

# Verificar se o Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose não encontrado. Por favor, instale o Docker Compose primeiro.${NC}"
    exit 1
fi

# Criar diretórios necessários
echo -e "${YELLOW}Criando diretórios...${NC}"
mkdir -p docker/nginx/conf.d
mkdir -p docker/nginx/ssl
mkdir -p docker/prometheus
mkdir -p docker/grafana/provisioning
mkdir -p backups
mkdir -p scripts

# Verificar se o arquivo .env existe
if [ ! -f .env ]; then
    echo -e "${YELLOW}Criando arquivo .env a partir do exemplo...${NC}"
    cp .env.example .env
    echo -e "${GREEN}Arquivo .env criado. Por favor, edite-o com suas configurações antes de continuar.${NC}"
    exit 1
fi

# Verificar certificados SSL
if [ ! -f docker/nginx/ssl/fullchain.pem ] || [ ! -f docker/nginx/ssl/privkey.pem ]; then
    echo -e "${RED}Certificados SSL não encontrados em docker/nginx/ssl/${NC}"
    echo -e "${YELLOW}Por favor, coloque seus certificados SSL em docker/nginx/ssl/ antes de continuar:${NC}"
    echo "  - fullchain.pem"
    echo "  - privkey.pem"
    exit 1
fi

# Dar permissões aos scripts
echo -e "${YELLOW}Configurando permissões dos scripts...${NC}"
chmod +x scripts/*.sh

# Criar rede Docker se não existir
if ! docker network inspect n8n-network >/dev/null 2>&1; then
    echo -e "${YELLOW}Criando rede Docker 'n8n-network'...${NC}"
    docker network create n8n-network
fi

# Parar containers existentes
echo -e "${YELLOW}Parando containers existentes...${NC}"
docker-compose down

# Limpar volumes antigos (opcional)
read -p "Deseja limpar os volumes existentes? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removendo volumes...${NC}"
    docker volume rm n8n_data pgdata waha_sessions waha_media prometheus_data grafana_data 2>/dev/null || true
fi

# Iniciar os serviços
echo -e "${YELLOW}Iniciando serviços...${NC}"
docker-compose up -d

# Verificar status dos serviços
echo -e "${YELLOW}Verificando status dos serviços...${NC}"
sleep 10

services=("n8n" "postgres" "redis" "nginx" "prometheus" "grafana" "waha")
for service in "${services[@]}"; do
    if docker-compose ps | grep -q "$service.*Up"; then
        echo -e "${GREEN}✓ $service está rodando${NC}"
    else
        echo -e "${RED}✗ $service não está rodando${NC}"
    fi
done

echo -e "\n${GREEN}Setup concluído!${NC}"
echo -e "\nAcesse:"
echo -e "n8n: https://${DOMAIN_NAME}"
echo -e "Grafana: https://${DOMAIN_NAME}/grafana"
echo -e "\n${YELLOW}Lembre-se de:"
echo "1. Verificar os logs usando 'docker-compose logs -f'"
echo "2. Fazer backup inicial usando 'scripts/backup.sh'"
echo "3. Configurar alertas no Grafana"
echo -e "4. Testar a restauração de backup${NC}" 
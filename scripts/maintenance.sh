#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Iniciando manutenção do ambiente n8n...${NC}"

# Verificar espaço em disco
echo -e "\n${YELLOW}Verificando espaço em disco...${NC}"
df -h

# Limpar logs antigos
echo -e "\n${YELLOW}Limpando logs antigos...${NC}"
find ./logs -name "*.log" -type f -mtime +7 -delete

# Limpar backups antigos
echo -e "\n${YELLOW}Limpando backups antigos...${NC}"
find ./backups -name "n8n_backup_*.tar.gz" -type f -mtime +7 -delete

# Limpar imagens Docker não utilizadas
echo -e "\n${YELLOW}Limpando recursos Docker não utilizados...${NC}"
docker system prune -f --volumes

# Verificar status dos containers
echo -e "\n${YELLOW}Verificando status dos containers...${NC}"
docker-compose ps

# Verificar logs por erros
echo -e "\n${YELLOW}Verificando logs por erros...${NC}"
for service in n8n postgres redis nginx prometheus grafana waha; do
    echo -e "\n${YELLOW}Logs do $service:${NC}"
    docker-compose logs --tail=50 $service | grep -i "error"
done

# Verificar performance do banco de dados
echo -e "\n${YELLOW}Verificando performance do PostgreSQL...${NC}"
docker-compose exec -T postgres psql -U n8n -d n8n -c "
SELECT schemaname, relname, n_live_tup, n_dead_tup, 
       round(n_dead_tup::numeric / NULLIF(n_live_tup, 0), 2) as dead_ratio
FROM pg_stat_user_tables 
WHERE n_dead_tup > 100
ORDER BY n_dead_tup DESC;
"

# Executar VACUUM no PostgreSQL
echo -e "\n${YELLOW}Executando VACUUM no PostgreSQL...${NC}"
docker-compose exec -T postgres psql -U n8n -d n8n -c "VACUUM ANALYZE;"

# Verificar tamanho do banco de dados
echo -e "\n${YELLOW}Verificando tamanho do banco de dados...${NC}"
docker-compose exec -T postgres psql -U n8n -d n8n -c "
SELECT pg_size_pretty(pg_database_size('n8n')) as db_size;
"

# Verificar uso de memória do Redis
echo -e "\n${YELLOW}Verificando uso de memória do Redis...${NC}"
docker-compose exec -T redis redis-cli info memory | grep "used_memory_human"

# Verificar integridade dos volumes
echo -e "\n${YELLOW}Verificando integridade dos volumes...${NC}"
docker volume ls
docker volume inspect n8n_data pgdata waha_sessions waha_media prometheus_data grafana_data

# Verificar certificados SSL
echo -e "\n${YELLOW}Verificando certificados SSL...${NC}"
if [ -f "./docker/nginx/ssl/fullchain.pem" ]; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in ./docker/nginx/ssl/fullchain.pem)
    echo -e "Certificado SSL expira em: $CERT_EXPIRY"
else
    echo -e "${RED}Certificado SSL não encontrado!${NC}"
fi

# Verificar atualizações disponíveis
echo -e "\n${YELLOW}Verificando atualizações disponíveis...${NC}"
docker-compose pull

echo -e "\n${GREEN}Manutenção concluída!${NC}"

# Gerar relatório
REPORT_FILE="maintenance_report_$(date +%Y%m%d).txt"
{
    echo "Relatório de Manutenção - $(date)"
    echo "================================"
    echo
    echo "Espaço em Disco:"
    df -h
    echo
    echo "Status dos Containers:"
    docker-compose ps
    echo
    echo "Tamanho do Banco de Dados:"
    docker-compose exec -T postgres psql -U n8n -d n8n -c "\l+ n8n"
    echo
    echo "Uso de Memória Redis:"
    docker-compose exec -T redis redis-cli info memory
} > "./logs/$REPORT_FILE"

echo -e "\n${GREEN}Relatório gerado em: ./logs/$REPORT_FILE${NC}" 
#!/bin/bash

# Configurações
BACKUP_DIR="/backups"
RETENTION_DAYS=7
REMOTE_BACKUP_DIR="s3://seu-bucket/n8n-backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/backup.log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função de logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Função de erro
error() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Verificar espaço em disco
check_disk_space() {
    FREE_SPACE=$(df -m "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    if [ "$FREE_SPACE" -lt 1000 ]; then
        error "Espaço em disco insuficiente (menos de 1GB disponível)"
    fi
}

# Criar diretório de backup
mkdir -p "$BACKUP_DIR" || error "Não foi possível criar diretório de backup"

# Verificar espaço em disco
check_disk_space

# Iniciar backup
log "${YELLOW}Iniciando backup...${NC}"

# Parar serviços não essenciais
log "Parando serviços não essenciais..."
docker-compose stop grafana prometheus || log "${YELLOW}Aviso: Falha ao parar alguns serviços${NC}"

# Backup do PostgreSQL
log "Realizando backup do PostgreSQL..."
POSTGRES_BACKUP="$BACKUP_DIR/postgres_$DATE.sql"
docker-compose exec -T postgres pg_dump -U n8n n8n > "$POSTGRES_BACKUP" || error "Falha no backup do PostgreSQL"

# Backup do Redis
log "Realizando backup do Redis..."
REDIS_BACKUP="$BACKUP_DIR/redis_$DATE.rdb"
docker-compose exec -T redis redis-cli SAVE
docker cp $(docker-compose ps -q redis):/data/dump.rdb "$REDIS_BACKUP" || error "Falha no backup do Redis"

# Backup dos volumes
log "Realizando backup dos volumes..."
VOLUMES_BACKUP="$BACKUP_DIR/volumes_$DATE.tar.gz"
docker run --rm \
    -v n8n_data:/source/n8n_data:ro \
    -v waha_sessions:/source/waha_sessions:ro \
    -v waha_media:/source/waha_media:ro \
    -v "$BACKUP_DIR:/backup" \
    alpine tar czf "/backup/$(basename $VOLUMES_BACKUP)" -C /source . || error "Falha no backup dos volumes"

# Backup das configurações
log "Realizando backup das configurações..."
CONFIG_BACKUP="$BACKUP_DIR/config_$DATE.tar.gz"
tar czf "$CONFIG_BACKUP" \
    docker-compose.yml \
    .env \
    docker/ \
    scripts/ || error "Falha no backup das configurações"

# Criar arquivo único
log "Criando arquivo único de backup..."
FINAL_BACKUP="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"
tar czf "$FINAL_BACKUP" \
    "$POSTGRES_BACKUP" \
    "$REDIS_BACKUP" \
    "$VOLUMES_BACKUP" \
    "$CONFIG_BACKUP" || error "Falha ao criar arquivo único de backup"

# Remover arquivos temporários
rm "$POSTGRES_BACKUP" "$REDIS_BACKUP" "$VOLUMES_BACKUP" "$CONFIG_BACKUP"

# Reiniciar serviços
log "Reiniciando serviços..."
docker-compose start grafana prometheus || log "${YELLOW}Aviso: Falha ao reiniciar alguns serviços${NC}"

# Backup remoto (S3)
if command -v aws &> /dev/null; then
    log "Enviando backup para S3..."
    aws s3 cp "$FINAL_BACKUP" "$REMOTE_BACKUP_DIR/" || log "${YELLOW}Aviso: Falha ao enviar backup para S3${NC}"
fi

# Limpar backups antigos
log "Limpando backups antigos..."
find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete

# Verificar integridade do backup
log "Verificando integridade do backup..."
if tar tzf "$FINAL_BACKUP" > /dev/null 2>&1; then
    log "${GREEN}Backup concluído com sucesso: $FINAL_BACKUP${NC}"
else
    error "Backup corrompido: $FINAL_BACKUP"
fi

# Gerar relatório
REPORT_FILE="$BACKUP_DIR/backup_report_$DATE.txt"
{
    echo "Relatório de Backup - $(date)"
    echo "================================"
    echo
    echo "Arquivo de backup: $FINAL_BACKUP"
    echo "Tamanho: $(du -h "$FINAL_BACKUP" | cut -f1)"
    echo "MD5: $(md5sum "$FINAL_BACKUP" | cut -d' ' -f1)"
    echo
    echo "Detalhes do backup:"
    tar tvf "$FINAL_BACKUP"
    echo
    echo "Espaço em disco após backup:"
    df -h "$BACKUP_DIR"
} > "$REPORT_FILE"

log "Relatório gerado em: $REPORT_FILE"

# Enviar notificação (exemplo com Slack)
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"Backup concluído com sucesso\nArquivo: $FINAL_BACKUP\nTamanho: $(du -h "$FINAL_BACKUP" | cut -f1)\"}" \
        "$SLACK_WEBHOOK_URL"
fi 
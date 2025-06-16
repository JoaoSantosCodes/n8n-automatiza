#!/bin/bash

# Diretório onde os backups serão armazenados
BACKUP_DIR="/backups/n8n"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
RETENTION_DAYS=7

# Criar diretório de backup se não existir
mkdir -p $BACKUP_DIR

# Backup dos volumes Docker
echo "Iniciando backup dos volumes Docker..."
docker run --rm \
  -v n8n_data:/source/n8n_data \
  -v pgdata:/source/pgdata \
  -v waha_sessions:/source/waha_sessions \
  -v waha_media:/source/waha_media \
  -v $BACKUP_DIR:/backup \
  ubuntu tar czf /backup/n8n_backup_$DATE.tar.gz /source

# Limpar backups antigos
echo "Removendo backups mais antigos que $RETENTION_DAYS dias..."
find $BACKUP_DIR -type f -name "n8n_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup concluído: $BACKUP_DIR/n8n_backup_$DATE.tar.gz" 
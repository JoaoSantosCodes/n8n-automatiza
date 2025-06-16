#!/bin/bash

# Verificar se o arquivo de backup foi fornecido
if [ -z "$1" ]; then
    echo "Por favor, forneça o arquivo de backup para restaurar."
    echo "Uso: $0 /caminho/para/n8n_backup_YYYY-MM-DD_HH-MM-SS.tar.gz"
    exit 1
fi

BACKUP_FILE=$1

# Verificar se o arquivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Arquivo de backup não encontrado: $BACKUP_FILE"
    exit 1
fi

# Parar os containers
echo "Parando containers..."
docker-compose down

# Criar diretório temporário para restauração
TEMP_DIR=$(mktemp -d)

# Extrair backup
echo "Extraindo backup..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Restaurar volumes
echo "Restaurando volumes..."
docker run --rm \
  -v n8n_data:/target/n8n_data \
  -v pgdata:/target/pgdata \
  -v waha_sessions:/target/waha_sessions \
  -v waha_media:/target/waha_media \
  -v $TEMP_DIR:/source \
  ubuntu cp -r /source/source/. /target/

# Limpar diretório temporário
rm -rf "$TEMP_DIR"

# Reiniciar containers
echo "Reiniciando containers..."
docker-compose up -d

echo "Restauração concluída!" 
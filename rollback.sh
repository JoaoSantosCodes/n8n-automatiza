#!/bin/bash

# Diretório de backup
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
COMPOSE_FILE="docker-compose.yml"
VOLUMES_DIR="/var/lib/docker/volumes"

# Função para fazer backup
backup() {
    echo "📦 Iniciando backup..."
    
    # Criar diretório de backup
    mkdir -p "$BACKUP_DIR"
    
    # Backup do docker-compose.yml
    echo "🗄️ Fazendo backup do docker-compose.yml..."
    cp "$COMPOSE_FILE" "$BACKUP_DIR/docker-compose.yml.bak"
    
    # Backup dos volumes
    echo "💾 Fazendo backup dos volumes..."
    docker-compose down
    
    # Lista de volumes para backup
    volumes=(
        "n8n_data"
        "postgres_data"
        "redis_data"
        "prometheus_data"
        "grafana_data"
        "waha_sessions"
        "waha_media"
    )
    
    for volume in "${volumes[@]}"; do
        if [ -d "$VOLUMES_DIR/$volume" ]; then
            echo "📀 Backup do volume $volume..."
            tar -czf "$BACKUP_DIR/${volume}.tar.gz" -C "$VOLUMES_DIR" "$volume"
        fi
    done
    
    echo "✅ Backup completo! Arquivos salvos em $BACKUP_DIR"
}

# Função para rollback
rollback() {
    if [ -z "$1" ]; then
        echo "❌ Por favor, especifique o diretório de backup para rollback"
        echo "Uso: $0 rollback ./backups/[timestamp]"
        exit 1
    fi
    
    RESTORE_DIR="$1"
    
    if [ ! -d "$RESTORE_DIR" ]; then
        echo "❌ Diretório de backup não encontrado: $RESTORE_DIR"
        exit 1
    }
    
    echo "🔄 Iniciando rollback..."
    
    # Parar containers
    docker-compose down
    
    # Restaurar docker-compose.yml
    if [ -f "$RESTORE_DIR/docker-compose.yml.bak" ]; then
        echo "📄 Restaurando docker-compose.yml..."
        cp "$RESTORE_DIR/docker-compose.yml.bak" "$COMPOSE_FILE"
    fi
    
    # Restaurar volumes
    echo "💽 Restaurando volumes..."
    for backup_file in "$RESTORE_DIR"/*.tar.gz; do
        if [ -f "$backup_file" ]; then
            volume_name=$(basename "$backup_file" .tar.gz)
            echo "📥 Restaurando volume $volume_name..."
            docker volume rm "$volume_name" || true
            docker volume create "$volume_name"
            tar -xzf "$backup_file" -C "$VOLUMES_DIR"
        fi
    done
    
    echo "🚀 Iniciando containers com configuração antiga..."
    docker-compose up -d
    
    echo "✅ Rollback completo!"
}

# Função para listar backups disponíveis
list_backups() {
    echo "📋 Backups disponíveis:"
    ls -l ./backups/
}

# Menu principal
case "$1" in
    "backup")
        backup
        ;;
    "rollback")
        rollback "$2"
        ;;
    "list")
        list_backups
        ;;
    *)
        echo "Uso: $0 [backup|rollback|list]"
        echo "  backup  - Criar novo backup"
        echo "  rollback [dir] - Restaurar de um backup"
        echo "  list    - Listar backups disponíveis"
        exit 1
        ;;
esac 
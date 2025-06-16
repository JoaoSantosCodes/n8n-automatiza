# Diretório de backup
$BACKUP_DIR = ".\backups\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$COMPOSE_FILE = "docker-compose.yml"
$VOLUMES_DIR = "C:\ProgramData\Docker\volumes"

# Função para fazer backup
function Backup-Environment {
    Write-Host "Iniciando backup..." -ForegroundColor Cyan
    
    # Criar diretório de backup
    New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
    
    # Backup do docker-compose.yml
    Write-Host "Fazendo backup do docker-compose.yml..." -ForegroundColor Green
    Copy-Item $COMPOSE_FILE -Destination "$BACKUP_DIR\docker-compose.yml.bak"
    
    # Backup dos volumes
    Write-Host "Fazendo backup dos volumes..." -ForegroundColor Green
    docker-compose down
    
    # Lista de volumes para backup
    $volumes = @(
        "n8n_data",
        "postgres_data",
        "redis_data",
        "prometheus_data",
        "grafana_data",
        "waha_sessions",
        "waha_media"
    )
    
    foreach ($volume in $volumes) {
        $volumePath = Join-Path $VOLUMES_DIR $volume
        if (Test-Path $volumePath) {
            Write-Host "Backup do volume $volume..." -ForegroundColor Yellow
            Compress-Archive -Path $volumePath -DestinationPath "$BACKUP_DIR\$volume.zip" -Force
        }
    }
    
    Write-Host "Backup completo! Arquivos salvos em $BACKUP_DIR" -ForegroundColor Green
}

# Função para rollback
function Restore-Environment {
    param (
        [Parameter(Mandatory=$true)]
        [string]$RestoreDir
    )
    
    if (-not (Test-Path $RestoreDir)) {
        Write-Host "Diretório de backup não encontrado: $RestoreDir" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Iniciando rollback..." -ForegroundColor Cyan
    
    # Parar containers
    docker-compose down
    
    # Restaurar docker-compose.yml
    if (Test-Path "$RestoreDir\docker-compose.yml.bak") {
        Write-Host "Restaurando docker-compose.yml..." -ForegroundColor Green
        Copy-Item "$RestoreDir\docker-compose.yml.bak" -Destination $COMPOSE_FILE -Force
    }
    
    # Restaurar volumes
    Write-Host "Restaurando volumes..." -ForegroundColor Green
    Get-ChildItem "$RestoreDir\*.zip" | ForEach-Object {
        $volumeName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        Write-Host "Restaurando volume $volumeName..." -ForegroundColor Yellow
        
        docker volume rm $volumeName -f
        docker volume create $volumeName
        
        # Extrair arquivo zip para o diretório do volume
        Expand-Archive -Path $_.FullName -DestinationPath $VOLUMES_DIR -Force
    }
    
    Write-Host "Iniciando containers com configuração antiga..." -ForegroundColor Green
    docker-compose up -d
    
    Write-Host "Rollback completo!" -ForegroundColor Green
}

# Função para listar backups disponíveis
function List-Backups {
    Write-Host "Backups disponíveis:" -ForegroundColor Cyan
    if (Test-Path ".\backups") {
        Get-ChildItem ".\backups" | Format-Table Name, LastWriteTime
    } else {
        Write-Host "Nenhum backup encontrado." -ForegroundColor Yellow
    }
}

# Menu principal
switch ($args[0]) {
    "backup" {
        Backup-Environment
    }
    "rollback" {
        if ($args.Count -lt 2) {
            Write-Host "Por favor, especifique o diretório de backup para rollback" -ForegroundColor Red
            Write-Host "Uso: .\rollback.ps1 rollback .\backups\[timestamp]"
            exit 1
        }
        Restore-Environment -RestoreDir $args[1]
    }
    "list" {
        List-Backups
    }
    default {
        Write-Host "Uso: .\rollback.ps1 [backup|rollback|list]" -ForegroundColor Yellow
        Write-Host "  backup  - Criar novo backup"
        Write-Host "  rollback [dir] - Restaurar de um backup"
        Write-Host "  list    - Listar backups disponíveis"
        exit 1
    }
} 
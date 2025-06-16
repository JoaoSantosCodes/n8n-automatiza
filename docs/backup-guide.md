# Guia de Backup e Restore

Este guia detalha os procedimentos de backup e restore do ambiente n8n enterprise.

## 📋 Visão Geral

O sistema de backup é projetado para:
- Backup automático para AWS S3
- Backup incremental
- Restore point-in-time
- Validação automática
- Retenção configurável

## 🗃️ Componentes Backup

### 1. Dados do n8n
- Workflows
- Credenciais
- Variáveis
- Execuções
- Webhooks

### 2. Banco de Dados
- PostgreSQL
- Redis
- Configurações

### 3. Configurações
- Keycloak
- Vault
- Certificados
- Network policies

### 4. Customizações
- Dashboards
- Alertas
- Scripts
- Templates

## 📦 Tipos de Backup

### Full Backup
```bash
# Backup completo
./scripts/backup.sh --full

# Backup completo com timestamp específico
./scripts/backup.sh --full --timestamp "2024-01-01-120000"

# Backup completo com compressão máxima
./scripts/backup.sh --full --compress max
```

### Incremental Backup
```bash
# Backup incremental
./scripts/backup.sh --incremental

# Backup incremental desde timestamp
./scripts/backup.sh --incremental --since "2024-01-01-120000"
```

### Backup Seletivo
```bash
# Backup de componente específico
./scripts/backup.sh --component workflow

# Backup de múltiplos componentes
./scripts/backup.sh --component "workflow,credentials,variables"
```

## 🔄 Processo de Backup

### 1. Pré-backup
```bash
# Verificar espaço
./scripts/backup.sh --check-space

# Validar dependências
./scripts/backup.sh --check-deps

# Teste de conectividade
./scripts/backup.sh --test-connection
```

### 2. Durante Backup
- Consistência dos dados
- Compressão
- Criptografia
- Upload para S3

### 3. Pós-backup
- Validação
- Limpeza
- Notificação
- Logs

## 🔐 Segurança

### Criptografia
```yaml
encryption:
  algorithm: AES-256-GCM
  key_management: aws-kms
  key_rotation: 90d
```

### Acesso
```yaml
permissions:
  - action: s3:PutObject
    resource: arn:aws:s3:::n8n-backups/*
  - action: s3:GetObject
    resource: arn:aws:s3:::n8n-backups/*
  - action: kms:Decrypt
    resource: arn:aws:kms:region:account:key/*
```

## 📅 Agendamento

### Configuração
```yaml
schedule:
  full:
    frequency: daily
    time: "00:00"
    retention: 7d
  
  incremental:
    frequency: hourly
    retention: 24h
  
  validation:
    frequency: daily
    time: "06:00"
```

## 🔄 Restore

### Restore Completo
```bash
# Restore do último backup
./scripts/restore.sh --latest

# Restore de backup específico
./scripts/restore.sh --backup "backup-2024-01-01-120000.tar.gz"

# Restore para ambiente de teste
./scripts/restore.sh --backup "backup.tar.gz" --target test
```

### Restore Seletivo
```bash
# Restore de workflows
./scripts/restore.sh --component workflow --backup "backup.tar.gz"

# Restore de credenciais
./scripts/restore.sh --component credentials --backup "backup.tar.gz"
```

### Restore Point-in-Time
```bash
# Restore para timestamp específico
./scripts/restore.sh --timestamp "2024-01-01-120000"

# Restore do último ponto consistente
./scripts/restore.sh --last-consistent
```

## 📊 Monitoramento

### Métricas
- Tempo de backup
- Tamanho do backup
- Taxa de sucesso
- Tempo de restore
- Uso de recursos

### Alertas
```yaml
alerts:
  backup_failed:
    condition: status != "success"
    severity: critical
    notification: ["email", "slack"]

  backup_size:
    condition: size > threshold
    severity: warning
    notification: ["slack"]

  restore_failed:
    condition: status != "success"
    severity: critical
    notification: ["email", "slack", "pagerduty"]
```

## 🔍 Validação

### Verificações
1. Integridade
   ```bash
   ./scripts/backup.sh --verify integrity
   ```

2. Consistência
   ```bash
   ./scripts/backup.sh --verify consistency
   ```

3. Restore Test
   ```bash
   ./scripts/backup.sh --verify restore
   ```

### Logs
```yaml
logging:
  path: /var/log/n8n/backup
  level: info
  retention: 90d
  format:
    timestamp: ISO8601
    fields:
      - operation
      - status
      - size
      - duration
```

## 🚨 Troubleshooting

### Problemas Comuns

1. Falha no Backup
```bash
# Verificar status
./scripts/backup.sh --status

# Verificar logs
./scripts/backup.sh --logs

# Retry backup
./scripts/backup.sh --retry
```

2. Falha no Restore
```bash
# Verificar backup
./scripts/restore.sh --verify backup.tar.gz

# Restore com debug
./scripts/restore.sh --debug

# Cleanup após falha
./scripts/restore.sh --cleanup
```

### Recovery
1. Backup Corrompido
```bash
# Verificar backup anterior
./scripts/backup.sh --verify-previous

# Restore do último válido
./scripts/restore.sh --last-valid
```

2. Restore Parcial
```bash
# Continuar restore
./scripts/restore.sh --continue

# Rollback restore
./scripts/restore.sh --rollback
```

## 📚 Boas Práticas

### 1. Backup
- Teste regularmente
- Monitore tamanho
- Valide integridade
- Mantenha documentação

### 2. Restore
- Teste mensalmente
- Documente procedimentos
- Mantenha runbook
- Treine equipe

### 3. Segurança
- Criptografe backups
- Controle acesso
- Monitore atividades
- Audite restaurações

## 📖 Documentação Adicional

### Guias
- [Arquitetura de Backup](docs/backup/architecture.md)
- [Procedimentos de Restore](docs/backup/restore-procedures.md)
- [Troubleshooting Guide](docs/backup/troubleshooting.md)

### Exemplos
- [Backup Customizado](examples/custom-backup.md)
- [Restore Seletivo](examples/selective-restore.md)
- [Validação de Backup](examples/backup-validation.md)

### Referências
- [AWS S3 Backup Best Practices](docs/backup/aws-best-practices.md)
- [Disaster Recovery Plan](docs/backup/dr-plan.md)
- [Compliance Requirements](docs/backup/compliance.md) 
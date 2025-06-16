# Guia do Sistema de Rollback

Este guia detalha o sistema de rollback do ambiente n8n enterprise, que permite reverter alterações em caso de problemas.

## 📋 Visão Geral

O sistema de rollback é projetado para:
- Reverter componentes específicos
- Restaurar backups completos
- Validar integridade após rollback
- Manter logs detalhados

## 🛠️ Componentes Suportados

- n8n Core
- GPT Service
- AI Analytics
- Vault
- OpenTelemetry
- Federation Controller
- SonarQube
- ArgoCD

## 📜 Scripts Disponíveis

### 1. Component Rollback
```bash
./scripts/rollback/rollback.sh component [versão]
```

Opções:
- `component`: Nome do componente
- `versão`: Versão específica (opcional)

Exemplo:
```bash
# Rollback do GPT Service para v1.0.0
./scripts/rollback/rollback.sh gpt-service v1.0.0

# Rollback do último deploy estável
./scripts/rollback/rollback.sh gpt-service
```

### 2. Backup
```bash
./scripts/backup.sh [--full|--incremental]
```

Opções:
- `--full`: Backup completo
- `--incremental`: Backup incremental

Exemplo:
```bash
# Backup completo
./scripts/backup.sh --full

# Backup incremental
./scripts/backup.sh --incremental
```

### 3. Restore
```bash
./scripts/restore.sh <arquivo_backup>
```

Exemplo:
```bash
./scripts/restore.sh backups/full_20240101_120000.tar.gz
```

## 🔄 Processo de Rollback

### Antes da Atualização

1. Backup Automático
   ```bash
   ./scripts/backup.sh --full
   ```

2. Validação de Dependências
   ```bash
   ./scripts/rollback/validate.sh
   ```

3. Snapshot do Estado
   ```bash
   ./scripts/rollback/snapshot.sh
   ```

### Durante o Rollback

1. Parada Segura
   ```bash
   ./scripts/rollback/stop.sh <component>
   ```

2. Reversão
   ```bash
   ./scripts/rollback/revert.sh <component> <version>
   ```

3. Validação
   ```bash
   ./scripts/rollback/validate.sh <component>
   ```

### Pós-Rollback

1. Verificação de Integridade
   ```bash
   ./scripts/rollback/health-check.sh
   ```

2. Teste de Funcionalidades
   ```bash
   ./scripts/rollback/test.sh
   ```

3. Notificação
   ```bash
   ./scripts/rollback/notify.sh
   ```

## 📊 Monitoramento

### Métricas Coletadas
- Tempo de rollback
- Taxa de sucesso
- Integridade dos dados
- Performance pós-rollback

### Alertas
- Falha no rollback
- Timeout excedido
- Erro de validação
- Inconsistência de dados

## 🔍 Validações

### 1. Pré-Rollback
- Dependências
- Recursos disponíveis
- Backups recentes
- Estado dos serviços

### 2. Durante Rollback
- Progresso da operação
- Integridade dos dados
- Conectividade
- Recursos do sistema

### 3. Pós-Rollback
- Funcionalidades críticas
- Performance
- Integridade dos dados
- Conectividade entre serviços

## 📝 Logs

### Estrutura
```
/var/log/n8n/rollback/
├── component/
│   ├── gpt-service/
│   ├── ai-analytics/
│   └── federation/
├── system/
└── audit/
```

### Níveis de Log
- INFO: Operações normais
- WARN: Avisos
- ERROR: Erros
- FATAL: Erros críticos

### Retenção
- Logs operacionais: 30 dias
- Logs de auditoria: 1 ano
- Logs de erro: 90 dias

## 🚨 Troubleshooting

### Problemas Comuns

1. Falha no Rollback
   ```bash
   ./scripts/rollback/diagnose.sh <component>
   ```

2. Timeout
   ```bash
   ./scripts/rollback/extend-timeout.sh <component>
   ```

3. Conflito de Versão
   ```bash
   ./scripts/rollback/version-check.sh <component>
   ```

### Recuperação de Erros

1. Rollback do Rollback
   ```bash
   ./scripts/rollback/emergency-stop.sh
   ```

2. Restauração de Emergência
   ```bash
   ./scripts/rollback/emergency-restore.sh
   ```

## 🔐 Segurança

### Controle de Acesso
- RBAC para operações de rollback
- Auditoria de comandos
- Validação de tokens
- Logs seguros

### Boas Práticas
1. Sempre faça backup antes de:
   - Atualizações
   - Configurações
   - Migrações

2. Documente:
   - Motivo do rollback
   - Mudanças realizadas
   - Resultados obtidos

3. Teste regularmente:
   - Procedimentos de rollback
   - Restauração de backup
   - Validações

## 📚 Recursos Adicionais

### Documentação
- [Arquitetura de Rollback](docs/architecture/rollback.md)
- [API de Rollback](docs/api/rollback.md)
- [Políticas de Backup](docs/policies/backup.md)

### Exemplos
- [Rollback Simples](examples/simple-rollback.md)
- [Rollback Multi-componente](examples/multi-component-rollback.md)
- [Recuperação de Desastre](examples/disaster-recovery.md)

### Referências
- [Changelog](CHANGELOG.md)
- [Matriz de Compatibilidade](docs/compatibility.md)
- [Guia de Contribuição](CONTRIBUTING.md) 
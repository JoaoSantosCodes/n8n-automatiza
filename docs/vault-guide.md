# Guia do Vault

Este guia detalha a implementação do HashiCorp Vault no ambiente n8n enterprise.

## Visão Geral

O Vault é usado para:
- Gerenciamento seguro de segredos
- Criptografia de dados sensíveis
- Rotação automática de credenciais
- Auditoria de acesso

## Arquitetura

### Alta Disponibilidade
- 3 nodes em cluster
- Raft para consenso
- Auto-healing
- Load balancing

### Segurança
- TLS para comunicação
- AWS KMS para auto-unseal
- Políticas granulares
- Audit logging

## Configuração

### Pré-requisitos
- AWS KMS configurado
- Certificados TLS
- Kubernetes cluster
- Storage persistente

### Instalação

1. Configure os secrets AWS:
```bash
kubectl create secret generic vault-aws-secrets \
  --from-literal=kms_key_id=sua_key_id \
  --from-literal=aws_access_key=sua_access_key \
  --from-literal=aws_secret_key=sua_secret_key \
  -n n8n
```

2. Aplique o deployment:
```bash
kubectl apply -k kubernetes/base/vault/
```

### Inicialização

1. Inicialize o Vault:
```bash
kubectl exec -it vault-0 -n n8n -- vault operator init
```

2. Configure o auto-unseal:
```bash
kubectl exec -it vault-0 -n n8n -- vault operator unseal
```

## Uso

### Secrets Engine

1. **Key/Value**
```bash
vault secrets enable -path=n8n kv-v2
vault kv put n8n/credentials/database \
  username=admin \
  password=secret
```

2. **Database**
```bash
vault secrets enable database
vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/n8n"
```

### Políticas

1. **N8N Policy**
```hcl
path "n8n/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

2. **Audit Policy**
```hcl
path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

## Monitoramento

### Métricas
- `vault.token.count`: Tokens ativos
- `vault.secret.count`: Segredos armazenados
- `vault.audit.requests`: Requisições auditadas
- `vault.ha.status`: Status do cluster

### Logs
- Audit logs
- Operation logs
- Debug logs

## Backup e Restore

### Backup
```bash
# Backup completo
./scripts/rollback/backup-data.sh

# Backup do Vault
./scripts/rollback/component-rollback.sh vault backup
```

### Restore
```bash
# Restore completo
./scripts/rollback/restore-backup.sh backups/full_backup_20240101_120000.tar.gz

# Restore do Vault
./scripts/rollback/component-rollback.sh vault restore
```

## Troubleshooting

### Problemas Comuns

1. **Sealed Status**
   - Verifique AWS KMS
   - Verifique conectividade
   - Logs do unseal

2. **HA Sync**
   - Verifique raft status
   - Verifique network
   - Logs do cluster

3. **Performance**
   - Monitore latência
   - Verifique recursos
   - Ajuste cache

## Segurança

### Boas Práticas
- Rotação regular de root tokens
- Audit logging habilitado
- TLS em todas comunicações
- Políticas least-privilege

### Compliance
- GDPR
- SOC 2
- ISO 27001
- PCI DSS

## Manutenção

### Regular
- Rotação de certificados
- Verificação de backups
- Teste de restore
- Atualização de políticas

### Emergência
- Procedimento de DR
- Rollback plan
- Contatos de suporte

## Referências

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Best Practices](https://www.vaultproject.io/docs/concepts/best-practices)
- [API Reference](https://www.vaultproject.io/api-docs) 
# Guia de Segurança

Este guia detalha as práticas de segurança implementadas no ambiente n8n enterprise.

## 🔐 Autenticação e Autorização

### Keycloak Integration
- Single Sign-On (SSO)
- Multi-Factor Authentication (MFA)
- OAuth2/OpenID Connect
- SAML Support
- LDAP Integration

### RBAC (Role-Based Access Control)
```yaml
roles:
  admin:
    - full_access
    - manage_users
    - manage_workflows
    - view_audit_logs
  
  workflow_manager:
    - create_workflows
    - edit_workflows
    - execute_workflows
    - view_logs
  
  operator:
    - execute_workflows
    - view_workflows
    - view_own_logs
  
  auditor:
    - view_workflows
    - view_audit_logs
    - generate_reports
```

## 🔒 HashiCorp Vault

### Secrets Management
- API Keys
- Credenciais
- Certificados
- Tokens
- Senhas

### Configuração
```hcl
storage "raft" {
  path = "/vault/data"
  node_id = "node-a"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 0
  tls_cert_file = "/vault/certs/tls.crt"
  tls_key_file = "/vault/certs/tls.key"
}

seal "awskms" {
  region = "us-east-1"
  kms_key_id = "alias/vault-key"
}
```

### Políticas
```hcl
path "secret/data/n8n/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/token/create" {
  capabilities = ["create", "update"]
}
```

## 🛡️ Network Security

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: n8n-network-policy
spec:
  podSelector:
    matchLabels:
      app: n8n
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 5678
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

### TLS/SSL
- Certificados automáticos com cert-manager
- Renovação automática
- Grade A+ no SSL Labs
- Perfect Forward Secrecy

## 🔍 Auditoria

### Logs de Auditoria
```yaml
audit:
  path: /var/log/n8n/audit
  retention: 365
  fields:
    - timestamp
    - user
    - action
    - resource
    - status
    - ip_address
    - user_agent
```

### Eventos Monitorados
1. Autenticação
   - Login/Logout
   - Falhas de autenticação
   - Alterações de senha
   - MFA events

2. Workflows
   - Criação
   - Modificação
   - Execução
   - Deleção

3. Configuração
   - Mudanças de settings
   - Updates de sistema
   - Alterações de RBAC
   - Gestão de secrets

## 🚨 Detecção de Ameaças

### Monitoramento
- Falhas de autenticação
- Padrões suspeitos
- Anomalias de uso
- Scanning activities

### Alertas
```yaml
alerts:
  bruteforce:
    threshold: 5
    window: 5m
    action: block_ip

  suspicious_access:
    conditions:
      - unusual_time
      - unusual_location
      - sensitive_resource
    action: notify_admin

  data_exfiltration:
    threshold: 1000
    window: 1h
    action: block_user
```

## 🔐 Criptografia

### Em Repouso
- Banco de dados
- Arquivos
- Backups
- Secrets

### Em Trânsito
- TLS 1.3
- Strong ciphers
- Certificate pinning
- Perfect forward secrecy

## 🛠️ Hardening

### Sistema Operacional
- Updates automáticos
- Minimal base image
- Seccomp profiles
- AppArmor/SELinux

### Kubernetes
```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

### Container
```dockerfile
FROM node:alpine

# Security updates
RUN apk update && apk upgrade

# Non-root user
USER node

# Minimal permissions
COPY --chown=node:node . .
```

## 📝 Compliance

### Standards
- GDPR
- LGPD
- SOC2
- ISO27001
- PCI DSS

### Processos
1. Risk Assessment
   - Regular scans
   - Penetration tests
   - Vulnerability assessment
   - Code review

2. Incident Response
   - Detection
   - Containment
   - Eradication
   - Recovery

3. Change Management
   - Approval process
   - Testing
   - Rollback plan
   - Documentation

## 🔄 Backup e Recovery

### Backup Seguro
```yaml
backup:
  encryption:
    algorithm: AES-256-GCM
    key_rotation: 90d
  
  storage:
    type: s3
    bucket: n8n-backups
    encryption: aws:kms
    
  retention:
    daily: 7
    weekly: 4
    monthly: 12
```

### Disaster Recovery
1. RPO (Recovery Point Objective): 1h
2. RTO (Recovery Time Objective): 4h
3. Teste mensal de recovery
4. Documentação detalhada

## 📚 Boas Práticas

### Desenvolvimento Seguro
1. Code Review
   - Security checks
   - Dependency scan
   - SAST/DAST
   - Container scan

2. CI/CD Security
   - Secrets scanning
   - Image scanning
   - Policy enforcement
   - Compliance checks

### Operação Segura
1. Access Management
   - Least privilege
   - Regular review
   - Access logging
   - Session management

2. Monitoring
   - Security events
   - System metrics
   - User activity
   - Resource usage

## 🎓 Treinamento

### Tópicos
1. Security Awareness
   - Phishing
   - Social engineering
   - Password security
   - Data handling

2. Technical Training
   - Secure coding
   - Cloud security
   - Container security
   - Network security

## 📚 Recursos Adicionais

### Documentação
- [Security Architecture](docs/security/architecture.md)
- [Compliance Guide](docs/security/compliance.md)
- [Incident Response](docs/security/incident-response.md)

### Ferramentas
- [Security Checklist](tools/security-checklist.md)
- [Audit Scripts](tools/audit-scripts.md)
- [Hardening Guide](tools/hardening-guide.md)

### Referências
- [OWASP Top 10](https://owasp.org/Top10)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework) 
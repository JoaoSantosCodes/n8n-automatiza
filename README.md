# n8n Enterprise Environment

Este é um ambiente enterprise completo para o n8n, incluindo autenticação OAuth2, monitoramento avançado, backup automatizado, alta disponibilidade e integração com serviços de IA.

## 🌟 Funcionalidades

### 🔐 Segurança e Autenticação
- **Keycloak Integration**
  - Single Sign-On (SSO)
  - Suporte a múltiplos provedores de identidade
  - Políticas de senha personalizáveis
  - MFA (Multi-Factor Authentication)

- **HashiCorp Vault**
  - Gerenciamento seguro de secrets
  - Rotação automática de credenciais
  - Criptografia de dados em repouso
  - Integração com AWS KMS

### 📊 Monitoramento e Observabilidade
- **Stack de Monitoramento**
  - Prometheus para métricas
  - Grafana para visualização
  - OpenTelemetry para traces
  - Jaeger para distributed tracing

- **Métricas Customizadas**
  - Métricas de negócio
  - Performance de workflows
  - Uso de recursos
  - Latência de integrações

### 🤖 Integrações com IA
- **GPT Service**
  - Processamento de linguagem natural
  - Geração de conteúdo
  - Análise de sentimento
  - Classificação de texto

- **AI Analytics**
  - Análise preditiva
  - Machine Learning automatizado
  - Detecção de anomalias
  - Insights de dados

### 🔄 DevOps e CI/CD
- **ArgoCD**
  - GitOps workflow
  - Deployments automatizados
  - Rollbacks automáticos
  - Multi-cluster management

- **SonarQube**
  - Análise de código
  - Code coverage
  - Vulnerabilidades
  - Code smells

### 💾 Backup e Recuperação
- **Sistema de Backup**
  - Backup automático para S3
  - Retenção configurável
  - Backup incremental
  - Restore point-in-time

- **Sistema de Rollback**
  - Rollback por componente
  - Rollback completo
  - Verificação automática
  - Logs detalhados

## 🛠️ Scripts de Gerenciamento

### Setup e Instalação
- `setup.sh`: Configuração inicial do ambiente
- `install.sh`: Instalação de todos os componentes
- `certs.sh`: Gerenciamento de certificados SSL

### Manutenção
- `update.sh`: Atualização de componentes
- `cleanup.sh`: Limpeza do ambiente
- `monitor.sh`: Monitoramento em tempo real

### Backup e Recuperação
- `backup.sh`: Backup manual ou agendado
- `restore.sh`: Restauração de backups
- `rollback.sh`: Sistema de rollback

## 📦 Pré-requisitos

- Kubernetes 1.21+
- Helm 3.0+
- AWS CLI 2.0+
- Terraform 1.0+
- ArgoCD CLI
- kubectl

## 🚀 Instalação

1. Clone o repositório:
   \`\`\`bash
   git clone https://github.com/seu-usuario/n8n-enterprise
   cd n8n-enterprise
   \`\`\`

2. Configure as variáveis:
   \`\`\`bash
   cp .env.example .env
   # Edite o arquivo .env com suas configurações
   \`\`\`

3. Execute o setup:
   \`\`\`bash
   ./scripts/setup.sh
   \`\`\`

4. Instale os componentes:
   \`\`\`bash
   ./scripts/install.sh
   \`\`\`

## 🔧 Configuração

### Infraestrutura
1. Configure o Terraform:
   \`\`\`bash
   cd terraform
   terraform init
   terraform apply
   \`\`\`

2. Configure o cluster:
   \`\`\`bash
   aws eks update-kubeconfig --name n8n-production
   \`\`\`

### Componentes
1. **Keycloak**
   - Configure realm
   - Adicione providers
   - Configure clients

2. **Vault**
   - Initialize
   - Unseal
   - Configure auth methods

3. **Monitoring**
   - Configure datasources
   - Import dashboards
   - Setup alerting

## 📊 Monitoramento

### Componentes Monitorados
- n8n core
- Workflows
- Integrações
- Banco de dados
- Cache
- Serviços de IA
- Federation Controller

### Alertas
- Uso de recursos
- Performance
- Erros
- Segurança
- Certificados
- Backups

## 🔄 Atualização e Rollback

### Processo de Atualização

1. **Backup do Ambiente Atual**
   ```powershell
   # Windows
   .\rollback.ps1 backup

   # Linux/Mac
   ./rollback.sh backup
   ```

2. **Verificar Backup**
   ```powershell
   # Windows
   .\rollback.ps1 list

   # Linux/Mac
   ./rollback.sh list
   ```

3. **Atualizar o Ambiente**
   ```bash
   # Parar containers atuais
   docker-compose down

   # Aplicar novas configurações
   docker-compose up -d

   # Verificar logs
   docker-compose logs -f
   ```

### Processo de Rollback

Se encontrar problemas após a atualização:

1. **Parar os containers**
   ```bash
   docker-compose down
   ```

2. **Executar o rollback**
   ```powershell
   # Windows
   .\rollback.ps1 rollback .\backups\[timestamp]

   # Linux/Mac
   ./rollback.sh rollback ./backups/[timestamp]
   ```

### Checklist Pós-Atualização

- [ ] Todos os containers estão em execução
- [ ] n8n está acessível via navegador
- [ ] Workflows estão funcionando
- [ ] Conexões com serviços externos estão operacionais
- [ ] Monitoramento está ativo
- [ ] Backups automáticos estão configurados

### Problemas Comuns e Soluções

#### Erro de Permissão em Volumes
```bash
docker-compose down
docker volume prune -f  # Cuidado: isso remove volumes não utilizados
docker-compose up -d
```

#### Problemas de Conexão com Banco de Dados
```bash
docker-compose logs postgres
```

## 📚 Documentação Adicional

- [Guia de Administração](docs/admin-guide.md)
- [Guia de Segurança](docs/security-guide.md)
- [Guia de Backup](docs/backup-guide.md)
- [Guia de Monitoramento](docs/monitoring-guide.md)
- [Guia de IA](docs/ai-guide.md)
- [Guia de Rollback](docs/rollback-guide.md)
- [Guia de Atualização](docs/update-guide.md)

## 🤝 Contribuição

1. Fork o projeto
2. Crie sua feature branch
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📝 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 🆘 Suporte

- Abra uma issue
- Consulte a [documentação](docs/)
- Email: support@seudominio.com

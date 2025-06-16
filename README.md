# n8n Enterprise Environment

Este é um ambiente enterprise completo para o n8n, incluindo autenticação OAuth2, monitoramento avançado, backup automatizado e alta disponibilidade.

## 🌟 Funcionalidades

- ✅ **Autenticação OAuth2 com Keycloak**
  - Single Sign-On (SSO)
  - Gerenciamento centralizado de usuários
  - Suporte a múltiplos provedores de identidade

- 🔒 **Segurança Avançada**
  - Autenticação em duas etapas
  - Criptografia de dados em repouso
  - Políticas de senha personalizáveis
  - Controle de acesso baseado em funções (RBAC)

- 📊 **Monitoramento Inteligente**
  - Dashboard Grafana personalizado
  - Métricas de negócio customizadas
  - Alertas configuráveis
  - APM (Application Performance Monitoring)

- 💾 **Backup Automatizado**
  - Backup diário para S3
  - Retenção configurável
  - Backup de workflows e dados
  - Recuperação simplificada

- 🚀 **Alta Disponibilidade**
  - Auto-scaling horizontal
  - Balanceamento de carga
  - Recuperação automática
  - Zero downtime deployments

## 🛠️ Pré-requisitos

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM (mínimo)
- 20GB espaço em disco

## 📦 Instalação

1. Clone o repositório:
```bash
git clone https://github.com/seu-usuario/n8n-enterprise
cd n8n-enterprise
```

2. Configure as variáveis de ambiente:
```bash
cp .env.example .env
# Edite o arquivo .env com suas configurações
```

3. Inicie os serviços:
```bash
docker-compose up -d
```

## 🔧 Configuração

### Keycloak (OAuth2)
1. Acesse: http://localhost:8080
2. Login: admin (senha no .env)
3. Crie um novo realm "n8n"
4. Configure o cliente OAuth2:
   - Client ID: n8n-client
   - Redirect URIs: http://localhost:5678/*

### Grafana
1. Acesse: http://localhost:3001
2. Login: admin (senha no .env)
3. Configure datasources:
   - Prometheus
   - Business Metrics

### n8n
1. Acesse: http://localhost:5678
2. Faça login usando o Keycloak
3. Configure suas credenciais e conexões

## 📊 Monitoramento

### Métricas Disponíveis
- Execuções de workflows (sucesso/erro)
- Tempo de execução
- Uso de recursos
- Métricas de negócio personalizadas

### Dashboards
- Overview do Sistema
- Performance de Workflows
- Métricas de Negócio
- Alertas e Notificações

## 💾 Backup

### Configuração
1. Configure as credenciais AWS no .env
2. Defina o bucket S3 no .env
3. Ajuste a retenção de backup (padrão: 7 dias)

### Restauração
1. Use o script `scripts/restore.sh`
2. Selecione o backup desejado
3. Aguarde a conclusão

## 🔐 Segurança

### Boas Práticas
- Mantenha o .env seguro
- Use senhas fortes
- Atualize regularmente
- Monitore os logs

### Hardening
- Firewall configurado
- HTTPS habilitado
- Secrets gerenciados
- Atualizações automáticas

## 📚 Documentação

- [Guia de Administração](docs/admin-guide.md)
- [Guia de Segurança](docs/security-guide.md)
- [Guia de Backup](docs/backup-guide.md)
- [Guia de Monitoramento](docs/monitoring-guide.md)

## 🗺️ Roadmap

Veja nosso [ROADMAP-2024.md](ROADMAP-2024.md) para os próximos desenvolvimentos.

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
- Entre em contato: support@seudominio.com

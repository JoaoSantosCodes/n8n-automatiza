# 📚 Guia de Instalação

Este guia fornece instruções detalhadas para instalar e configurar o ambiente n8n enterprise.

## 📋 Pré-requisitos

### Hardware Recomendado
- CPU: 4+ cores
- RAM: 8GB+ (4GB mínimo)
- Disco: 50GB+ SSD
- Rede: 100Mbps+

### Software Necessário
- Docker 20.10+
- Docker Compose 2.0+
- Git
- Node.js 16+
- npm 7+

### Domínio e SSL
- Domínio configurado
- Certificados SSL (ou Let's Encrypt)

## 🚀 Passo a Passo

### 1. Preparação do Ambiente

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y curl git docker.io docker-compose

# Iniciar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
```

### 2. Clone do Repositório

```bash
# Clonar repositório
git clone https://github.com/seu-usuario/n8n-enterprise
cd n8n-enterprise

# Criar diretórios necessários
mkdir -p \
    data/postgres \
    data/redis \
    data/n8n \
    logs/nginx \
    logs/n8n \
    backups
```

### 3. Configuração do Ambiente

```bash
# Copiar arquivo de exemplo
cp .env.example .env

# Editar configurações
nano .env
```

Configurações importantes no `.env`:
```env
# Básico
DOMAIN=seu-dominio.com
NODE_ENV=production

# Segurança
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=senha-segura

# Database
POSTGRES_USER=n8n
POSTGRES_PASSWORD=senha-segura
POSTGRES_DB=n8n

# Redis
REDIS_PASSWORD=senha-segura

# SMTP
SMTP_HOST=smtp.exemplo.com
SMTP_PORT=587
SMTP_USER=seu-email@exemplo.com
SMTP_PASS=senha-smtp

# Backup
S3_BUCKET=seu-bucket
AWS_ACCESS_KEY_ID=sua-key
AWS_SECRET_ACCESS_KEY=seu-secret
```

### 4. Configuração do SSL

```bash
# Criar diretório SSL
mkdir -p docker/nginx/ssl

# Copiar certificados
cp fullchain.pem docker/nginx/ssl/
cp privkey.pem docker/nginx/ssl/
```

### 5. Inicialização dos Serviços

```bash
# Construir e iniciar containers
docker-compose up -d

# Verificar status
docker-compose ps

# Verificar logs
docker-compose logs -f
```

### 6. Configuração do Monitoramento

#### Grafana
1. Acesse: https://seu-dominio.com/grafana
2. Login: admin
3. Senha: admin (altere no primeiro login)
4. Importe os dashboards:
   - n8n Overview
   - Business Metrics
   - System Monitoring

#### Kibana
1. Acesse: https://seu-dominio.com/kibana
2. Configure index patterns:
   - filebeat-*
   - metricbeat-*

### 7. Verificação

Verifique os seguintes endpoints:
- n8n: https://seu-dominio.com
- Grafana: https://seu-dominio.com/grafana
- Kibana: https://seu-dominio.com/kibana
- Prometheus: http://localhost:9090 (interno)

### 8. Backup Inicial

```bash
# Executar backup inicial
./scripts/backup.sh

# Verificar backup
ls -la backups/
```

### 9. Segurança

```bash
# Verificar configurações de segurança
docker-compose exec nginx nginx -t
docker-compose exec n8n npm audit

# Testar SSL
curl -vI https://seu-dominio.com
```

## 🔍 Verificação Pós-instalação

### Checklist
- [ ] Todos os containers rodando
- [ ] SSL funcionando
- [ ] Autenticação básica ativa
- [ ] Backups configurados
- [ ] Monitoramento ativo
- [ ] Logs sendo coletados
- [ ] Métricas sendo registradas
- [ ] Notificações funcionando

### Comandos Úteis

```bash
# Status dos serviços
docker-compose ps

# Logs
docker-compose logs -f service-name

# Restart serviço
docker-compose restart service-name

# Parar todos os serviços
docker-compose down

# Iniciar todos os serviços
docker-compose up -d
```

## 🛠 Troubleshooting

### Problemas Comuns

1. **Erro de Permissão**
```bash
sudo chown -R 1000:1000 data/
```

2. **Erro de Conexão PostgreSQL**
```bash
docker-compose exec postgres pg_isready
```

3. **Erro de SSL**
```bash
docker-compose exec nginx nginx -t
```

4. **Logs não aparecem no Kibana**
```bash
docker-compose restart filebeat
```

## 📞 Suporte

- GitHub Issues: [Link]
- Email: suporte@exemplo.com
- Discord: [Link]

## 📚 Próximos Passos

1. [Configuração Avançada](configuration.md)
2. [Guia de Segurança](security.md)
3. [Monitoramento](monitoring.md)
4. [Backup e Recuperação](backup.md) 
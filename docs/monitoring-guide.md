# Guia de Monitoramento

Este guia detalha o sistema de monitoramento do ambiente n8n enterprise, incluindo métricas, alertas e dashboards.

## 📊 Stack de Monitoramento

### Componentes
- Prometheus: Coleta de métricas
- Grafana: Visualização
- OpenTelemetry: Tracing distribuído
- AlertManager: Gerenciamento de alertas
- Jaeger: Tracing detalhado

## 🔍 Métricas Coletadas

### 1. n8n Core
- Execuções de workflows
  - Taxa de sucesso/erro
  - Tempo de execução
  - Quantidade por período
- Performance
  - Uso de CPU
  - Uso de memória
  - Latência
- Conexões
  - Status das integrações
  - Tempo de resposta
  - Taxa de erro

### 2. Banco de Dados
- PostgreSQL
  - Conexões ativas
  - Query performance
  - Tempo de resposta
  - Uso de disco
- Redis
  - Hit rate
  - Uso de memória
  - Conexões
  - Latência

### 3. Serviços de IA
- GPT Service
  - Requisições por minuto
  - Tempo de resposta
  - Custo por request
  - Taxa de erro
- AI Analytics
  - Performance dos modelos
  - Tempo de processamento
  - Uso de recursos
  - Precisão

### 4. Infraestrutura
- Kubernetes
  - Pod status
  - Node health
  - Resource utilization
  - Network metrics
- AWS
  - EKS metrics
  - S3 usage
  - Cost metrics
  - Service health

## ⚡ Alertas

### Configuração
```yaml
groups:
  - name: n8n_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(n8n_workflow_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          description: "Taxa de erro acima de 10% nos últimos 5 minutos"

      - alert: HighLatency
        expr: n8n_workflow_execution_time_seconds > 30
        for: 5m
        labels:
          severity: warning
        annotations:
          description: "Workflows demorando mais de 30 segundos para executar"
```

### Níveis de Severidade
1. Critical
   - Sistema indisponível
   - Perda de dados
   - Falha de segurança

2. Warning
   - Performance degradada
   - Recursos próximos do limite
   - Erros não críticos

3. Info
   - Eventos normais
   - Manutenção programada
   - Updates disponíveis

### Notificações
- Slack
- Email
- SMS
- PagerDuty
- Teams

## 📈 Dashboards

### 1. Overview
- Status geral
- Métricas principais
- Alertas ativos
- Tendências

### 2. Workflows
- Performance
- Taxa de sucesso
- Tempo de execução
- Erros comuns

### 3. Recursos
- Uso de CPU
- Uso de memória
- Disco
- Network

### 4. Custos
- Por serviço
- Por workflow
- Tendências
- Previsões

## 🔄 Monitoramento em Tempo Real

### Script de Monitoramento
```bash
./scripts/monitor.sh [opções]
```

Opções:
- `--interval`: Intervalo de check (default: 5m)
- `--components`: Componentes específicos
- `--metrics`: Métricas específicas
- `--output`: Formato de saída

### Verificações
1. Health Check
   ```bash
   ./scripts/monitor.sh --check health
   ```

2. Performance
   ```bash
   ./scripts/monitor.sh --check performance
   ```

3. Recursos
   ```bash
   ./scripts/monitor.sh --check resources
   ```

## 📝 Logs

### Estrutura
```
/var/log/n8n/
├── workflows/
│   ├── errors/
│   ├── performance/
│   └── audit/
├── system/
│   ├── kubernetes/
│   ├── database/
│   └── cache/
└── services/
    ├── gpt/
    ├── ai-analytics/
    └── federation/
```

### Retenção
- Logs operacionais: 30 dias
- Logs de performance: 90 dias
- Logs de auditoria: 1 ano

### Agregação
- ELK Stack
- Cloudwatch
- Loki

## 🔍 Troubleshooting

### Ferramentas
1. Diagnóstico
   ```bash
   ./scripts/monitor.sh --diagnose <componente>
   ```

2. Debug
   ```bash
   ./scripts/monitor.sh --debug <workflow-id>
   ```

3. Trace
   ```bash
   ./scripts/monitor.sh --trace <request-id>
   ```

### Procedimentos
1. Identificação
   - Verificar alertas
   - Analisar logs
   - Coletar métricas

2. Isolamento
   - Identificar componente
   - Verificar dependências
   - Testar conectividade

3. Resolução
   - Aplicar fix
   - Validar solução
   - Documentar processo

## 📊 Relatórios

### Tipos
1. Performance
   - Tempo de resposta
   - Throughput
   - Erros

2. Utilização
   - Recursos
   - Workflows
   - Integrações

3. Custos
   - Por serviço
   - Por workflow
   - Tendências

### Agendamento
- Diário: Métricas básicas
- Semanal: Performance
- Mensal: Custos e tendências

## 🔐 Segurança

### Monitoramento
- Tentativas de acesso
- Mudanças de configuração
- Uso de credenciais
- Atividades suspeitas

### Compliance
- GDPR
- LGPD
- SOC2
- ISO27001

## 📚 Recursos Adicionais

### Documentação
- [Prometheus Queries](docs/monitoring/prometheus.md)
- [Grafana Dashboards](docs/monitoring/grafana.md)
- [Alert Rules](docs/monitoring/alerts.md)

### Exemplos
- [PromQL Examples](examples/promql.md)
- [Dashboard Templates](examples/dashboards.md)
- [Alert Templates](examples/alerts.md)

### Referências
- [Best Practices](docs/monitoring/best-practices.md)
- [Troubleshooting Guide](docs/monitoring/troubleshooting.md)
- [Scaling Guide](docs/monitoring/scaling.md) 
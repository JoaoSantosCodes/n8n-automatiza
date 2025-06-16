# Guia do OpenTelemetry

Este guia detalha a implementação do OpenTelemetry no ambiente n8n enterprise.

## Visão Geral

O OpenTelemetry é usado para:
- Coleta de métricas
- Tracing distribuído
- Logging centralizado
- Análise de performance

## Arquitetura

### Componentes
- Collector
- Exporters
- Processors
- Receivers

### Integrações
- Prometheus
- Jaeger
- Elasticsearch
- Grafana

## Configuração

### Pré-requisitos
- Kubernetes cluster
- Storage para logs
- Endpoints de exportação
- Service accounts

### Instalação

1. Aplique o deployment:
```bash
kubectl apply -k kubernetes/base/opentelemetry/
```

2. Verifique a instalação:
```bash
kubectl get pods -n n8n -l app=otel-collector
```

### Configuração do Collector

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  
  prometheus:
    config:
      scrape_configs:
        - job_name: 'n8n'
          scrape_interval: 10s
          static_configs:
            - targets: ['n8n:5678']

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  
  memory_limiter:
    check_interval: 1s
    limit_mib: 1500

exporters:
  prometheus:
    endpoint: 0.0.0.0:8889
  
  otlp:
    endpoint: "jaeger:4317"
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
    
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

## Uso

### Métricas Coletadas

1. **Sistema**
- CPU usage
- Memory usage
- Disk I/O
- Network traffic

2. **Aplicação**
- Request latency
- Error rates
- Queue size
- Active workflows

3. **Business**
- Workflows completed
- Success rate
- Processing time
- Cost metrics

### Tracing

1. **Configuração no n8n**
```javascript
const tracer = opentelemetry.trace.getTracer('n8n');
const span = tracer.startSpan('workflow.execute');
try {
  // Execução do workflow
} finally {
  span.end();
}
```

2. **Visualização**
- Jaeger UI
- Grafana Tempo
- Custom dashboards

## Monitoramento

### Dashboards

1. **Operacional**
- Health status
- Resource usage
- Error rates
- Latency

2. **Business**
- Workflow metrics
- User activity
- Cost analysis
- SLA compliance

### Alertas

1. **Configuração**
```yaml
alerting:
  rules:
    - alert: HighErrorRate
      expr: rate(n8n_errors_total[5m]) > 0.1
      for: 5m
      labels:
        severity: critical
      annotations:
        description: "High error rate detected"
```

2. **Canais**
- Email
- Slack
- PagerDuty
- Webhook

## Troubleshooting

### Problemas Comuns

1. **Alta Latência**
- Verifique batch settings
- Monitore resource usage
- Ajuste buffer sizes

2. **Perda de Dados**
- Verifique conectividade
- Monitore queue size
- Ajuste retry policy

3. **Resource Usage**
- Ajuste memory limits
- Configure batch size
- Otimize exporters

## Backup e Restore

### Backup
```bash
# Backup completo
./scripts/rollback/backup-data.sh

# Backup do OpenTelemetry
./scripts/rollback/component-rollback.sh otel backup
```

### Restore
```bash
# Restore completo
./scripts/rollback/restore-backup.sh backups/full_backup_20240101_120000.tar.gz

# Restore do OpenTelemetry
./scripts/rollback/component-rollback.sh otel restore
```

## Manutenção

### Regular
- Limpeza de dados antigos
- Verificação de performance
- Atualização de configurações
- Teste de alertas

### Emergência
- Procedimento de DR
- Rollback plan
- Debug mode
- Support contacts

## Segurança

### Boas Práticas
- TLS em todas conexões
- Autenticação em endpoints
- Sanitização de dados
- Audit logging

### Compliance
- GDPR
- SOC 2
- ISO 27001
- PCI DSS

## Referências

- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [Best Practices](https://opentelemetry.io/docs/concepts/best-practices/) 
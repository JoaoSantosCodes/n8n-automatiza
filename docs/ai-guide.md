# Guia de Integrações com IA

Este guia detalha as integrações de IA disponíveis no ambiente n8n enterprise, incluindo o GPT Service e o AI Analytics.

## 🤖 GPT Service

### Visão Geral
O GPT Service é uma integração que permite utilizar modelos de linguagem avançados em seus workflows n8n.

### Funcionalidades
- Processamento de linguagem natural
- Geração de texto
- Análise de sentimento
- Classificação de documentos
- Extração de informações
- Tradução automática

### Configuração
1. Configure as credenciais:
   ```bash
   kubectl create secret generic openai-secrets \
     --from-literal=api-key=sua-chave \
     --namespace n8n
   ```

2. Ajuste os recursos:
   ```yaml
   resources:
     requests:
       cpu: "1"
       memory: "2Gi"
     limits:
       cpu: "2"
       memory: "4Gi"
   ```

3. Configure o rate limiting:
   ```yaml
   rateLimit:
     requests: 100
     period: "1m"
   ```

### Uso em Workflows
1. Use o nó "GPT Service"
2. Selecione a operação desejada
3. Configure os parâmetros
4. Processe a resposta

### Monitoramento
- Métricas de uso
- Latência de requisições
- Taxa de sucesso
- Custos por workflow

## 📊 AI Analytics

### Visão Geral
O AI Analytics oferece capacidades de análise preditiva e machine learning para seus dados n8n.

### Funcionalidades
- Previsão de séries temporais
- Detecção de anomalias
- Clustering automático
- Análise de padrões
- Recomendações
- AutoML

### Configuração
1. Configure o storage:
   ```bash
   kubectl apply -f kubernetes/base/ai-analytics/storage.yaml
   ```

2. Configure os modelos:
   ```yaml
   models:
     - name: anomaly-detection
       type: isolation-forest
       parameters:
         contamination: 0.1
     - name: forecasting
       type: prophet
       parameters:
         interval_width: 0.95
   ```

3. Configure integrações:
   ```yaml
   integrations:
     prometheus:
       enabled: true
       metrics_prefix: "ai_analytics_"
     s3:
       bucket: "n8n-ml-models"
       region: "us-east-1"
   ```

### Uso em Workflows
1. Use o nó "AI Analytics"
2. Selecione o modelo
3. Configure os parâmetros
4. Processe os resultados

### Monitoramento
- Performance dos modelos
- Uso de recursos
- Precisão das previsões
- Tempo de treinamento

## 🔄 Federation Controller

### Visão Geral
O Federation Controller permite distribuir cargas de trabalho de IA entre múltiplos clusters.

### Funcionalidades
- Load balancing de requisições
- Failover automático
- Scaling baseado em demanda
- Monitoramento distribuído

### Configuração
1. Configure o controller:
   ```bash
   kubectl apply -f kubernetes/base/federation/controller.yaml
   ```

2. Configure as políticas:
   ```yaml
   policies:
     - name: latency-based
       type: weighted
       parameters:
         max_latency: "100ms"
     - name: cost-based
       type: threshold
       parameters:
         max_cost: "10.00"
   ```

### Monitoramento
- Latência entre clusters
- Distribuição de carga
- Custos por cluster
- Saúde do sistema

## 📈 Dashboards

### GPT Service Dashboard
- Requisições por minuto
- Tempo de resposta
- Taxa de erro
- Uso por workflow
- Custos

### AI Analytics Dashboard
- Performance dos modelos
- Uso de recursos
- Precisão das previsões
- Anomalias detectadas
- Tendências

### Federation Dashboard
- Distribuição de carga
- Latência entre clusters
- Custos por região
- Status dos clusters

## 🔐 Segurança

### Boas Práticas
- Use rate limiting
- Monitore custos
- Implemente retry policies
- Valide inputs
- Sanitize outputs

### Compliance
- GDPR
- LGPD
- Audit logs
- Data retention

## 📚 Recursos Adicionais

### Documentação
- [GPT Service API](docs/api/gpt-service.md)
- [AI Analytics API](docs/api/ai-analytics.md)
- [Federation API](docs/api/federation.md)

### Exemplos
- [Análise de Sentimento](examples/sentiment-analysis.json)
- [Previsão de Demanda](examples/demand-forecast.json)
- [Detecção de Fraude](examples/fraud-detection.json)

### Troubleshooting
- [Guia de Problemas Comuns](docs/troubleshooting/ai.md)
- [FAQs](docs/faq/ai.md) 
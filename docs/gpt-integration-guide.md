# Guia de Integração GPT

Este guia detalha a integração do serviço GPT com o ambiente n8n enterprise.

## Visão Geral

O serviço GPT oferece capacidades avançadas de IA para:
- Completar workflows automaticamente
- Gerar documentação
- Otimizar workflows existentes
- Explicar códigos e configurações

## Configuração

### Pré-requisitos
- Chave API OpenAI válida
- Kubernetes cluster configurado
- Namespace n8n criado

### Instalação

1. Configure o secret com a chave API:
```bash
kubectl create secret generic openai-secrets \
  --from-literal=api_key=sua_chave_api \
  -n n8n
```

2. Aplique o deployment:
```bash
kubectl apply -k kubernetes/base/gpt-integration/
```

### Configuração do ConfigMap

O serviço usa um ConfigMap para definir:
- Modelos disponíveis (GPT-4, GPT-3.5)
- Limites de taxa
- Prompts personalizados
- Cache de respostas

## Uso

### Workflows

1. **Completar Workflow**
```json
{
  "node": "GPT Complete",
  "parameters": {
    "action": "workflow_completion",
    "context": "Descrição do workflow"
  }
}
```

2. **Gerar Documentação**
```json
{
  "node": "GPT Document",
  "parameters": {
    "action": "documentation_generation",
    "workflow_id": "123"
  }
}
```

### API REST

Endpoints disponíveis:
- `POST /api/v1/complete`: Completa workflows
- `POST /api/v1/document`: Gera documentação
- `POST /api/v1/optimize`: Sugere otimizações
- `POST /api/v1/explain`: Explica código

## Monitoramento

Métricas disponíveis:
- `gpt_requests_total`: Total de requisições
- `gpt_tokens_used`: Tokens consumidos
- `gpt_response_time`: Tempo de resposta
- `gpt_cache_hits`: Cache hits

## Troubleshooting

### Problemas Comuns

1. **Erro de Rate Limit**
   - Verifique as configurações de rate limit
   - Ajuste o cache conforme necessário

2. **Latência Alta**
   - Verifique a conexão com a API
   - Monitore o uso de recursos

3. **Erros de Token**
   - Valide a chave API
   - Verifique os logs do pod

## Segurança

- Todas as requisições são autenticadas
- Dados sensíveis são criptografados
- Logs não contêm informações sensíveis
- Rate limiting por usuário/IP

## Manutenção

### Backup
```bash
./scripts/rollback/backup-data.sh
```

### Rollback
```bash
./scripts/rollback/component-rollback.sh gpt v1.0.0
```

## Referências

- [Documentação OpenAI](https://platform.openai.com/docs)
- [API Reference](https://platform.openai.com/docs/api-reference)
- [Best Practices](https://platform.openai.com/docs/guides/best-practices) 
import os
import time
import requests
from datetime import datetime, timedelta
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

# Configurações
N8N_API_URL = os.getenv('N8N_API_URL')
N8N_API_KEY = os.getenv('N8N_API_KEY')
PUSHGATEWAY_URL = os.getenv('PUSHGATEWAY_URL')
COLLECTION_INTERVAL = 300  # 5 minutos

# Headers para API do n8n
headers = {
    'X-N8N-API-KEY': N8N_API_KEY,
    'Content-Type': 'application/json'
}

# Registro do Prometheus
registry = CollectorRegistry()

# Métricas
workflow_executions = Gauge('n8n_workflow_executions_total', 
    'Total de execuções de workflows', 
    ['workflow_name', 'status'],
    registry=registry)

workflow_execution_time = Gauge('n8n_workflow_execution_time_seconds',
    'Tempo de execução dos workflows',
    ['workflow_name'],
    registry=registry)

workflow_errors = Gauge('n8n_workflow_errors_total',
    'Total de erros nos workflows',
    ['workflow_name', 'error_type'],
    registry=registry)

business_value = Gauge('n8n_business_value_total',
    'Valor de negócio gerado',
    ['workflow_name', 'metric_type'],
    registry=registry)

def collect_workflow_metrics():
    try:
        # Buscar workflows
        workflows = requests.get(f"{N8N_API_URL}/workflows", headers=headers).json()
        
        for workflow in workflows:
            workflow_id = workflow['id']
            workflow_name = workflow['name']
            
            # Execuções
            executions = requests.get(
                f"{N8N_API_URL}/workflows/{workflow_id}/executions",
                headers=headers
            ).json()
            
            success_count = 0
            error_count = 0
            total_time = 0
            
            for execution in executions:
                if execution['status'] == 'success':
                    success_count += 1
                else:
                    error_count += 1
                    
                # Tempo de execução
                start_time = datetime.fromisoformat(execution['startedAt'].replace('Z', '+00:00'))
                end_time = datetime.fromisoformat(execution['finishedAt'].replace('Z', '+00:00'))
                execution_time = (end_time - start_time).total_seconds()
                total_time += execution_time
                
                # Erros
                if execution['status'] == 'error':
                    error_type = execution.get('error', {}).get('type', 'unknown')
                    workflow_errors.labels(
                        workflow_name=workflow_name,
                        error_type=error_type
                    ).inc()
            
            # Atualizar métricas
            workflow_executions.labels(
                workflow_name=workflow_name,
                status='success'
            ).set(success_count)
            
            workflow_executions.labels(
                workflow_name=workflow_name,
                status='error'
            ).set(error_count)
            
            if len(executions) > 0:
                avg_time = total_time / len(executions)
                workflow_execution_time.labels(
                    workflow_name=workflow_name
                ).set(avg_time)
            
            # Métricas de negócio
            if 'tags' in workflow and 'business_value' in workflow['tags']:
                business_value.labels(
                    workflow_name=workflow_name,
                    metric_type='estimated_value'
                ).set(float(workflow['tags']['business_value']))
        
        # Enviar métricas para o Pushgateway
        push_to_gateway(PUSHGATEWAY_URL, job='n8n_metrics', registry=registry)
        
    except Exception as e:
        print(f"Erro ao coletar métricas: {str(e)}")

def main():
    while True:
        collect_workflow_metrics()
        time.sleep(COLLECTION_INTERVAL)

if __name__ == "__main__":
    main() 
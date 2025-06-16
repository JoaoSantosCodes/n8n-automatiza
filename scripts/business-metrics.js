const { Client } = require('pg');
const { promisify } = require('util');
const Redis = require('ioredis');
const { register, Gauge, Counter, Histogram } = require('prom-client');

// Métricas do Prometheus
const workflowSuccessRate = new Gauge({
    name: 'n8n_workflow_success_rate',
    help: 'Taxa de sucesso dos workflows nas últimas 24h'
});

const workflowExecutionTime = new Histogram({
    name: 'n8n_workflow_execution_time',
    help: 'Tempo de execução dos workflows',
    buckets: [1, 5, 10, 30, 60, 120, 300, 600]
});

const activeUsers = new Gauge({
    name: 'n8n_active_users',
    help: 'Número de usuários ativos'
});

const workflowsByTag = new Gauge({
    name: 'n8n_workflows_by_tag',
    help: 'Número de workflows por tag',
    labelNames: ['tag']
});

const errorsByType = new Counter({
    name: 'n8n_errors_by_type',
    help: 'Número de erros por tipo',
    labelNames: ['error_type']
});

// Conexão com PostgreSQL
const pgClient = new Client({
    host: process.env.POSTGRES_HOST,
    port: process.env.POSTGRES_PORT,
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
});

// Conexão com Redis
const redisClient = new Redis({
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT,
    password: process.env.REDIS_PASSWORD,
    tls: {}
});

async function collectMetrics() {
    try {
        // Calcular taxa de sucesso
        const successRateQuery = `
            SELECT 
                COUNT(CASE WHEN status = 'success' THEN 1 END)::float / COUNT(*) * 100 as success_rate
            FROM execution_entity
            WHERE finished_at > NOW() - INTERVAL '24 hours';
        `;
        const successRateResult = await pgClient.query(successRateQuery);
        workflowSuccessRate.set(successRateResult.rows[0].success_rate);

        // Coletar tempos de execução
        const executionTimeQuery = `
            SELECT 
                EXTRACT(EPOCH FROM (finished_at - started_at)) as duration
            FROM execution_entity
            WHERE finished_at > NOW() - INTERVAL '1 hour';
        `;
        const executionTimeResult = await pgClient.query(executionTimeQuery);
        executionTimeResult.rows.forEach(row => {
            workflowExecutionTime.observe(row.duration);
        });

        // Contar usuários ativos
        const activeUsersQuery = `
            SELECT COUNT(DISTINCT user_id) as active_users
            FROM auth_entity
            WHERE last_login > NOW() - INTERVAL '24 hours';
        `;
        const activeUsersResult = await pgClient.query(activeUsersQuery);
        activeUsers.set(activeUsersResult.rows[0].active_users);

        // Contar workflows por tag
        const workflowsByTagQuery = `
            SELECT 
                tags.name as tag_name,
                COUNT(*) as count
            FROM workflow_entity w
            JOIN workflow_tags wt ON w.id = wt.workflow_id
            JOIN tags ON tags.id = wt.tag_id
            GROUP BY tags.name;
        `;
        const workflowsByTagResult = await pgClient.query(workflowsByTagQuery);
        workflowsByTagResult.rows.forEach(row => {
            workflowsByTag.set({ tag: row.tag_name }, row.count);
        });

        // Coletar erros do Redis
        const errors = await redisClient.hgetall('n8n:errors');
        Object.entries(errors).forEach(([type, count]) => {
            errorsByType.inc({ error_type: type }, parseInt(count));
        });

        // Limpar contadores de erro no Redis
        await redisClient.del('n8n:errors');

    } catch (error) {
        console.error('Erro ao coletar métricas:', error);
    }
}

// Coletar métricas a cada minuto
setInterval(collectMetrics, 60000);

// Endpoint para o Prometheus
const express = require('express');
const app = express();

app.get('/metrics', async (req, res) => {
    try {
        await collectMetrics();
        res.set('Content-Type', register.contentType);
        res.end(await register.metrics());
    } catch (error) {
        res.status(500).end(error.message);
    }
});

app.listen(9100, '0.0.0.0', () => {
    console.log('Servidor de métricas rodando na porta 9100');
}); 
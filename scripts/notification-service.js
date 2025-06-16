const express = require('express');
const Redis = require('ioredis');
const nodemailer = require('nodemailer');
const { Webhook, MessageBuilder } = require('discord-webhook-node');
const { WebClient } = require('@slack/web-api');

class NotificationService {
    constructor() {
        this.app = express();
        this.redis = new Redis({
            host: process.env.REDIS_HOST,
            port: process.env.REDIS_PORT,
            password: process.env.REDIS_PASSWORD,
            tls: {}
        });

        // Email
        this.emailTransporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST,
            port: process.env.SMTP_PORT,
            secure: true,
            auth: {
                user: process.env.SMTP_USER,
                pass: process.env.SMTP_PASS
            }
        });

        // Slack
        this.slack = new WebClient(process.env.SLACK_TOKEN);

        // Discord
        this.discord = new Webhook(process.env.DISCORD_WEBHOOK_URL);

        this.setupRoutes();
    }

    setupRoutes() {
        this.app.use(express.json());

        // Endpoint para receber notificações
        this.app.post('/notify', async (req, res) => {
            try {
                const { type, message, priority, recipients, metadata } = req.body;
                await this.processNotification(type, message, priority, recipients, metadata);
                res.status(200).json({ status: 'success' });
            } catch (error) {
                console.error('Erro ao processar notificação:', error);
                res.status(500).json({ error: error.message });
            }
        });

        // Endpoint de health check
        this.app.get('/health', (req, res) => {
            res.status(200).json({ status: 'healthy' });
        });
    }

    async processNotification(type, message, priority = 'normal', recipients = [], metadata = {}) {
        // Registrar notificação no Redis para histórico
        await this.redis.lpush('notifications:history', JSON.stringify({
            type,
            message,
            priority,
            timestamp: new Date().toISOString(),
            metadata
        }));

        // Limitar histórico a 1000 entradas
        await this.redis.ltrim('notifications:history', 0, 999);

        switch (type) {
            case 'email':
                await this.sendEmail(message, recipients, priority, metadata);
                break;
            case 'slack':
                await this.sendSlack(message, priority, metadata);
                break;
            case 'discord':
                await this.sendDiscord(message, priority, metadata);
                break;
            case 'all':
                await Promise.all([
                    this.sendEmail(message, recipients, priority, metadata),
                    this.sendSlack(message, priority, metadata),
                    this.sendDiscord(message, priority, metadata)
                ]);
                break;
        }

        // Se for alta prioridade, garantir entrega
        if (priority === 'high') {
            await this.ensureDelivery(type, message, recipients, metadata);
        }
    }

    async sendEmail(message, recipients, priority, metadata) {
        const mailOptions = {
            from: process.env.SMTP_FROM,
            to: recipients.join(','),
            subject: `[${priority.toUpperCase()}] N8N Notification`,
            text: message,
            html: this.formatEmailHtml(message, metadata)
        };

        await this.emailTransporter.sendMail(mailOptions);
    }

    async sendSlack(message, priority, metadata) {
        const blocks = [
            {
                type: "section",
                text: {
                    type: "mrkdwn",
                    text: `*Priority: ${priority.toUpperCase()}*\n${message}`
                }
            }
        ];

        if (Object.keys(metadata).length > 0) {
            blocks.push({
                type: "section",
                text: {
                    type: "mrkdwn",
                    text: `*Additional Info:*\n${JSON.stringify(metadata, null, 2)}`
                }
            });
        }

        await this.slack.chat.postMessage({
            channel: process.env.SLACK_CHANNEL,
            blocks
        });
    }

    async sendDiscord(message, priority, metadata) {
        const embed = new MessageBuilder()
            .setTitle(`N8N Notification - ${priority.toUpperCase()}`)
            .setDescription(message)
            .setColor(this.getPriorityColor(priority))
            .setTimestamp();

        if (Object.keys(metadata).length > 0) {
            embed.addField('Additional Info', '```' + JSON.stringify(metadata, null, 2) + '```');
        }

        await this.discord.send(embed);
    }

    async ensureDelivery(type, message, recipients, metadata) {
        // Tentar reenviar até 3 vezes em caso de falha
        for (let i = 0; i < 3; i++) {
            try {
                switch (type) {
                    case 'email':
                        await this.sendEmail(message, recipients, 'high', metadata);
                        break;
                    case 'slack':
                        await this.sendSlack(message, 'high', metadata);
                        break;
                    case 'discord':
                        await this.sendDiscord(message, 'high', metadata);
                        break;
                }
                break;
            } catch (error) {
                console.error(`Tentativa ${i + 1} falhou:`, error);
                await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
            }
        }
    }

    getPriorityColor(priority) {
        switch (priority) {
            case 'high':
                return 0xFF0000; // Vermelho
            case 'normal':
                return 0x00FF00; // Verde
            default:
                return 0xFFFF00; // Amarelo
        }
    }

    formatEmailHtml(message, metadata) {
        return `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background-color: #f8f9fa; padding: 20px; border-radius: 5px;">
                    <h2 style="color: #333;">N8N Notification</h2>
                    <p style="color: #666;">${message}</p>
                    ${Object.keys(metadata).length > 0 ? `
                        <div style="background-color: #fff; padding: 15px; border-radius: 3px; margin-top: 20px;">
                            <h3 style="color: #333; margin-top: 0;">Additional Information</h3>
                            <pre style="background-color: #f5f5f5; padding: 10px; border-radius: 3px;">${JSON.stringify(metadata, null, 2)}</pre>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;
    }

    start(port = 3000) {
        this.app.listen(port, '0.0.0.0', () => {
            console.log(`Serviço de notificações rodando na porta ${port}`);
        });
    }
}

const service = new NotificationService();
service.start(); 
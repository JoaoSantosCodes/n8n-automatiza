# Guia de Atualização do Ambiente n8n

Este guia fornece instruções detalhadas sobre como atualizar seu ambiente n8n de forma segura e eficiente.

## 📋 Pré-requisitos

Antes de iniciar o processo de atualização, certifique-se de que você tem:

- Docker Desktop instalado e em execução
- PowerShell (Windows) ou Bash (Linux/Mac)
- Acesso administrativo ao sistema
- Espaço em disco suficiente para backups (recomendado: 3x o tamanho atual do ambiente)
- Todas as alterações importantes commitadas no git

## 🔄 Processo de Atualização

### 1. Preparação

1. Verifique o estado atual do sistema:
   ```bash
   docker-compose ps
   docker-compose logs --tail=100
   ```

2. Verifique o espaço em disco disponível:
   ```bash
   # Windows (PowerShell)
   Get-PSDrive C

   # Linux/Mac
   df -h
   ```

### 2. Backup

1. Execute o backup do ambiente:
   ```powershell
   # Windows
   .\rollback.ps1 backup

   # Linux/Mac
   ./rollback.sh backup
   ```

2. Verifique se o backup foi criado corretamente:
   ```powershell
   # Windows
   .\rollback.ps1 list

   # Linux/Mac
   ./rollback.sh list
   ```

3. Anote o timestamp do backup para possível rollback

### 3. Atualização

1. Pare os containers atuais:
   ```bash
   docker-compose down
   ```

2. Aplique as novas configurações:
   ```bash
   docker-compose up -d
   ```

3. Monitore os logs durante a inicialização:
   ```bash
   docker-compose logs -f
   ```

### 4. Verificação

Execute a checklist pós-atualização:

- [ ] Todos os containers estão em execução (`docker-compose ps`)
- [ ] n8n está acessível via navegador
- [ ] Workflows estão funcionando corretamente
- [ ] Conexões com serviços externos estão operacionais
- [ ] Sistema de monitoramento está ativo
- [ ] Backups automáticos estão configurados
- [ ] Logs não mostram erros críticos

## ⚠️ Solução de Problemas

### Erro de Permissão em Volumes

Se encontrar erros de permissão ao acessar volumes:

```bash
docker-compose down
docker volume prune -f  # Cuidado: isso remove volumes não utilizados
docker-compose up -d
```

### Problemas de Conexão com Banco de Dados

1. Verifique os logs do PostgreSQL:
   ```bash
   docker-compose logs postgres
   ```

2. Verifique as conexões:
   ```bash
   docker-compose exec postgres pg_isready
   ```

### Containers Não Iniciam

1. Verifique os logs específicos:
   ```bash
   docker-compose logs [nome-do-servico]
   ```

2. Verifique as configurações de rede:
   ```bash
   docker network ls
   docker network inspect n8n_default
   ```

## 🔙 Processo de Rollback

Se encontrar problemas graves após a atualização:

1. Pare todos os serviços:
   ```bash
   docker-compose down
   ```

2. Execute o rollback para o último backup funcional:
   ```powershell
   # Windows
   .\rollback.ps1 rollback .\backups\[timestamp]

   # Linux/Mac
   ./rollback.sh rollback ./backups/[timestamp]
   ```

3. Verifique o ambiente após o rollback usando a mesma checklist de verificação.

## 📝 Boas Práticas

1. **Sempre faça backup antes de atualizar**
   - Mantenha backups por pelo menos 30 dias
   - Verifique a integridade dos backups regularmente

2. **Documente o Processo**
   - Mantenha um log de atualizações
   - Registre problemas encontrados e soluções
   - Atualize a documentação conforme necessário

3. **Monitore o Ambiente**
   - Configure alertas para problemas críticos
   - Mantenha logs organizados
   - Revise métricas de performance regularmente

4. **Planejamento**
   - Agende atualizações em horários de baixo uso
   - Comunique stakeholders sobre janelas de manutenção
   - Tenha um plano de contingência

## 📞 Suporte

Em caso de problemas:

1. Consulte os logs dos containers
2. Verifique a [documentação oficial do n8n](https://docs.n8n.io/)
3. Verifique o status dos serviços externos
4. Execute o rollback se necessário
5. Abra uma issue no repositório do projeto
6. Contate o suporte técnico: support@seudominio.com 
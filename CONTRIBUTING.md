# Guia de Contribuição

Obrigado por considerar contribuir para o projeto! Este guia ajudará você a entender como pode participar do desenvolvimento.

## Índice

1. [Código de Conduta](#código-de-conduta)
2. [Como Contribuir](#como-contribuir)
3. [Ambiente de Desenvolvimento](#ambiente-de-desenvolvimento)
4. [Padrões de Código](#padrões-de-código)
5. [Processo de Pull Request](#processo-de-pull-request)
6. [Segurança](#segurança)

## Código de Conduta

Este projeto segue um Código de Conduta. Ao participar, você concorda em seguir suas diretrizes.

### Nossos Compromissos

- Respeito mútuo
- Comunicação construtiva
- Foco na comunidade
- Inclusão e diversidade

## Como Contribuir

### Reportando Bugs

1. Verifique se o bug já não foi reportado
2. Use o template de bug report
3. Inclua:
   - Versão do software
   - Ambiente (OS, K8s version, etc)
   - Passos para reproduzir
   - Comportamento esperado
   - Logs relevantes

### Sugerindo Melhorias

1. Verifique se a sugestão já não existe
2. Use o template de feature request
3. Descreva:
   - Problema que resolve
   - Solução proposta
   - Alternativas consideradas
   - Impacto na base de código

## Ambiente de Desenvolvimento

### Setup

1. Fork o repositório
2. Clone localmente:
```bash
git clone https://github.com/seu-usuario/n8n-enterprise.git
cd n8n-enterprise
```

3. Instale dependências:
```bash
npm install
```

4. Configure ambiente:
```bash
cp .env.example .env
```

### Testes

1. Testes unitários:
```bash
npm run test:unit
```

2. Testes de integração:
```bash
npm run test:integration
```

3. Testes end-to-end:
```bash
npm run test:e2e
```

## Padrões de Código

### Estilo

- Use ESLint e Prettier
- Siga o estilo existente
- Documente código novo
- Escreva testes

### Commits

Formato:
```
tipo(escopo): descrição curta

Descrição longa se necessário
```

Tipos:
- feat: nova feature
- fix: correção de bug
- docs: documentação
- style: formatação
- refactor: refatoração
- test: testes
- chore: manutenção

### Branches

- `main`: produção
- `develop`: desenvolvimento
- `feature/*`: novas features
- `fix/*`: correções
- `docs/*`: documentação

## Processo de Pull Request

1. Crie branch específica
2. Faça commits atômicos
3. Escreva testes
4. Atualize documentação
5. Abra PR para `develop`

### Review

- CI deve passar
- Precisa aprovação
- Sem conflitos
- Documentação atualizada

## Segurança

### Reportando Vulnerabilidades

1. NÃO abra issue pública
2. Email: security@seudominio.com
3. Inclua:
   - Descrição
   - Impacto
   - Reprodução
   - Possível fix

### Boas Práticas

- Não commit secrets
- Use HTTPS/SSH
- Revise dependências
- Siga guidelines

## Dúvidas?

- Abra uma issue
- Email: support@seudominio.com
- Discord: link-do-discord

## Agradecimentos

Agradecemos a todos que contribuem para tornar este projeto melhor! 
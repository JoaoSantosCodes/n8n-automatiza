#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configurações
REPO_URL="https://github.com/JoaoSantosCodes/n8n-automatiza.git"
BRANCH="main"

echo -e "${YELLOW}Iniciando processo de publicação...${NC}"

# Verificar se git está instalado
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git não está instalado. Instalando...${NC}"
    sudo apt-get update && sudo apt-get install -y git
fi

# Verificar se já é um repositório git
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Inicializando repositório git...${NC}"
    git init
    git remote add origin $REPO_URL
else
    echo -e "${YELLOW}Verificando remote...${NC}"
    if ! git remote | grep -q "origin"; then
        git remote add origin $REPO_URL
    fi
fi

# Atualizar arquivos de documentação
echo -e "${YELLOW}Atualizando arquivos de documentação...${NC}"

# Gerar lista de arquivos modificados
echo -e "${YELLOW}Verificando arquivos modificados...${NC}"
git status

# Adicionar todos os arquivos
echo -e "${YELLOW}Adicionando arquivos ao git...${NC}"
git add .

# Commit com timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo -e "${YELLOW}Criando commit...${NC}"
git commit -m "Atualização automática - $TIMESTAMP"

# Pull antes do push para evitar conflitos
echo -e "${YELLOW}Sincronizando com repositório remoto...${NC}"
git pull origin $BRANCH --rebase

# Push para o GitHub
echo -e "${YELLOW}Publicando no GitHub...${NC}"
git push -u origin $BRANCH

echo -e "${GREEN}Processo de publicação concluído!${NC}"

# Verificar status final
echo -e "${YELLOW}Status final:${NC}"
git status 
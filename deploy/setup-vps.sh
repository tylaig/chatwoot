#!/usr/bin/env bash
set -euo pipefail

echo "======================================================"
echo "  🚀 Chatwoot Custom - Setup Inicial da VPS"
echo "======================================================"

# 1. Atualizar pacotes
echo "📦 Atualizando pacotes do sistema..."
apt-get update -y && apt-get upgrade -y
apt-get install -y curl git ufw jq ca-certificates

# 2. Instalar Docker e Docker Compose caso não existam
if ! command -v docker &> /dev/null; then
  echo "🐳 Instalando Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm -f get-docker.sh
  systemctl enable --now docker
fi

# 3. Criar diretório /opt/chatwoot
echo "📁 Preparando diretório /opt/chatwoot..."
mkdir -p /opt/chatwoot

# 4. Copiar docker-compose se executado da pasta do repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.yaml" ]; then
  cp "$SCRIPT_DIR/docker-compose.yaml" /opt/chatwoot/docker-compose.yaml
fi

if [ ! -f /opt/chatwoot/.env ] && [ -f "$SCRIPT_DIR/.env.production.example" ]; then
  cp "$SCRIPT_DIR/.env.production.example" /opt/chatwoot/.env
  echo "⚠️ Arquivo /opt/chatwoot/.env criado a partir do exemplo. LEMBRE-SE DE EDITAR SUAS SENHAS E DOMÍNIO!"
fi

echo "======================================================"
echo "✅ Setup da VPS concluído!"
echo "Próximos passos:"
echo " 1. Edite /opt/chatwoot/.env com seu domínio e senhas"
echo " 2. Configure os Secrets no GitHub (VPS_HOST, VPS_USER, VPS_SSH_KEY)"
echo " 3. Dispare o GitHub Actions para o primeiro deploy!"
echo "======================================================"

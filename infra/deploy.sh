#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy.sh — Deploy Azure PostgreSQL infrastructure for SkyReward migration
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-skyreward-migration}"
LOCATION="${LOCATION:-westeurope}"
DEPLOYMENT_NAME="skyreward-pg-$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_FILE="${SCRIPT_DIR}/main.bicep"
PARAMS_FILE="${SCRIPT_DIR}/parameters.json"

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Pre-flight checks ──────────────────────────────────────────────────────
command -v az >/dev/null 2>&1 || { error "Azure CLI (az) is not installed."; exit 1; }

if ! az account show >/dev/null 2>&1; then
  error "Not logged in to Azure. Run 'az login' first."
  exit 1
fi

# ── Prompt for admin password if not supplied via env ───────────────────────
if [[ -z "${PG_ADMIN_PASSWORD:-}" ]]; then
  read -rsp "Enter PostgreSQL admin password: " PG_ADMIN_PASSWORD
  echo
fi

# Validate password meets Azure requirements (8+ chars)
if [[ ${#PG_ADMIN_PASSWORD} -lt 8 ]]; then
  error "Password must be at least 8 characters."
  exit 1
fi

# ── Detect client IP for firewall rule ──────────────────────────────────────
info "Detecting your public IP address…"
CLIENT_IP=$(curl -s https://api.ipify.org || echo "0.0.0.0")
info "Client IP: ${CLIENT_IP}"

# ── Create resource group if it doesn't exist ──────────────────────────────
if ! az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  info "Creating resource group '${RESOURCE_GROUP}' in '${LOCATION}'…"
  az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none
else
  info "Resource group '${RESOURCE_GROUP}' already exists."
fi

# ── Deploy Bicep template ──────────────────────────────────────────────────
info "Starting deployment '${DEPLOYMENT_NAME}'…"
az deployment group create \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${BICEP_FILE}" \
  --parameters "${PARAMS_FILE}" \
  --parameters administratorPassword="${PG_ADMIN_PASSWORD}" \
               clientIpAddress="${CLIENT_IP}" \
  --output table

# ── Show outputs ────────────────────────────────────────────────────────────
info "Deployment complete. Outputs:"
az deployment group show \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "properties.outputs" \
  --output table

SERVER_FQDN=$(az deployment group show \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "properties.outputs.serverFqdn.value" \
  --output tsv)

info "──────────────────────────────────────────────────────"
info "Connection string:"
info "  psql \"host=${SERVER_FQDN} port=5432 dbname=skyreward user=skyreward_admin sslmode=require\""
info "──────────────────────────────────────────────────────"

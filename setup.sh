#!/usr/bin/env bash
# Sentinel — Configuración inicial del entorno
# Uso: chmod +x setup.sh && ./setup.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

printf "${CYAN}╔══════════════════════════════════════╗\n"
printf "║    Sentinel — Configuración inicial   ║\n"
printf "╚══════════════════════════════════════╝${NC}\n\n"

if [ -f .env ]; then
    printf "${YELLOW}Ya existe un .env — guardando backup como .env.bak${NC}\n"
    cp .env .env.bak
fi

# ── Detectar IP de la VM ──────────────────────────────────────────────────────
VM_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
if [ -z "${VM_IP:-}" ]; then
    VM_IP=$(ip -4 addr show scope global 2>/dev/null \
        | awk '/inet /{print $2}' | cut -d/ -f1 | head -1 || true)
fi
if [ -z "${VM_IP:-}" ]; then
    read -r -p "No se pudo detectar la IP. Ingresá la IP de esta VM: " VM_IP
fi
printf "  IP detectada: ${GREEN}%s${NC}\n\n" "$VM_IP"

# ── Generar clave de encriptación para n8n ────────────────────────────────────
if command -v openssl >/dev/null 2>&1; then
    N8N_KEY=$(openssl rand -hex 32)
else
    N8N_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
fi

# ── Credenciales ──────────────────────────────────────────────────────────────
printf "${YELLOW}Configurar credenciales${NC} (Enter para aceptar el valor entre [corchetes])\n\n"

read -r -p "  Usuario PostgreSQL [sentinel]: " PG_USER
PG_USER=${PG_USER:-sentinel}

while true; do
    read -r -s -p "  Contraseña PostgreSQL: " PG_PASS; printf "\n"
    if [ -n "$PG_PASS" ]; then break; fi
    printf "  ${RED}No puede estar vacía.${NC}\n"
done

read -r -p "  Usuario GVM/OpenVAS [admin]: " GVM_U
GVM_U=${GVM_U:-admin}

while true; do
    read -r -s -p "  Contraseña GVM/OpenVAS: " GVM_P; printf "\n"
    if [ -n "$GVM_P" ]; then break; fi
    printf "  ${RED}No puede estar vacía.${NC}\n"
done

read -r -p "  Usuario n8n [admin]: " N8N_U
N8N_U=${N8N_U:-admin}

while true; do
    read -r -s -p "  Contraseña n8n: " N8N_P; printf "\n"
    if [ -n "$N8N_P" ]; then break; fi
    printf "  ${RED}No puede estar vacía.${NC}\n"
done

read -r -p "  Red de laboratorio [192.168.100.0/24]: " SCAN_NET
SCAN_NET=${SCAN_NET:-192.168.100.0/24}

read -r -p "  Zona horaria [America/Argentina/Buenos_Aires]: " TZ_VAL
TZ_VAL=${TZ_VAL:-America/Argentina/Buenos_Aires}

# ── Escribir .env ─────────────────────────────────────────────────────────────
# Usamos printf para todas las líneas para manejar correctamente caracteres
# especiales (como $, !, ") que podrían aparecer en las contraseñas.
{
    printf '# ── Base de datos (PostgreSQL) ────────────────────────────────────────────────\n'
    printf 'POSTGRES_DB=security_scans\n'
    printf 'POSTGRES_USER=%s\n' "$PG_USER"
    printf 'POSTGRES_PASSWORD=%s\n' "$PG_PASS"
    printf '\n'
    printf '# ── Dashboard ─────────────────────────────────────────────────────────────────\n'
    printf 'DB_HOST=postgres-scans\n'
    printf 'DB_NAME=security_scans\n'
    printf 'DB_USER=%s\n' "$PG_USER"
    printf 'DB_PASSWORD=%s\n' "$PG_PASS"
    printf 'DB_PORT=5432\n'
    printf '\n'
    printf '# ── n8n ───────────────────────────────────────────────────────────────────────\n'
    printf 'N8N_ENCRYPTION_KEY=%s\n' "$N8N_KEY"
    printf 'WEBHOOK_URL=http://%s:5678/\n' "$VM_IP"
    printf 'N8N_USER=%s\n' "$N8N_U"
    printf 'N8N_PASSWORD=%s\n' "$N8N_P"
    printf '\n'
    printf '# ── GVM / OpenVAS ─────────────────────────────────────────────────────────────\n'
    printf 'GVM_USER=%s\n' "$GVM_U"
    printf 'GVM_PASSWORD=%s\n' "$GVM_P"
    printf '\n'
    printf '# ── Integración dashboard → n8n ───────────────────────────────────────────────\n'
    printf 'N8N_WEBHOOK_URL=http://n8n:5678/webhook/start-scan\n'
    printf '\n'
    printf '# ── Red de laboratorio ────────────────────────────────────────────────────────\n'
    printf 'SCAN_NETWORK=%s\n' "$SCAN_NET"
    printf '\n'
    printf '# ── Zona horaria ──────────────────────────────────────────────────────────────\n'
    printf 'TZ=%s\n' "$TZ_VAL"
} > .env

printf "\n${GREEN}✓ .env generado correctamente${NC}\n\n"
printf "${CYAN}Próximos pasos:${NC}\n"
printf "  1. ${YELLOW}docker compose up -d${NC}\n"
printf "  2. Primera vez: aguardá 10-30 min para la descarga de feeds de OpenVAS\n"
printf "  3. Importá el workflow en n8n → Workflows → Import from file\n"
printf "     Configurá las credenciales de PostgreSQL en los nodos y publicá el workflow\n"
printf "\n${CYAN}Accesos una vez levantado:${NC}\n"
printf "  Dashboard  →  ${GREEN}http://%s:5002${NC}\n" "$VM_IP"
printf "  n8n        →  ${GREEN}http://%s:5678${NC}  (usuario: %s)\n" "$VM_IP" "$N8N_U"
printf "  OpenVAS    →  ${GREEN}http://%s:9392${NC}\n" "$VM_IP"

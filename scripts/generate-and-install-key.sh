#!/usr/bin/env bash
set -euo pipefail

timestamp(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log(){ printf '[%s] %s\n' "$(timestamp)" "$*" >&2; }
err(){ printf '[%s] ERROR: %s\n' "$(timestamp)" "$*" >&2; }

usage(){
  cat <<EOF
Genera un par de claves (ed25519) y sobrescribe authorized_keys del servicio.

Uso:
  ./scripts/generate-and-install-key.sh [--key /ruta/a/id_ed25519] [--force]

Opciones:
  --key PATH    Ruta del archivo de clave privada a crear (por defecto: ~/.ssh/id_ed25519_as2025)
  --force       Sobrescribe la clave privada existente y el authorized_keys sin preguntar

EOF
}

KEY_PATH="${HOME}/.ssh/id_ed25519_as2025"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) KEY_PATH="$2"; shift 2;;
    --force) FORCE=1; shift;;
    -h|--help) usage; exit 0;;
    *) err "Argumento desconocido: $1"; usage; exit 2;;
  esac
done

require_cmd(){ command -v "$1" >/dev/null 2>&1 || { err "Se requiere: $1"; exit 3; } }
require_cmd ssh-keygen

SSH_CFG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/stacks/services/ssh/config/.ssh"
AUTHORIZED_KEYS_FILE="$SSH_CFG_DIR/authorized_keys"

mkdir -p "$(dirname "$KEY_PATH")"
mkdir -p "$SSH_CFG_DIR"

if [[ -f "$KEY_PATH" && $FORCE -ne 1 ]]; then
  err "La clave privada ya existe en $KEY_PATH. Usa --force para sobrescribir." 
  exit 4
fi

if [[ $FORCE -eq 1 && -f "$KEY_PATH" ]]; then
  log "Sobrescribiendo clave privada existente en: $KEY_PATH"
  rm -f "$KEY_PATH" "$KEY_PATH.pub" "$KEY_PATH-cert.pub"
fi

if [[ -f "$AUTHORIZED_KEYS_FILE" ]]; then
  backup="${AUTHORIZED_KEYS_FILE}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  cp -a "$AUTHORIZED_KEYS_FILE" "$backup"
  log "Backup: existing authorized_keys -> $backup"
fi

log "Generando par de claves en: $KEY_PATH"
ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "as2025@$(hostname)" >/dev/null

if [[ ! -f "$KEY_PATH.pub" ]]; then
  err "No se generó la clave pública"; exit 5
fi

log "Instalando clave pública en: $AUTHORIZED_KEYS_FILE"
cp -f "$KEY_PATH.pub" "$AUTHORIZED_KEYS_FILE"
chmod 600 "$AUTHORIZED_KEYS_FILE"

fp="$(ssh-keygen -lf "$KEY_PATH.pub" 2>/dev/null || true)"
if [[ -n "$fp" ]]; then
  log "Fingerprint clave pública: $fp"
fi

log "Hecho. Para conectarte desde este equipo (privada en $KEY_PATH):"
printf "  ssh -p 2222 -i %s admin_user@<HOST>\n" "$KEY_PATH"
log "Si el contenedor corre en la misma máquina, usa HOST=127.0.0.1"
log "Nota: la clave privada NO se sube al repositorio. Manténla segura."

exit 0

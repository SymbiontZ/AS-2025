#!/usr/bin/env bash
set -euo pipefail

timestamp(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf '[%s] %s\n' "$(timestamp)" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$(timestamp)" "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontro el comando requerido: $1"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_KEYS_VOLUME_NAME="${SSH_KEYS_VOLUME_NAME:-services_ssh_host_keys}"
SSH_KEYS_STAGE_DIR="$(mktemp -d)"
SSH_CFG_DIR="$ROOT_DIR/stacks/services/ssh/config/.ssh"
AUTH_KEYS_EXAMPLE="$SSH_CFG_DIR/authorized_keys.example"
AUTH_KEYS_TARGET="$SSH_CFG_DIR/authorized_keys"

require_cmd ssh-keygen
require_cmd docker

cleanup() {
  rm -rf "$SSH_KEYS_STAGE_DIR"
}
trap cleanup EXIT

docker volume inspect "$SSH_KEYS_VOLUME_NAME" >/dev/null 2>&1 || docker volume create "$SSH_KEYS_VOLUME_NAME" >/dev/null
mkdir -p "$SSH_CFG_DIR"

create_keypair_if_missing() {
  local key_type="$1"
  local key_file="$2"
  local extra_opts=()

  if [[ "$key_type" == "rsa" ]]; then
    extra_opts=(-b 4096)
  fi

  if [[ -f "$key_file" && -f "$key_file.pub" ]]; then
    log "EXISTE: $(basename "$key_file")"
    return 0
  fi

  ssh-keygen -q -t "$key_type" "${extra_opts[@]}" -N "" -f "$key_file"
  log "CREADA: $(basename "$key_file")"
  # show fingerprint if public created
  if [[ -f "$key_file.pub" ]]; then
    fp="$(ssh-keygen -lf "$key_file.pub" 2>/dev/null || true)"
    [[ -n "$fp" ]] && log "Fingerprint $(basename "$key_file.pub"): $fp"
  fi
}

create_keypair_if_missing rsa "$SSH_KEYS_STAGE_DIR/ssh_host_rsa_key"
create_keypair_if_missing ecdsa "$SSH_KEYS_STAGE_DIR/ssh_host_ecdsa_key"
create_keypair_if_missing ed25519 "$SSH_KEYS_STAGE_DIR/ssh_host_ed25519_key"

log "Sincronizando host keys hacia el volumen Docker: $SSH_KEYS_VOLUME_NAME"
docker run --rm \
  -v "$SSH_KEYS_VOLUME_NAME:/target" \
  -v "$SSH_KEYS_STAGE_DIR:/source:ro" \
  alpine:3.20 sh -c '
    set -e
    cp -n /source/ssh_host_* /target/ 2>/dev/null || true
    chmod 600 /target/ssh_host_*_key 2>/dev/null || true
    chmod 644 /target/ssh_host_*_key.pub 2>/dev/null || true
  ' >/dev/null

log "Host keys disponibles en el volumen: $SSH_KEYS_VOLUME_NAME"

if [[ -f "$AUTH_KEYS_EXAMPLE" ]]; then
  if [[ -f "$AUTH_KEYS_TARGET" ]]; then
    log "EXISTE: $(basename "$AUTH_KEYS_TARGET"); no se sobreescribe"
  else
    cp -f "$AUTH_KEYS_EXAMPLE" "$AUTH_KEYS_TARGET"
    log "CREADO: $(basename "$AUTH_KEYS_EXAMPLE") -> $(basename "$AUTH_KEYS_TARGET")"
  fi
fi

log "Listo. Secretos SSH preparados en el volumen: $SSH_KEYS_VOLUME_NAME"

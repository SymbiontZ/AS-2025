#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/stacks/development/compose.yml"
USERS_CONF="$ROOT_DIR/stacks/development/ssh-2fa/users.conf"
SERVICE_NAME="ssh_2fa"
CONTAINER_NAME="dev_ssh_2fa"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/create-ssh-2fa-user.sh <usuario> <password>

Ejemplo:
  ./scripts/create-ssh-2fa-user.sh Developer123 "ClaveSegura2026!"

Que hace:
  1) Agrega usuario:password en stacks/development/ssh-2fa/users.conf.
  2) Reinicia el servicio ssh_2fa.
  3) Verifica que el usuario exista en el contenedor.
  4) Muestra el secreto TOTP para enrolar en Google Authenticator.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontro el comando requerido: $1"
}

validate_username() {
  local username="$1"
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || {
    die "Usuario invalido. Usa: letras minusculas, numeros, '_' o '-', max 32 chars, empezando por letra o '_'"
  }
}

validate_password() {
  local password="$1"
  [[ -n "$password" ]] || die "La password no puede ser vacia"
  [[ "$password" != *:* ]] || die "La password no puede contener ':' (formato users.conf: usuario:password)"
  [[ "$password" != *$'\n'* ]] || die "La password no puede contener saltos de linea"
}

normalize_users_conf_newline() {
  local tmp
  tmp="$(mktemp)"
  awk '1' "$USERS_CONF" > "$tmp"
  mv "$tmp" "$USERS_CONF"
}

append_user() {
  local username="$1"
  local password="$2"

  if grep -qE "^${username}:" "$USERS_CONF"; then
    die "El usuario '$username' ya existe en $USERS_CONF"
  fi

  normalize_users_conf_newline
  printf '%s:%s\n' "$username" "$password" >> "$USERS_CONF"
}

restart_service() {
  local output

  # Prefer recreate over restart to ensure entrypoint re-processes users.conf.
  if output="$(docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate "$SERVICE_NAME" 2>&1)"; then
    return 0
  fi

  # Docker Desktop + WSL may fail with bind-mount metadata collisions on restart/recreate.
  if grep -qiE 'docker-desktop-bind-mounts|file exists' <<<"$output"; then
    log "WARN: fallo de montaje detectado; aplicando recuperacion del servicio"
    docker compose -f "$COMPOSE_FILE" stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    docker compose -f "$COMPOSE_FILE" rm -sf "$SERVICE_NAME" >/dev/null 2>&1 || true
    docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate "$SERVICE_NAME" >/dev/null
    return 0
  fi

  log "$output"
  die "No se pudo recrear el servicio $SERVICE_NAME"
}

wait_container_running() {
  local tries=20
  local running
  while ((tries > 0)); do
    running="$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)"
    if [[ "$running" == "true" ]]; then
      return 0
    fi
    tries=$((tries - 1))
    sleep 1
  done

  die "El contenedor $CONTAINER_NAME no quedo en estado running"
}

verify_user_and_print_secret() {
  local username="$1"
  local tries=30

  while ((tries > 0)); do
    if docker exec "$CONTAINER_NAME" sh -lc "getent passwd '$username' >/dev/null" >/dev/null 2>&1; then
      break
    fi
    tries=$((tries - 1))
    sleep 1
  done

  if ((tries == 0)); then
    die "El usuario '$username' no fue creado dentro del contenedor"
  fi

  local secret
  tries=30
  while ((tries > 0)); do
    secret="$(docker exec "$CONTAINER_NAME" sh -lc "head -n 1 '/home/$username/.google_authenticator'" 2>/dev/null || true)"
    [[ -n "$secret" ]] && break
    tries=$((tries - 1))
    sleep 1
  done
  [[ -n "$secret" ]] || die "No se encontro el secreto TOTP para '$username'"

  log "Cuenta creada correctamente"
  log " - Usuario: $username"
  log " - SSH: ssh -p 2223 $username@localhost"
  log " - Secreto TOTP: $secret"
}

main() {
  local username="${1:-}"
  local password="${2:-}"

  [[ -n "$username" && -n "$password" ]] || { usage; exit 1; }

  require_cmd docker
  require_cmd awk
  require_cmd grep

  [[ -f "$COMPOSE_FILE" ]] || die "No existe $COMPOSE_FILE"
  [[ -f "$USERS_CONF" ]] || die "No existe $USERS_CONF"

  validate_username "$username"
  validate_password "$password"

  append_user "$username" "$password"
  restart_service
  wait_container_running
  verify_user_and_print_secret "$username"
}

main "$@"

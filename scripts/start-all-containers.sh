#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontro el comando requerido: $1"
}

require_cmd docker

# En Linux moderno, 'docker compose' viene como plugin.
docker compose version >/dev/null 2>&1 || die "No se pudo ejecutar 'docker compose'."

create_networks_if_needed() {
  local script="$ROOT_DIR/scripts/create-docker-networks.sh"
  if [[ -x "$script" ]]; then
    log "==> Verificando/creando redes Docker"
    "$script"
    return
  fi

  if [[ -f "$script" ]]; then
    log "==> Verificando/creando redes Docker"
    bash "$script"
    return
  fi

  die "No se encontro $script"
}

up_stack() {
  local compose_file="$1"
  local stack_name
  local config_output
  stack_name="$(basename "$(dirname "$compose_file")")"
  [[ -f "$compose_file" ]] || die "No existe compose: $compose_file"

  # Capturamos la salida de validacion para reportar la causa real si falla.
  config_output="$(docker compose -f "$compose_file" config 2>&1)" || {
    log "==> WARN: compose invalido o incompleto en $stack_name, se omite"
    while IFS= read -r line; do
      [[ -n "$line" ]] && log "   - $line"
    done <<< "$config_output"
    return 0
  }

  log "==> Levantando $stack_name"
  docker compose -f "$compose_file" up -d
}

is_container_running() {
  local container_name="$1"
  local state

  state="$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || true)"
  [[ "$state" == "running" ]]
}

main() {
  create_networks_if_needed

  # Orden recomendado: primero firewall/router y luego servicios.
  up_stack "$ROOT_DIR/stacks/network/compose.yml"
  up_stack "$ROOT_DIR/stacks/services/compose.yml"
  up_stack "$ROOT_DIR/stacks/development/compose.yml"
  up_stack "$ROOT_DIR/stacks/production/compose.yml"

  if is_container_running "pfsense-fw"; then
    up_stack "$ROOT_DIR/stacks/vpn/compose.yml"
  else
    log "==> WARN: pfsense-fw no esta en estado running; se omite stack vpn"
  fi

  log ""
  log "Listo. Estado de contenedores:"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Networks}}"
}

main "$@"

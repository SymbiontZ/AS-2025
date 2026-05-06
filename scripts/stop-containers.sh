#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
info() { log "[INFO] $*"; }
warn() { log "[WARN] $*"; }
ok() { log "[ OK ] $*"; }
die() { log "[FAIL] $*"; exit 1; }

hr() { log "------------------------------------------------------------"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontro el comando requerido: $1"
}

main() {
  hr
  info "Detener contenedores Docker"
  hr

  require_cmd docker

  local -a running_ids=()
  local -a running_names=()

  mapfile -t running_ids < <(docker ps -q)
  mapfile -t running_names < <(docker ps --format '{{.Names}}')

  if [[ "${#running_ids[@]}" -eq 0 ]]; then
    warn "No hay contenedores en ejecucion para detener."
    exit 0
  fi

  info "Contenedores en ejecucion: ${#running_ids[@]}"
  for name in "${running_names[@]}"; do
    log "  - $name"
  done

  info "Deteniendo contenedores..."
  docker stop "${running_ids[@]}" >/dev/null

  ok "Se detuvieron ${#running_ids[@]} contenedores."
  hr

  info "Estado actual:"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Networks}}"
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontró el comando requerido: $1"
}

require_cmd docker

# Define redes en formato: nombre[:subnet]
# - Sin subnet: Docker asigna una automáticamente.
# - Con subnet: evita solapamientos (ej. 172.30.10.0/24)
#
# Personaliza de 2 formas:
# 1) Edita NETWORK_SPECS aquí.
# 2) O pásalo por variable de entorno, separando por espacios:
#    NETWORK_SPECS_ENV='dev_net:172.30.10.0/24 prod_net:172.30.20.0/24' ./scripts/create-docker-networks.sh
NETWORK_SPECS_DEFAULT=(
  "development_net:172.40.0.0/24"
  "services_net:172.20.0.0/24"
  "production_net:172.30.0.0/24"
  "vpn_net:172.10.0.0/24"
)

# shellcheck disable=SC2206
NETWORK_SPECS=( ${NETWORK_SPECS_ENV:-} )
if [[ ${#NETWORK_SPECS[@]} -eq 0 ]]; then
  NETWORK_SPECS=("${NETWORK_SPECS_DEFAULT[@]}")
fi

create_network_if_missing() {
  local name="$1"
  local subnet="${2:-}"

  if docker network inspect "$name" >/dev/null 2>&1; then
    log "==> Red existe: $name"
    return 0
  fi

  log "==> Creando red: $name"
  if [[ -n "$subnet" ]]; then
    docker network create --driver bridge --subnet "$subnet" "$name" >/dev/null
  else
    docker network create --driver bridge "$name" >/dev/null
  fi
}

for spec in "${NETWORK_SPECS[@]}"; do
  name="${spec%%:*}"
  subnet="${spec#*:}"
  if [[ -z "$name" ]]; then
    die "Spec inválido (nombre vacío): '$spec'"
  fi
  if [[ "$name" == "$subnet" ]]; then
    subnet=""
  fi

  create_network_if_missing "$name" "$subnet"
done

log "Listo. Redes creadas (o ya existían)."
log "Haz docker network ls para mirar las redes"
#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

print_header() {
  log ""
  log "=============================================="
  log " Inicializacion de Redes Docker"
  log "=============================================="
}

print_row() {
  local status="$1"
  local name="$2"
  local subnet="$3"
  printf '%-10s | %-18s | %s\n' "$status" "$name" "$subnet" >&2
}

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

created_count=0
existing_count=0

create_network_if_missing() {
  local name="$1"
  local subnet="${2:-}"
  local subnet_show="${subnet:-automatica}"

  if docker network inspect "$name" >/dev/null 2>&1; then
    print_row "EXISTE" "$name" "$subnet_show"
    ((existing_count+=1))
    return 0
  fi

  if [[ -n "$subnet" ]]; then
    docker network create --driver bridge --subnet "$subnet" "$name" >/dev/null
  else
    docker network create --driver bridge "$name" >/dev/null
  fi

  print_row "CREADA" "$name" "$subnet_show"
  ((created_count+=1))
}

print_header
log "Estado     | Red                | Subred"
log "-----------+--------------------+----------------"

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

log "-----------+--------------------+----------------"
log "Resumen: creadas=$created_count, existentes=$existing_count, total=${#NETWORK_SPECS[@]}"
log "Listo. Puedes verificar con: docker network ls"
#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
info() { log "[INFO] $*"; }
warn() { log "[WARN] $*"; }
ok() { log "[ OK ] $*"; }
die() { log "[FAIL] $*"; exit 1; }

hr() { log "------------------------------------------------------------"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_OUT="$ROOT_DIR/stacks/services/dns/rndc.key"
DEFAULT_KEY_NAME="rndc-key"
DEFAULT_ALGORITHM="hmac-sha256"
DEFAULT_BITS="256"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontro el comando requerido: $1"
}

usage() {
  cat <<EOF
Uso:
  $(basename "$0") [--show-key] [archivo_salida] [nombre_clave]

Ejemplos:
  $(basename "$0")
  $(basename "$0") --show-key
  $(basename "$0") "$ROOT_DIR/stacks/services/dns/rndc.key"
  $(basename "$0") "$ROOT_DIR/stacks/services/dns/rndc.key" "rndc-key"
EOF
}

backup_if_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    cp -f "$file" "${file}.bak.${ts}"
    warn "Se creo respaldo: ${file}.bak.${ts}"
  fi
}

generate_with_rndc_confgen() {
  local output_file="$1"
  local key_name="$2"
  local algorithm="$3"
  local bits="$4"

  rndc-confgen -a -A "$algorithm" -b "$bits" -k "$key_name" -c "$output_file" >/dev/null
}

generate_with_openssl() {
  local output_file="$1"
  local key_name="$2"
  local algorithm="$3"
  local bits="$4"
  local bytes
  local secret

  if (( bits % 8 != 0 )); then
    die "El tamano en bits debe ser multiplo de 8 para fallback openssl"
  fi

  bytes=$((bits / 8))
  secret="$(openssl rand -base64 "$bytes")"

  cat >"$output_file" <<EOF
key "$key_name" {
    algorithm $algorithm;
    secret "$secret";
};
EOF
}

main() {
  local show_key="false"

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  if [[ "${1:-}" == "--show-key" ]]; then
    show_key="true"
    shift
  fi

  local output_file="${1:-$DEFAULT_OUT}"
  local key_name="${2:-$DEFAULT_KEY_NAME}"

  hr
  info "Generar clave RNDC"
  hr
  info "Salida: $output_file"
  info "Key name: $key_name"
  info "Algoritmo: $DEFAULT_ALGORITHM"
  info "Bits: $DEFAULT_BITS"

  mkdir -p "$(dirname "$output_file")"
  backup_if_exists "$output_file"

  if command -v rndc-confgen >/dev/null 2>&1; then
    info "Generando con rndc-confgen"
    generate_with_rndc_confgen "$output_file" "$key_name" "$DEFAULT_ALGORITHM" "$DEFAULT_BITS"
  else
    warn "No se encontro rndc-confgen; usando fallback con openssl"
    require_cmd openssl
    generate_with_openssl "$output_file" "$key_name" "$DEFAULT_ALGORITHM" "$DEFAULT_BITS"
  fi

  chmod 600 "$output_file" || warn "No se pudo ajustar permisos a 600"

  ok "Clave generada correctamente"
  hr
  info "Archivo generado: $output_file"
  if [[ "$show_key" == "true" ]]; then
    warn "Mostrando clave en salida por solicitud explicita (--show-key)"
    cat "$output_file"
  fi
}

main "$@"
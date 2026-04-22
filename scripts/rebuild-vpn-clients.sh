#!/usr/bin/env bash
set -euo pipefail

# Imprime mensajes de estado por stderr.
log() { printf '%s\n' "$*" >&2; }
# Imprime error y termina la ejecucion.
die() { log "ERROR: $*"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VPN_STACK_DIR="$ROOT_DIR/stacks/vpn"
VPN_CFG_DIR="$VPN_STACK_DIR/vpn-config"
WG_CONF="$VPN_CFG_DIR/wg_confs/wg0.conf"
SERVER_PUBKEY_FILE="$VPN_CFG_DIR/server/publickey-server"
PROFILES_DIR="$VPN_CFG_DIR/profiles"
VPN_ENV_FILE="$VPN_STACK_DIR/.env"

# Verifica que un comando exista en el sistema.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontro el comando requerido: $1"
}

# Levanta el contenedor VPN si no esta en ejecucion.
ensure_vpn_container_running() {
  local running
  running="$(docker inspect -f '{{.State.Running}}' vpn_server 2>/dev/null || true)"
  if [[ "$running" != "true" ]]; then
    log "==> Iniciando vpn_server"
    docker compose -f "$VPN_STACK_DIR/compose.yml" up -d vpn_server >/dev/null
  fi
}

# Genera clave privada WireGuard.
gen_private_key() {
  docker exec vpn_server sh -lc "wg genkey"
}

# Deriva clave publica desde una privada.
gen_public_key() {
  local private_key="$1"
  printf '%s' "$private_key" | docker exec -i vpn_server sh -lc "wg pubkey"
}

# Genera clave precompartida (PSK).
gen_psk() {
  docker exec vpn_server sh -lc "wg genpsk"
}

# Escribe el perfil cliente en formato WireGuard.
render_profile() {
  local profile_path="$1"
  local client_ip="$2"
  local client_privkey="$3"
  local psk="$4"
  local allowed_ips="$5"
  local dns_server="$6"
  local server_pubkey="$7"
  local endpoint_host="$8"
  local endpoint_port="$9"

  {
    printf '[Interface]\n'
    printf 'Address = %s\n' "$client_ip"
    printf 'PrivateKey = %s\n' "$client_privkey"
    if [[ -n "$dns_server" ]]; then
      printf 'DNS = %s\n' "$dns_server"
    fi
    printf '\n'
    printf '[Peer]\n'
    printf 'PublicKey = %s\n' "$server_pubkey"
    printf 'PresharedKey = %s\n' "$psk"
    printf 'Endpoint = %s:%s\n' "$endpoint_host" "$endpoint_port"
    printf 'AllowedIPs = %s\n' "$allowed_ips"
  } > "$profile_path"

  chmod 600 "$profile_path"
}

# Agrega un bloque [Peer] al wg0 del servidor.
append_peer_block() {
  local name="$1"
  local pubkey="$2"
  local psk="$3"
  local client_ip_cidr="$4"

  {
    printf '\n[Peer]\n'
    printf '# %s\n' "$name"
    printf 'PublicKey = %s\n' "$pubkey"
    printf 'PresharedKey = %s\n' "$psk"
    printf 'AllowedIPs = %s\n' "$client_ip_cidr"
    printf 'PersistentKeepalive = 25\n'
  } >> "$WG_CONF"
}

# Orquesta regeneracion de perfiles y peers.
main() {
  require_cmd docker

  [[ -f "$WG_CONF" ]] || die "No existe $WG_CONF"
  [[ -f "$SERVER_PUBKEY_FILE" ]] || die "No existe $SERVER_PUBKEY_FILE"

  mkdir -p "$PROFILES_DIR"

  ensure_vpn_container_running

  local server_pubkey
  server_pubkey="$(<"$SERVER_PUBKEY_FILE")"
  local endpoint_host="vpn.empresa.local"
  local endpoint_port="51820"

  if [[ -f "$VPN_ENV_FILE" ]]; then
    # Carga variables de endpoint desde .env si existe.
    # shellcheck disable=SC1090
    set -a; source "$VPN_ENV_FILE"; set +a
    endpoint_host="${SERVERURL:-$endpoint_host}"
    endpoint_port="${SERVERPORT:-$endpoint_port}"
  fi

  local tmp_header
  tmp_header="$(mktemp)"
  awk '/^\[Peer\]/{exit} {print}' "$WG_CONF" > "$tmp_header"
  cp "$WG_CONF" "$WG_CONF.bak.$(date +%Y%m%d%H%M%S)"
  cat "$tmp_header" > "$WG_CONF"
  rm -f "$tmp_header"

  # Genera llaves nuevas para cada cliente.
  local dev_priv dev_pub dev_psk
  local svc_priv svc_pub svc_psk

  dev_priv="$(gen_private_key)"
  dev_pub="$(gen_public_key "$dev_priv")"
  dev_psk="$(gen_psk)"

  svc_priv="$(gen_private_key)"
  svc_pub="$(gen_public_key "$svc_priv")"
  svc_psk="$(gen_psk)"

  # Regenera perfiles cliente con sus rutas permitidas.
  render_profile \
    "$PROFILES_DIR/dev_user.conf" \
    "172.10.0.100" \
    "$dev_priv" \
    "$dev_psk" \
    "172.40.0.0/24" \
    "" \
    "$server_pubkey" \
    "$endpoint_host" \
    "$endpoint_port"

  render_profile \
    "$PROFILES_DIR/svc_prod_user.conf" \
    "172.10.0.101" \
    "$svc_priv" \
    "$svc_psk" \
    "172.20.0.0/24,172.30.0.0/24" \
    "172.20.0.10" \
    "$server_pubkey" \
    "$endpoint_host" \
    "$endpoint_port"

  # Registra peers en el servidor WireGuard.
  append_peer_block "dev_user" "$dev_pub" "$dev_psk" "172.10.0.100/32"
  append_peer_block "svc_prod_user" "$svc_pub" "$svc_psk" "172.10.0.101/32"

  log "==> Reaplicando configuracion VPN"
  docker compose -f "$VPN_STACK_DIR/compose.yml" up -d --force-recreate vpn_server >/dev/null

  log "Listo. Perfiles regenerados:"
  log " - $PROFILES_DIR/dev_user.conf"
  log " - $PROFILES_DIR/svc_prod_user.conf"
}

main "$@"

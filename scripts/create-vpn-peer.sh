#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VPN_STACK_DIR="$ROOT_DIR/stacks/vpn"
VPN_CFG_DIR="$VPN_STACK_DIR/vpn-config"
WG_CONF="$VPN_CFG_DIR/wg_confs/wg0.conf"
SERVER_PUBKEY_FILE="$VPN_CFG_DIR/server/publickey-server"
PROFILES_DIR="$VPN_CFG_DIR/profiles"
VPN_ENV_FILE="$VPN_STACK_DIR/.env"

VPN_PREFIX="172.10.0"
IP_START=100
IP_END=200

usage() {
  cat <<'EOF'
Uso:
  ./scripts/create-vpn-peer.sh <peer_name> [client_dns]

Ejemplos:
  ./scripts/create-vpn-peer.sh qa_user
  ./scripts/create-vpn-peer.sh ext_user "172.20.0.10"
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontro el comando requerido: $1"
}

ensure_vpn_container_running() {
  local running
  running="$(docker inspect -f '{{.State.Running}}' vpn_server 2>/dev/null || true)"
  if [[ "$running" != "true" ]]; then
    log "==> Arrancando vpn_server"
    docker compose -f "$VPN_STACK_DIR/compose.yml" up -d vpn_server >/dev/null
  fi
}

sanitize_peer_name() {
  local raw_name="$1"
  if [[ ! "$raw_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    die "peer_name solo puede contener letras, numeros, guion y guion bajo"
  fi
  printf '%s' "$raw_name"
}

next_free_ip() {
  local octet
  local -A used=()

  while IFS= read -r octet; do
    [[ -n "$octet" ]] && used["$octet"]=1
  done < <(
    grep -Eo "${VPN_PREFIX}\\.[0-9]{1,3}/32" "$WG_CONF" \
      | sed -E "s#${VPN_PREFIX}\\.([0-9]{1,3})/32#\\1#" \
      | sort -n -u || true
  )

  for ((octet=IP_START; octet<=IP_END; octet++)); do
    if [[ -z "${used[$octet]+x}" ]]; then
      printf '%s.%s' "$VPN_PREFIX" "$octet"
      return 0
    fi
  done

  return 1
}

gen_private_key() {
  docker exec vpn_server sh -lc "wg genkey"
}

gen_public_key() {
  local private_key="$1"
  printf '%s' "$private_key" | docker exec -i vpn_server sh -lc "wg pubkey"
}

gen_psk() {
  docker exec vpn_server sh -lc "wg genpsk"
}

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
    printf 'PersistentKeepalive = 25\n'
  } > "$profile_path"

  chmod 600 "$profile_path"
}

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

main() {
  require_cmd docker
  require_cmd grep
  require_cmd sed

  local peer_name="${1:-}"
  [[ -n "$peer_name" ]] || { usage; die "Debes indicar <peer_name>"; }
  peer_name="$(sanitize_peer_name "$peer_name")"

  [[ -f "$WG_CONF" ]] || die "No existe $WG_CONF"
  [[ -f "$SERVER_PUBKEY_FILE" ]] || die "No existe $SERVER_PUBKEY_FILE"

  mkdir -p "$PROFILES_DIR"

  local profile_path="$PROFILES_DIR/${peer_name}.conf"
  [[ ! -f "$profile_path" ]] || die "Ya existe el perfil: $profile_path"

  ensure_vpn_container_running

  local server_pubkey
  server_pubkey="$(<"$SERVER_PUBKEY_FILE")"

  local endpoint_host="vpn.empresa.local"
  local endpoint_port="51820"
  local client_allowed_ips="172.10.0.0/24"
  local client_dns="172.20.0.10"

  if [[ -f "$VPN_ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$VPN_ENV_FILE"; set +a
    endpoint_host="${SERVERURL:-$endpoint_host}"
    endpoint_port="${SERVERPORT:-$endpoint_port}"
    client_dns="${PEERDNS:-$client_dns}"
  fi

  if [[ -n "${2:-}" ]]; then
    client_dns="$2"
  fi

  local client_ip
  client_ip="$(next_free_ip)" || die "No hay IPs disponibles entre ${VPN_PREFIX}.${IP_START} y ${VPN_PREFIX}.${IP_END}"

  local client_priv client_pub client_psk
  client_priv="$(gen_private_key)"
  client_pub="$(gen_public_key "$client_priv")"
  client_psk="$(gen_psk)"

  render_profile \
    "$profile_path" \
    "$client_ip" \
    "$client_priv" \
    "$client_psk" \
    "$client_allowed_ips" \
    "$client_dns" \
    "$server_pubkey" \
    "$endpoint_host" \
    "$endpoint_port"

  append_peer_block "$peer_name" "$client_pub" "$client_psk" "${client_ip}/32"

  log "==> Reaplicando configuracion VPN"
  docker compose -f "$VPN_STACK_DIR/compose.yml" up -d --force-recreate vpn_server >/dev/null

  log "Listo. Peer creado"
  log " - Nombre: $peer_name"
  log " - IP asignada: $client_ip"
  log " - Perfil: $profile_path"
}

main "$@"

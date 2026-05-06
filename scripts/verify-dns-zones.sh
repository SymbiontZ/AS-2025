#!/usr/bin/env bash
set -u

# Verify forward and reverse DNS zones for AS-2025 from the host terminal.
# Usage examples:
#   ./scripts/verify-dns-zones.sh
#   DNS_SERVER=127.0.0.1 DNS_PORT=1053 ./scripts/verify-dns-zones.sh
#   DNS_SERVER=172.20.0.10 DNS_PORT=53 ./scripts/verify-dns-zones.sh   # desde un contenedor en services_net
# Requires: dig (dnsutils / bind9-dnsutils package)

DNS_SERVER="${DNS_SERVER:-127.0.0.1}"
DNS_PORT="${DNS_PORT:-1053}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-2}"
FORWARD_CHECKS=(
  "dns.empresa.local:A:172.20.0.10"
  "nas.empresa.local:A:172.20.0.11"
  "prod-web.empresa.local:A:172.30.0.10"
  "prod-postgres.empresa.local:A:172.30.0.20"
  "dev-web.empresa.local:A:172.40.0.10"
  "dev-mysql.empresa.local:A:172.40.0.20"
)

REVERSE_CHECKS=(
  "172.20.0.10:dns.empresa.local."
  "172.20.0.11:nas.empresa.local."
  "172.30.0.10:prod-web.empresa.local."
  "172.30.0.20:prod-postgres.empresa.local."
  "172.40.0.10:dev-web.empresa.local."
  "172.40.0.20:dev-mysql.empresa.local."
)

has_command() {
  command -v "$1" >/dev/null 2>&1
}

run_dig() {
  local qname="$1"
  local qtype="$2"

  dig +short +time="$TIMEOUT_SECONDS" +tries=1 @"$DNS_SERVER" -p "$DNS_PORT" "$qname" "$qtype" 2>/dev/null
}

run_dig_reverse() {
  local ip="$1"

  dig +short +time="$TIMEOUT_SECONDS" +tries=1 @"$DNS_SERVER" -p "$DNS_PORT" -x "$ip" 2>/dev/null
}

verify_forward() {
  local host="$1"
  local record_type="$2"
  local expected_ip="$3"

  local answer
  answer="$(run_dig "$host" "$record_type" | sed '/^[[:space:]]*$/d')"

  if printf '%s\n' "$answer" | grep -Fxq "$expected_ip"; then
    echo "[OK] ${host} -> ${expected_ip}"
    return 0
  fi

  if [ -z "$answer" ]; then
    echo "[ERROR] ${host} -> expected ${expected_ip}, got <empty>"
  else
    echo "[FAIL] ${host} -> expected ${expected_ip}, got: ${answer}"
  fi
  return 1
}

verify_reverse() {
  local ip="$1"
  local expected_fqdn="$2"

  local answer
  answer="$(run_dig_reverse "$ip" | sed '/^[[:space:]]*$/d')"

  if printf '%s\n' "$answer" | grep -Fxq "$expected_fqdn"; then
    echo "[OK] ${ip} -> ${expected_fqdn}"
    return 0
  fi

  if [ -z "$answer" ]; then
    echo "[ERROR] ${ip} -> esperado ${expected_fqdn}, obtenido <vacío>"
  else
    echo "[ERROR] ${ip} -> esperado ${expected_fqdn}, obtenido: ${answer}"
  fi
  return 1
}

main() {
  local failures=0

  if ! has_command dig; then
    echo "ERROR: 'dig' no esta instalado en el host." >&2
    echo "Instala dnsutils (Debian/Ubuntu) o bind9-dnsutils y vuelve a ejecutar." >&2
    exit 127
  fi

  echo "Testing DNS server ${DNS_SERVER}:${DNS_PORT}"
  echo ""
  echo "== Forward checks (A) =="
  local item host record_type expected_ip
  for item in "${FORWARD_CHECKS[@]}"; do
    IFS=':' read -r host record_type expected_ip <<< "$item"
    if ! verify_forward "$host" "$record_type" "$expected_ip"; then
      failures=$((failures + 1))
    fi
  done

  echo ""
  echo "== Reverse checks (PTR) =="
  local ip expected_fqdn
  for item in "${REVERSE_CHECKS[@]}"; do
    IFS=':' read -r ip expected_fqdn <<< "$item"
    if ! verify_reverse "$ip" "$expected_fqdn"; then
      failures=$((failures + 1))
    fi
  done

  echo ""
  echo "== Summary =="
  if [ "$failures" -eq 0 ]; then
    echo "All DNS zone checks passed."
    exit 0
  fi

  echo "DNS checks failed: ${failures}"
  exit 1
}

main

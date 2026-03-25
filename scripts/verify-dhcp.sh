#!/usr/bin/env bash
set -u

# Verifica DHCP en redes Docker con timeout corto usando udhcpc.
# Uso:
#   ./scripts/verify-dhcp.sh
#   ./scripts/verify-dhcp.sh services_net production_net

DEFAULT_NETWORKS=(
  "services_net"
  "vpn_net"
  "production_net"
  "development_net"
)

if [ "$#" -gt 0 ]; then
  NETWORKS=("$@")
else
  NETWORKS=("${DEFAULT_NETWORKS[@]}")
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker no esta disponible en PATH"
  exit 1
fi

action_test_network() {
  local net="$1"

  if ! docker network inspect "$net" >/dev/null 2>&1; then
    echo "[$net] ERROR: la red no existe"
    return 2
  fi

  local output
  output=$(docker run --rm \
    --network "$net" \
    --cap-add NET_ADMIN \
    alpine sh -lc "apk add --no-cache busybox-extras >/dev/null; ip addr flush dev eth0; udhcpc -i eth0 -n -q -t 4 -T 3; ip -4 -o addr show dev eth0" 2>&1)
  local rc=$?

  if [ "$rc" -eq 0 ]; then
    local ip
    ip=$(printf '%s\n' "$output" | awk '/inet / {print $4}' | head -n1)
    if [ -n "$ip" ]; then
      echo "[$net] OK: lease obtenido -> $ip"
    else
      echo "[$net] OK: lease obtenido (sin parsear IP)"
    fi
    return 0
  fi

  echo "[$net] ERROR: no se obtuvo lease DHCP"
  printf '%s\n' "$output" | tail -n 8
  return 1
}

failures=0

for net in "${NETWORKS[@]}"; do
  echo ""
  echo "===== Test DHCP en $net ====="
  if ! action_test_network "$net"; then
    failures=$((failures + 1))
  fi
done

echo ""
echo "===== Resumen ====="
if [ "$failures" -eq 0 ]; then
  echo "Todo OK: DHCP responde en todas las redes probadas."
  exit 0
fi

echo "Fallos: $failures red(es) con error DHCP."
exit 1

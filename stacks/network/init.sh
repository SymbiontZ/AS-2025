#!/bin/bash

apt-get update && apt-get install -y iptables iproute2 dnsmasq

# activar routing
sysctl -w net.ipv4.ip_forward=1

# aplicar reglas
sed 's/\r$//' /iptables.rules | iptables-restore

# lanzar dnsmasq en primer plano usando la config de DHCP
exec dnsmasq -k --conf-file=/etc/dnsmasq.d/dhcp.conf
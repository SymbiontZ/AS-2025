#!/bin/bash
# Reglas para Usuario Desarrollador (.100) -> Solo a Development (172.40.0.0/24)
docker exec pfsense-fw iptables -A FORWARD -s 172.10.0.100 -d 172.40.0.0/24 -j ACCEPT
docker exec pfsense-fw iptables -A FORWARD -d 172.10.0.100 -s 172.40.0.0/24 -j ACCEPT

# Reglas para Usuario Admin (.101) -> A Services (172.20.0.0/24) y Production (172.30.0.0/24)
docker exec pfsense-fw iptables -A FORWARD -s 172.10.0.101 -d 172.20.0.0/24 -j ACCEPT
docker exec pfsense-fw iptables -A FORWARD -d 172.10.0.101 -s 172.20.0.0/24 -j ACCEPT
docker exec pfsense-fw iptables -A FORWARD -s 172.10.0.101 -d 172.30.0.0/24 -j ACCEPT
docker exec pfsense-fw iptables -A FORWARD -d 172.10.0.101 -s 172.30.0.0/24 -j ACCEPT

# Bloqueo explícito para dev_user hacia Production y Services
docker exec pfsense-fw iptables -A FORWARD -s 172.10.0.100 -d 172.30.0.0/24 -j DROP
docker exec pfsense-fw iptables -A FORWARD -s 172.10.0.100 -d 172.20.0.0/24 -j DROP

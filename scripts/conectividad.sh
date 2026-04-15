#!/bin/bash

echo "VERIFICACION SSH Y CONECTIVIDAD"
echo ""

# 1. Estado del servicio SSH
echo "[1] Estado del servicio SSHD:"
if systemctl is-active --quiet ssh; then
    echo "Estado: Activo (Running)"
else
    echo "Estado: Inactivo o no instalado"
fi
echo ""

# 2. Verificacion de Localhost
echo "[2] Prueba de conexion Localhost (Puerto 22):"
if nc -zv 127.0.0.1 22 > /dev/null 2>&1; then
    echo "Resultado: Localhost respondiendo en puerto 22"
else
    echo "Resultado: Error de conexion en Localhost"
fi
echo ""

# 3. Datos para la conexion LAN
echo "[3] Datos para verificacion LAN:"
IP_LAN=$(hostname -I | awk '{print $1}')
echo "Direccion IP Privada: $IP_LAN"
echo "Comando de acceso sugerido: ssh $(whoami)@$IP_LAN"
echo ""

# 4. Verificacion de Docker
echo "[4] Estado de Docker:"
if docker ps > /dev/null 2>&1; then
    echo "Estado: Docker Daemon operativo"
else
    echo "Estado: Docker no responde o requiere permisos"
fi
echo ""

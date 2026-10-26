#!/usr/bin/env bash
# ============================================================
# practicar-dhcp.sh  -  practicar un ejercicio de DHCP (parcial 2025 2C Ej I, simulacro Ej 4)
#                        en ESTA VM sin tocar la red real (enp0s8 / NAT).
#
# Arma un "cable" virtual (par veth):  veth-srv (el server) <--> veth-cli (el cliente)
# A veth-srv le pone la IP de "option routers" de la config (o la .1 de la subnet), así dhcpd
# tiene una IP en la red que reparte. Levanta dhcpd SÓLO en veth-srv y simula clientes con
# nmap --script broadcast-dhcp-discover (el comando que daba el enunciado): una MAC
# cualquiera y cada MAC de los "hardware ethernet" de la config.
#
# Uso:  ~/Protos/scripts/practicar-dhcp.sh [archivo.conf]
#       (por defecto: ~/Protos/ejercicios/parciales/2025-2c-ej1-dhcpd.conf)
#       Simulacro:  ~/Protos/scripts/practicar-dhcp.sh ~/Protos/ejercicios/simulacro/ej4-dhcpd.conf
#       Editá la config, volvé a correr el script y mirá qué ofrece el server.
# Al terminar desarma todo (veth, dhcpd, archivos temporales).
# ============================================================
set -euo pipefail

CONF="${1:-$HOME/Protos/ejercicios/parciales/2025-2c-ej1-dhcpd.conf}"
TMPCONF=/etc/dhcp/dhcpd-practica.conf            # AppArmor sólo deja a dhcpd leer /etc/dhcp/
LEASES=/var/lib/dhcp/dhcpd.leases-practica

mascara_a_prefijo() {   # 255.255.255.0 -> 24
    local bits=0 o
    for o in ${1//./ }; do
        case $o in 255) bits=$((bits+8));; 254) bits=$((bits+7));; 252) bits=$((bits+6));; 248) bits=$((bits+5));;
                   240) bits=$((bits+4));; 224) bits=$((bits+3));; 192) bits=$((bits+2));; 128) bits=$((bits+1));; esac
    done
    echo "$bits"
}

# Datos que salen de la config
read -r RED MASCARA < <(grep -oE 'subnet [0-9.]+ netmask [0-9.]+' "$CONF" | head -1 | awk '{print $2, $4}') \
    || { echo "No encontré 'subnet X netmask Y' en $CONF"; exit 1; }
SRVIP=$(grep -oE 'option routers [0-9.]+' "$CONF" | head -1 | awk '{print $3}' || true)
SRVIP="${SRVIP:-${RED%.*}.$(( ${RED##*.} + 1 ))}"
PREFIJO=$(mascara_a_prefijo "$MASCARA")
MACS="AA:BB:CC:DD:EE:FF $(grep -oiE 'hardware ethernet [0-9a-f:]{17}' "$CONF" | awk '{print toupper($3)}' | tr '\n' ' ' || true)"

limpiar() {
    sudo pkill -f "^dhcpd -4 -q -cf $TMPCONF" 2>/dev/null || true
    sudo ip link del veth-srv 2>/dev/null || true
    sudo rm -f "$TMPCONF" "$LEASES"*
}
trap limpiar EXIT
limpiar

echo "==> red virtual: veth-srv $SRVIP/$PREFIJO <-> veth-cli"
sudo ip link add veth-srv type veth peer name veth-cli
sudo ip addr add "$SRVIP/$PREFIJO" dev veth-srv
sudo ip addr add 169.254.10.10/16 dev veth-cli      # nmap -e necesita alguna IP de origen en la interfaz
sudo ip link set veth-srv up
sudo ip link set veth-cli up

echo "==> validando $CONF"
sudo install -m 644 "$CONF" "$TMPCONF"
sudo dhcpd -4 -t -cf "$TMPCONF" 2>&1 | grep -vE "^(Internet Systems|Copyright|All rights|For info)" || true

echo "==> levantando dhcpd en veth-srv"
sudo touch "$LEASES"
sudo dhcpd -4 -q -cf "$TMPCONF" -lf "$LEASES" -pf /dev/null veth-srv
sleep 1

for mac in $MACS; do
    echo
    echo "==> DHCPDISCOVER desde la MAC $mac"
    sudo nmap -e veth-cli --script broadcast-dhcp-discover \
        --script-args "broadcast-dhcp-discover.mac=$mac" 2>/dev/null \
        | grep -E "IP Offered|Subnet Mask|Router|Domain Name Server|Lease Time|Server Identifier" \
        || echo "   (sin respuesta: revisá la config o journalctl -t dhcpd)"
done

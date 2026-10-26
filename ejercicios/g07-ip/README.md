# Guía 7: Internet Protocol (sólo lo que se hace con 1 host)

Teoría (traceroute, TTL, fragmentación, tabla de ruteo, forwarding): `../../apuntes/09-ip-traceroute-ruteo.md`

**Fuera del alcance acordado**: E82, E83, E84 y E87 (necesitan host H + R, otros grupos o 2
máquinas). Los conceptos están en el apunte 09 y en `12-temas-multi-host.md`.

## Ojo con el NAT de VirtualBox

La VM tiene la red en **NAT**, y el NAT de VirtualBox arruina traceroute. Probado el 26/10:

- `traceroute -n www.google.com` (UDP): el salto 1 es `10.0.2.2` (el NAT) y después son
  todos `*`. El NAT no devuelve los ICMP *Time Exceeded*.
- `traceroute -I` (ICMP): aparece **el destino en el salto 1**. El NAT de VirtualBox no
  reenvía el ICMP con el mismo TTL: hace él mismo el ping al destino.

Para ver bien E79 a E81 hay dos opciones: correrlo **desde la Mac**
(`traceroute www.google.com`, con Wireshark en la Mac) o poner la placa de red de la VM en
modo **Bridge** (VirtualBox → Configuración → Red).

## Comandos

```bash
# E79: traceroute clásico (UDP a puertos altos 33434+, TTL = 1, 2, 3...)
traceroute -n www.google.com
#   Wireshark: filtro "udp.dstport >= 33434 || icmp"
#   cada router que baja el TTL a 0 contesta ICMP Time Exceeded (type 11) -> así aparece su IP
#   el destino contesta ICMP Port Unreachable (type 3 code 3) -> ahí termina

# E80: otros métodos (atraviesan firewalls que filtran UDP)
traceroute -n -M icmp www.google.com         # = traceroute -I : ICMP Echo Request
sudo traceroute -n -M tcp www.google.com     # = traceroute -T : TCP SYN al puerto 80 (necesita root)

# E81: paquetes de 4000 bytes > MTU 1500 -> fragmentación IP
traceroute -n www.google.com 4000
#   Wireshark: filtro "ip.flags.mf == 1 || ip.frag_offset > 0"
#   4000 bytes de datagrama -> 3 fragmentos (1480 + 1480 + resto de datos)
#   headers IP: Identification igual en los 3, flag MF (More Fragments) = 1 en todos menos el último,
#   Fragment Offset en unidades de 8 bytes (0, 185, 370)
ip link show enp0s8 | grep mtu               # MTU de la interfaz
ping -M do -s 1472 8.8.8.8                   # 1472 + 8 (ICMP) + 20 (IP) = 1500: pasa
ping -M do -s 1473 8.8.8.8                   # "message too long": DF prohíbe fragmentar

# tabla de ruteo y forwarding (para entender E82-E84)
ip route                                     # = route -n / netstat -rn
cat /proc/sys/net/ipv4/ip_forward            # 0 = host, 1 = router
#   sudo sysctl -w net.ipv4.ip_forward=1     (no persiste al reiniciar)

# E85: que NADIE de este host pueda hablar con 192.168.14.0/27 (de 2 maneras)
sudo ip route add unreachable 192.168.14.0/27    # 1) ruta "reject": el kernel rechaza al instante (a un paquete reenviado le contesta ICMP Host Unreachable)
#   (con net-tools:  sudo route add -net 192.168.14.0 netmask 255.255.255.224 reject)
ping -c1 192.168.14.5                            #    -> "ping: connect: No route to host" (falla al instante, sin mandar nada)
sudo ip route del unreachable 192.168.14.0/27
sudo ip route add blackhole 192.168.14.0/27      # 2) blackhole: descarta en silencio, sin ICMP (local: "ping: connect: Invalid argument")
sudo ip route del blackhole 192.168.14.0/27
#   3) también con firewall:  sudo iptables -A OUTPUT -d 192.168.14.0/27 -j REJECT   (y -D para borrarla)

# E86: varias IPs en una sola interfaz (alias)
sudo ip addr add 10.0.2.50/24 dev enp0s8 label enp0s8:1
ip addr show enp0s8                          # aparecen las 2 IPs
ip route                                     # NO cambia: misma red 10.0.2.0/24, misma interfaz (ver "src")
#   Si la IP es de OTRA red (ej. 192.168.99.1/24) SÍ aparece una ruta nueva "192.168.99.0/24 dev enp0s8"
#   Los otros hosts no se enteran: sus tablas no cambian (sólo cambia su cache ARP si te hablan)
sudo ip addr del 10.0.2.50/24 dev enp0s8
#   con net-tools (como dice la guía): sudo ifconfig enp0s8:1 10.0.2.50 netmask 255.255.255.0 up
```

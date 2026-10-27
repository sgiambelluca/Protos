# 12: temas que necesitan varios hosts (Guías 8, 9 y 10)

RIP y ARP entre hosts quedan fuera del alcance práctico acordado (necesitan varias
máquinas). **DHCP, en cambio, salió en el parcial 2025 2C resuelto en una sola VM**: ver la
sección del final y `~/Protos/scripts/practicar-dhcp.sh`. El `isc-dhcp-server` del sistema
sigue sin configurar a propósito; el script usa una red virtual aparte.

## DHCP (Guía 8, RFC 2131)

- **UDP: el server escucha en el 67 y el cliente en el 68.** El cliente todavía **no tiene
  IP**, así que manda desde `0.0.0.0` a `255.255.255.255` (broadcast). El server responde por
  broadcast, o por unicast a la **MAC** del cliente (la saca de `chaddr`), según el flag
  BROADCAST. Así le llega la respuesta a alguien sin IP.
- **DORA**: **D**ISCOVER (broadcast) → **O**FFER (el server propone una IP) → **R**EQUEST
  (broadcast: "elijo la de este server", así los otros servers se enteran) → **A**CK. Los 4
  mensajes tienen el **mismo Transaction ID (xid)**, que es lo que relaciona respuestas con
  pedidos.
- **Otros mensajes**: NAK (rechazo), RELEASE (`dhclient -r`: el cliente devuelve la IP; no
  tiene respuesta), DECLINE (la IP ya está en uso, detectado por ARP), INFORM.
- **Lease** (cuánto dura la asignación). Con lease L:
  - **T1 = L/2**: **RENEWING**, un REQUEST **unicast** al server que la dio.
  - **T2 = 7L/8**: **REBINDING**, un REQUEST **broadcast** a cualquier server.
  - **Al llegar a L** sin ACK, el cliente **pierde la IP** y vuelve a DISCOVER.

  E90 y E91, con un lease de 2 minutos: renueva a los 60 s y hace rebinding a los 105 s. Si
  el server está apagado, pierde la IP a los 120 s.
- **Relay agent** (`giaddr`): un router reenvía los DHCP de otra subred al server.

```
# /etc/dhcp/dhcpd.conf  (isc-dhcp-server; interfaz en /etc/default/isc-dhcp-server: INTERFACESv4="enp0s9")
ddns-update-style none;
default-lease-time 120;          # E90: 2 minutos
max-lease-time 120;
authoritative;
subnet 192.168.56.0 netmask 255.255.255.0 {
    range 192.168.56.100 192.168.56.150;
    option routers 192.168.56.1;              # gateway
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.56.255;
    option domain-name-servers 8.8.8.8;
}
host h1 {                                     # E89: siempre la misma IP (por MAC), FUERA del range
    hardware ethernet 08:00:27:aa:bb:cc;
    fixed-address 192.168.56.10;
}
host h1-denegado {                            # E92: no darle nada a esa MAC
    hardware ethernet 08:00:27:aa:bb:cc;
    deny booting;                             # el server lo ignora: no hay OFFER ni NAK, y el cliente reintenta DISCOVER
}
```

`sudo dhcpd -t` (chequea la sintaxis). Del lado del cliente: `sudo dhclient -v enp0s3` y
`sudo dhclient -r enp0s3`. Filtro de Wireshark: `dhcp` (o `bootp` en versiones viejas). **No
levantarlo en la red del laboratorio**: competiría con el DHCP real.

## RIP (Guía 9, RFC 2453)

- **Vector-distancia**: cada router anuncia **su tabla** (destino + métrica) a sus vecinos
  **cada 30 s**. La métrica es la **cantidad de saltos**, y **16 = infinito** (inalcanzable),
  así que sirve para redes chicas. Con Bellman-Ford distribuido, cada router se queda con
  "lo que me dice el vecino + 1".
- **Transporte**: **UDP 520**. RIPv1 manda por broadcast y es *classful* (no manda la
  máscara). **RIPv2** usa **multicast 224.0.0.9**, manda la **máscara** (CIDR) y el next hop,
  y admite autenticación.
- **Timers**: update 30 s, timeout 180 s (la ruta se marca con métrica 16), garbage
  collection 120 s más.
- **Problema**: el *count to infinity*. Se mitiga con **split horizon** (no anunciarle una
  ruta al vecino del que la aprendiste), **poison reverse** (anunciársela con métrica 16) y
  **triggered updates**.
- `routed` ya no existe en Ubuntu. Se usa **FRR** (`ripd`):

```
# /etc/frr/daemons:  ripd=yes        # /etc/frr/frr.conf:
router rip
 version 2
 network 192.168.101.0/24          ! en qué interfaces/redes hablar RIP
 network 10.3.0.0/16
 redistribute connected
```

`sudo vtysh -c "show ip rip"` y `ip route` (las rutas aprendidas aparecen con
`proto rip`). Wireshark: `rip`.

## ARP y la capa de enlace (Guía 10)

- **ARP** (RFC 826) traduce IP → MAC dentro de **la misma red**. El **Request** va por
  **broadcast** (`ff:ff:ff:ff:ff:ff`): "¿quién tiene 192.168.56.1? Avisale a
  192.168.56.101". El **Reply** va por **unicast**. Las respuestas se guardan en el **cache
  ARP**.
- Para un destino en **otra red**, se hace ARP de la IP **del gateway**, nunca de la IP
  final.

```bash
ip neigh                         # = arp -n   (estados REACHABLE, STALE, PERMANENT...)
sudo ip neigh add 192.168.56.88 lladdr 0a:00:27:00:00:00 dev enp0s3 nud permanent   # = arp -s IP MAC
sudo ip neigh del 192.168.56.88 dev enp0s3                                          # = arp -d IP
sudo ip neigh flush all
```

Respuestas de E96:

- **Agregar una entrada estática no genera tráfico**: sólo cambia la tabla local.
- Ping a la IP X (inventada, con la MAC de H): **no hay ARP**, porque la entrada estática
  lo evita. Sale el Echo Request con la **MAC de H** y la **IP X**. H lo recibe en la placa,
  pero no es su IP y **no responde**.
- **No afecta al tráfico R → H** que usa la IP real de H, porque el cache se indexa **por
  IP**.
- **MAC inexistente para la IP de H**: R manda la trama a esa MAC, nadie la toma y no hay
  respuesta (y tampoco ARP). En cambio **H → R sí funciona**, porque H tiene bien su cache.
- **Dos entradas para la misma IP**: queda **una sola**, la última. El cache es un mapa
  IP → MAC.
- **Gratuitous ARP**: un host anuncia su propia IP (para detectar conflictos o actualizar
  caches). **ARP spoofing**: mandar replies falsos para meterse en el medio (MITM, E98: sólo
  con consentimiento).
- **Switch vs hub**: un switch aprende MAC → puerto y sólo reenvía la trama al puerto
  correcto. Por eso no se ve el tráfico de otros salvo con *port mirroring*, ARP spoofing o
  un hub.

## Forwarding (E97)

En cada salto **cambian** las MAC origen y destino (la de la interfaz de salida del router
y la del siguiente salto), el **TTL baja en 1** y el **checksum IP se recalcula**. **No
cambian** las IP origen y destino, salvo que haya NAT.

## Sockets y C10K (Guía 12, fuera del parcial)

- **C10K**: atender 10.000 conexiones simultáneas. Con un thread o proceso por conexión, se
  terminan la memoria y el tiempo de cambio de contexto.
- La solución son las **syscalls no bloqueantes** + **multiplexación de E/S**
  (`select`/`poll` → **`epoll`**/kqueue): un solo thread atiende miles de sockets y sólo
  trabaja sobre los que están listos. Es el modelo de nginx.
- **Throughput vs tiempo de respuesta** (E109, E110): con un solo cliente iterativo,
  throughput ≈ 1 / tiempo de respuesta. Con más clientes concurrentes, el throughput sube
  hasta que se satura un recurso (CPU, I/O, el buffer). Desde ahí el throughput se estanca y
  el tiempo de respuesta crece (ley de Little: N = X · R).

---

## En parciales anteriores: DHCP en una sola VM (2025 2C, Ej I)

La resolución completa, paso a paso, está en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 4 es otro DHCP (`192.168.90.0/24`, DNS de Cloudflare): `practicar-dhcp.sh ~/Protos/ejercicios/simulacro/ej4-dhcpd.conf`. Ojo al copiar la MAC: si el primer byte es impar, es multicast y ninguna placa la tiene.

**Ojo: DHCP sí salió en un parcial**, resuelto **en una sola VM** con una interfaz en "red
interna" (no hacen falta dos hosts). Pedía:

- la impresora `08:00:27:AE:C8:6A` siempre con `192.168.100.8`;
- DNS `8.8.8.8` y `8.8.4.4`;
- rango `.10`–`.200`.

Se verificaba con:

```bash
sudo nmap --script broadcast-dhcp-discover --script-args "broadcast-dhcp-discover.mac=AA:BB:CC:DD:EE:FF"
```

```
subnet 192.168.100.0 netmask 255.255.255.0 {
    range 192.168.100.10 192.168.100.200;
    option routers 192.168.100.1;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
}
host impresora { hardware ethernet 08:00:27:AE:C8:6A; fixed-address 192.168.100.8; }
```

Más `INTERFACESv4="enpXsY"` en `/etc/default/isc-dhcp-server`, y **una IP de esa red en la
interfaz** (`sudo ip addr add 192.168.100.1/24 dev enpXsY`).

**Explicado desde cero, paso a paso y con DORA**: `18-dhcp-paso-a-paso.md`.

**Para practicarlo en esta VM** sin tocar la red: `~/Protos/scripts/practicar-dhcp.sh`. Arma
un par veth, levanta dhcpd con la config del parcial (o la tuya:
`practicar-dhcp.sh mi.conf`), corre el nmap del enunciado y después limpia todo.

---

## Más práctica (material del repo Protos-ITBA: laboratorio H/R)

**Topología del laboratorio con 2 VMs**: H tiene 1 adaptador en **red interna**. R tiene 2
adaptadores: uno en la **misma red interna** (mismo nombre) y otro en **Bridge/NAT** hacia
afuera. En los adaptadores se activa el **modo promiscuo** para capturar todo. En ambas
VMs se para NetworkManager (`sudo systemctl stop NetworkManager`), porque si no pisa la
configuración manual. Toda la configuración con `ip`/`ifconfig` se pierde al reiniciar.

**R como router con salida a Internet (NAT con iptables)**:

```bash
sudo sysctl -w net.ipv4.ip_forward=1                                   # reenviar paquetes
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE            # SNAT: lo que sale por enp0s3 sale con la IP de R
sudo iptables -t nat -A PREROUTING -i enp0s3 -p tcp --dport 8080 \
     -j DNAT --to-destination 192.168.100.10:80                        # DNAT: exponer un servicio de H en R:8080
sudo iptables -t nat -L -n --line-numbers                              # ver reglas
sudo iptables -t nat -D POSTROUTING 1                                  # borrar la regla nº 1 de esa cadena
```

Sin NAT, H tiene forwarding pero **no le vuelven las respuestas**: el router del laboratorio
no conoce la red de H (la inventó R). Con MASQUERADE, los paquetes salen con la IP de R y R
deshace la traducción a la vuelta. SNAT va en **POSTROUTING** (después de rutear) y DNAT en
**PREROUTING** (antes, para que el ruteo ya vea el destino nuevo).

**`deny booting` en DHCP: el server no responde nada.** Probado con `practicar-dhcp.sh`: en
el log aparece `DHCPDISCOVER from aa:bb:... booting disallowed` y no hay OFFER ni NAK. El
cliente reintenta el DISCOVER. `guia_respuestas.md` del repo dice NAK, y está mal.

**arping** (`sudo apt install arping`): manda ARP requests a mano y no toca tu tabla ARP.
Opciones: `-I iface`, `-S ip_origen`, `-s mac_origen`, `-T ip_destino`, `-t mac_destino`.
Por ejemplo, `sudo arping -I enp0s3 192.168.100.10` verifica si alguien tiene esa IP.

**Ruteo dinámico (comparación)**:

| | RIP v1/v2 | OSPF | BGP |
|---|---|---|---|
| Tipo | vector-distancia | estado de enlace (Dijkstra con el mapa completo) | path-vector, entre sistemas autónomos |
| Métrica | saltos (máx. 15, 16 = ∞) | costo | políticas |
| Problemas / uso | count-to-infinity; redes chicas | converge rápido; redes grandes | Internet entre ISPs |

**Ethernet**: la trama es preámbulo (8) | MAC destino (6) | MAC origen (6) | tipo (2) |
datos (46 a 1500) | CRC (4). En **CSMA/CD**, para que una colisión se detecte, transmitir la
trama tiene que tardar más que ida y vuelta de la señal: **L/R > 2·d_prop**. De ahí salen la
trama mínima de **64 bytes** y el largo máximo del cable.

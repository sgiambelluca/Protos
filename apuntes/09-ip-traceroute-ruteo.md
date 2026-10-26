# 09: IP, ICMP, traceroute y ruteo (Guía 7)

## Header IPv4 (20 bytes sin opciones)

| Campo | Para qué |
|---|---|
| Version / IHL | 4 / largo del header en palabras de 32 bits (5 = 20 bytes) |
| DSCP/ECN | calidad de servicio / congestión |
| **Total Length** | largo del datagrama (header + datos), 65535 como máximo |
| **Identification** | igual en todos los **fragmentos** de un mismo datagrama |
| **Flags** | **DF** (Don't Fragment), **MF** (More Fragments) |
| **Fragment Offset** | posición del fragmento, en **unidades de 8 bytes** |
| **TTL** | se **decrementa en 1 en cada router**. Si llega a 0, se descarta y el router manda **ICMP Time Exceeded** (evita loops) |
| Protocol | 1 ICMP, 6 TCP, 17 UDP, 132 SCTP |
| Header Checksum | sólo del header: **se recalcula en cada salto** porque cambia el TTL |
| Source / Destination | **no cambian en el camino** (salvo con NAT) |

En cada salto **cambian** las MAC origen y destino (Ethernet), el TTL y el checksum. **No
cambian** las IP origen y destino.

## Fragmentación (E81)

- Si el datagrama es más grande que la **MTU** del enlace (Ethernet = 1500), el router (o el
  host que lo origina) lo **fragmenta**. Todos los fragmentos llevan el mismo
  Identification, **MF=1** salvo el último, y su offset. El que **reensambla es el destino
  final**, no los routers.
- Ejemplo con `traceroute host 4000`: 4000 bytes = 20 de header + 3980 de datos, y cada
  fragmento puede llevar 1480 de datos (múltiplo de 8). Quedan **3 fragmentos**:
  1480 (offset 0, MF=1) + 1480 (offset 185, MF=1) + 1020 (offset 370, MF=0).
- **DF=1**: si no entra, el router lo descarta y devuelve **ICMP Fragmentation Needed**
  (type 3 code 4) con la MTU. Así funciona **Path MTU Discovery**.
  `ping -M do -s 1472 host` (1472 + 8 de ICMP + 20 de IP = 1500).
- **IPv6**: los routers **no fragmentan**. Sólo el origen, con un header de extensión.

## ICMP

| Type/Code | Mensaje | Lo genera |
|---|---|---|
| 8 / 0 | Echo Request / Echo Reply | `ping` |
| 3 / 0,1 | Network / Host Unreachable | un router sin ruta, o el ARP que no responde |
| 3 / 3 | **Port Unreachable** | un host al que le llega UDP a un puerto cerrado (fin de traceroute, escaneo UDP) |
| 3 / 4 | Fragmentation Needed (DF) | PMTUD |
| 3 / 13 | Administratively prohibited | firewall (`REJECT`) |
| 11 / 0 | **Time Exceeded** (TTL = 0 en tránsito) | cada salto de traceroute |
| 5 | Redirect | "usá otro gateway" |

## traceroute (E79, E80)

1. Manda sondas con **TTL = 1, 2, 3, ...** (3 por salto). Por defecto en Linux son **UDP a
   puertos altos** (33434 y siguientes, uno distinto por sonda).
2. El router donde el TTL llega a 0 descarta la sonda y responde **ICMP Time Exceeded**. La
   IP de origen de ese ICMP es el salto. Se mide el RTT.
3. Cuando la sonda llega al destino, como el puerto UDP está cerrado, responde **ICMP Port
   Unreachable** y ahí termina.
4. `*` = no hubo respuesta: el router no manda ICMP, un firewall lo filtra o hay rate limit.

- `-M icmp` / `-I`: las sondas son **ICMP Echo Request** y el final es un Echo Reply (es lo
  que hace `tracert` de Windows).
- `-M tcp` / `-T`: **TCP SYN** al puerto 80 (necesita root). El final es un SYN/ACK o un RST.
- **Por qué existen las variantes**: muchos firewalls descartan UDP a puertos raros o ICMP,
  pero dejan pasar TCP/80 o 443. Con el método adecuado se llega más lejos.
- `traceroute host 4000`: el último número es el tamaño del paquete, y fuerza la
  fragmentación (E81).
- **En esta VM** (NAT de VirtualBox): UDP muestra `10.0.2.2` y después `*`, e ICMP muestra el
  destino en el salto 1. Para la práctica, hay que hacerlo desde la Mac o con la red en
  bridge.

## Direccionamiento y CIDR

- `192.168.14.0/24` dividida en `/27` = 8 subredes de 32 direcciones (30 hosts útiles cada
  una): .0, .32, .64, .96, .128, .160, .192, .224. Máscara /27 = 255.255.255.**224**.
- Red = primera dirección (todos los bits de host en 0). Broadcast = la última (todos en 1).
- Privadas (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`. Loopback
  `127.0.0.0/8`. Link-local `169.254.0.0/16`. Documentación `192.0.2.0/24`, `2001:db8::/32`.

## Tabla de ruteo

```bash
ip route                # = route -n = netstat -rn
#   default via 10.0.2.2 dev enp0s8              <- default gateway
#   10.0.2.0/24 dev enp0s8 proto kernel scope link src 10.0.2.15   <- red conectada directamente (sin gateway)
ip route get 8.8.8.8    # qué ruta usaría para ese destino
```

- **Longest prefix match**: entre las rutas que coinciden, gana **la más específica** (/32 >
  /24 > /0). La default (`0.0.0.0/0`) es la menos específica.
- **Ruta conectada** (sin `via`): el destino está en la misma red, así que se manda
  directo, haciendo **ARP de la IP destino**.
- **Ruta con gateway** (`via R`): se hace **ARP de la IP del gateway** y la trama va con la
  **MAC del gateway**, pero con la **IP del destino final**.
- **No se puede agregar `via X` si X no es alcanzable** por una ruta conectada
  ("Nexthop has invalid gateway").
- **Host vs router**: `/proc/sys/net/ipv4/ip_forward` vale 0 en un host (descarta lo que no
  es para él) y 1 en un router (lo reenvía según su tabla). Se cambia con
  `sysctl -w net.ipv4.ip_forward=1` y se hace persistente en `/etc/sysctl.d/*.conf`.
- **Para que dos redes se hablen hace falta ida Y vuelta**: cada lado necesita una ruta
  hacia la red del otro. Es el error más común en E83 y E84.

```bash
sudo ip route add 192.168.58.0/24 via 192.168.56.2      # = route add -net 192.168.58.0/24 gw 192.168.56.2
sudo ip route add default via 10.0.2.2
sudo ip route del 192.168.58.0/24
sudo ip route add unreachable 192.168.14.0/27           # E85 "reject" (= route add -net ... reject)
sudo ip route add blackhole 192.168.14.0/27             # E85 descarte silencioso
```

## Varias IPs en una interfaz (E86)

`ip addr add 10.0.2.50/24 dev enp0s8` (con ifconfig: alias `enp0s8:1`). Si la IP nueva es
de **la misma red**, la tabla de ruteo **no cambia**. Si es de **otra red**, aparece una ruta
conectada nueva. Los otros hosts **no se enteran** hasta que les llega tráfico (ARP).

## E87: 192.168.0.18 y 192.168.0.13 en el mismo switch no se ven

Casi siempre es un problema de **máscaras o rutas**. Por ejemplo: uno tiene /29 (.18 está
en .16–.23 y .13 en .8–.15, que son redes distintas, así que intenta ir por un gateway que
no existe) o le falta la ruta conectada. Soluciones: corregir la máscara (`ip addr`, o
`ifconfig` según el enunciado) o agregar una ruta al otro host por la interfaz
(`ip route add 192.168.0.13/32 dev eth0`, sin ifconfig). Otra opción es una entrada ARP
estática.

---

## En parciales anteriores

La resolución completa, paso a paso, está en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 6 es la ruta + nmap + traceroute de siempre, con el gateway `192.168.80.250`. No se puede probar desde casa.

**2024 2C Ej III y 2025 2C Ej II**: llegar a una red que está **detrás de un gateway que no
es tu default**.

```bash
ping <GATEWAY>                                       # ¿lo veo? (VM en Bridge a la red Lab)
sudo ip route add 10.0.0.0/24 via <GATEWAY>          # = route add -net 10.0.0.0/24 gw <GATEWAY>
ip route get 10.0.0.1                                # confirmar que sale "via <GATEWAY>"
traceroute -n 10.0.0.1                               # el primer salto tiene que ser <GATEWAY>
```

Por qué hace falta: el **longest prefix match** elige `10.0.0.0/24` (que es más específica
que la default). La trama sale con la **MAC del gateway** y la **IP destino 10.0.0.1**. Sin
la ruta, el paquete va al router por defecto, que no conoce esa red.

---

## Más práctica (material del repo Protos-ITBA)

### Subnetting rápido

| Prefijo | Máscara | Hosts usables (2^n − 2) |
|---|---|---|
| /24 | 255.255.255.0 | 254 |
| /25 | 255.255.255.128 | 126 |
| /26 | 255.255.255.192 | 62 |
| /27 | 255.255.255.224 | 30 |
| /28 | 255.255.255.240 | 14 |
| /29 | 255.255.255.248 | 6 |
| /30 | 255.255.255.252 | 2 |

- **Red** = IP AND máscara. **Broadcast** = red OR (NOT máscara).
- ¿192.168.1.93 está en la /27 de .64? 93 AND 224 = 64, así que sí (la red va de .64 a .95,
  con hosts del .65 al .94).
- Para k subredes hacen falta ⌈log₂ k⌉ bits. Para N hosts, ⌈log₂(N+2)⌉ bits.
- Multicast: `224.0.0.0/4` (224 a 239). RIPv2 usa `224.0.0.9`.

### Modos de red de VirtualBox (salen en los enunciados: "VM en modo Bridge")

| Modo | Qué es | Cuándo |
|---|---|---|
| **NAT** (el de esta VM) | sale a Internet con la IP del host; nadie de afuera la ve | uso normal (traceroute se ve mal) |
| **Bridge** | la VM es un equipo más en la red física, con IP propia | parciales con la red del laboratorio (gateway 192.168.x, nmap a 10.0.0.x) |
| **Red interna** | sólo las VMs con el **mismo nombre** de red, sin host ni Internet | laboratorio H ↔ R, DHCP (2025 Ej I) |
| **Host-only** | red entre el host y las VMs, sin Internet | probar desde la Mac |
| **Red NAT** | como NAT, pero las VMs se ven entre sí | varias VMs con Internet |

### Tablas de ruteo con VPN (pregunta conceptual)

Escenario: mi IP es 192.168.3.2 (router 192.168.3.1), el servidor VPN es 24.232.1.1 y la red
de la VPN es 10.3.0.0/24 (gateway 10.3.0.1).

| | Full tunnel (todo por la VPN) | Split tunnel (sólo la red de la VPN) |
|---|---|---|
| default `0.0.0.0/0` | **vpn0** via 10.3.0.1 | eth0 via 192.168.3.1 |
| `10.3.0.0/24` | vpn0 | vpn0 |
| `24.232.1.1/32` | **eth0 via 192.168.3.1 (obligatoria)** | no hace falta |

En full tunnel, la ruta /32 al servidor VPN es la que evita el **loop**: sin ella, los
propios paquetes del túnel intentarían salir por el túnel. Por longest prefix match, la /32
le gana a la default.

---

## Del integrador (CTF Protolab, `~/Protos/recu/`)

"¿Cuál es el gateway de pampero para llegar a 1.1.1.1?": la respuesta sale de la tabla de
ruteo **de pampero**, así que el comando se corre ahí y no en tu máquina:

```bash
ssh usuario@pampero.itba.edu.ar
ip route get 1.1.1.1
# 1.1.1.1 via 10.16.1.254 dev enp1s0 src 10.16.1.100     -> el gateway es lo que sigue a "via"
```

`ip route get` dice qué ruta usaría el kernel: `via` (next hop), `dev` (interfaz) y `src` (IP
de origen). Si no hay una ruta más específica, es la `default`.

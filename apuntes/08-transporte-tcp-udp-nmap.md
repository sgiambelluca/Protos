# 08: capa de transporte: TCP, UDP, SCTP, netcat, nmap (Guía 6)

## Puertos

- Identifican el **proceso** dentro del host. Un socket TCP queda definido por la 4-tupla
  (IP origen, puerto origen, IP destino, puerto destino).
- Rangos: 0–1023 **bien conocidos** (necesitan root para escuchar), 1024–49151
  registrados, 49152–65535 efímeros (en Linux: `cat /proc/sys/net/ipv4/ip_local_port_range`).
- `/etc/services` tiene la tabla nombre ↔ puerto: echo 7, discard 9, daytime 13, chargen
  19, ftp 21, ssh 22, telnet 23, smtp 25, time 37, dns 53, dhcp 67/68, http 80, pop3 110,
  imap 143, https 443, submission 587, rip 520.

## TCP (RFC 9293)

Es **orientado a conexión**, confiable (ACK + retransmisión), **ordenado**, un **flujo de
bytes** (no conserva los límites de los mensajes), con control de flujo (ventana) y control
de congestión (slow start, AIMD).

**Header**: puertos, número de **secuencia**, número de **ACK**, flags (**SYN**, **ACK**,
**FIN**, **RST**, PSH, URG), **ventana**, checksum y opciones (MSS, window scale, SACK,
timestamps).

```
Handshake (3 vías)            Cierre (4 segmentos; cada lado cierra su mitad)
C ── SYN seq=x ──────► S      A ── FIN ──► B        A: FIN_WAIT_1
C ◄─ SYN,ACK seq=y ack=x+1    A ◄── ACK ── B        A: FIN_WAIT_2   B: CLOSE_WAIT
C ── ACK ack=y+1 ───► S       A ◄── FIN ── B                        B: LAST_ACK
                              A ── ACK ──► B        A: TIME_WAIT (2·MSL) -> CLOSED
```

### Estados (los que muestran `ss -tan` y `netstat -tan`)

| Estado | Qué significa |
|---|---|
| LISTEN | socket pasivo esperando conexiones |
| SYN_SENT / SYN_RECV | handshake en curso |
| ESTABLISHED | conexión abierta |
| FIN_WAIT_1 / FIN_WAIT_2 | yo cerré primero y espero el ACK, y después el FIN del otro |
| CLOSE_WAIT | el otro cerró y **yo todavía no** (muchos en este estado = la aplicación no hace close) |
| LAST_ACK | cerré después y espero el último ACK |
| TIME_WAIT | cerré primero y espero 2·MSL para que no se mezclen segmentos viejos con una conexión nueva |

- **RST**: aborta la conexión. Se manda al conectarse a un **puerto cerrado** (E73: llega
  `RST,ACK` al instante y nc dice "Connection refused"), o cuando muere el proceso con datos
  sin leer.
- Si un firewall **descarta** el SYN (*drop*), no vuelve nada: el SYN se **retransmite** con
  backoff exponencial (1 s, 2 s, 4 s...) hasta el timeout.
- **Nagle**: junta varios bytes chicos en un solo segmento mientras hay datos sin ACK. Con el
  echo de E75: una tecla cada 1 segundo = 1 segmento por tecla; una tecla apretada = varios
  caracteres por segmento.
- **ACK retrasado**: el receptor espera un poco para mandar el ACK junto con datos (el eco).

## UDP (RFC 768)

Header de 8 bytes: puertos, largo y checksum. **Sin conexión**, sin confiabilidad, sin
orden, sin control de flujo. **Conserva los límites de los mensajes** (1 send = 1
datagrama). Lo usan DNS, DHCP, RIP, streaming, juegos y QUIC.

- En el echo UDP (E76) no hay handshake ni estados. Si el servidor no existe, vuelve un
  **ICMP Port Unreachable** y el *siguiente* `recv` del cliente falla con "Connection
  refused". Si se mata un extremo, el otro no se entera.
- Por qué nc muestra lo mismo que mandó: el servicio echo (RFC 862) **devuelve cada
  datagrama** al puerto de origen, y nc imprime lo que recibe en ese socket.
- **Tamaño máximo**: 65535 − 8 − 20 = **65507 bytes** de datos en IPv4. Si supera la MTU,
  se fragmenta en IP.

## SCTP (RFC 9260)

Es confiable como TCP, pero **orientado a mensajes** como UDP. Tiene **multi-streaming**
(varios flujos independientes en una misma asociación, sin head-of-line blocking entre
ellos) y **multi-homing** (varias IPs por extremo, con failover). Usa un **handshake de 4
vías con cookie** (INIT, INIT-ACK, COOKIE-ECHO, COOKIE-ACK) que resiste el SYN flood.
Se cierra con SHUTDOWN, SHUTDOWN-ACK y SHUTDOWN-COMPLETE, sin estado half-closed. Los
datos van en chunks DATA, que se confirman con SACK. Lo usan la telefonía (SIGTRAN) y los
DataChannels de WebRTC.

En esta VM: `ncat --sctp` **envía** bien, pero el **receptor** (`ncat -l --sctp`) no
entrega datos en la versión 7.98. Hay que usar `ejercicios/g06-transporte/sctp-recv.py`.

## netcat: variantes

| | `nc` (netcat-openbsd, el de esta VM) | `ncat` (de nmap) |
|---|---|---|
| Escuchar | `nc -l 9999` | `ncat -l 9999` |
| UDP | `-u` | `-u` / `--udp` |
| SCTP | no | `--sctp` |
| Fin de línea CRLF | `-C` | `-C` |
| Por un proxy SOCKS5 | `-X 5 -x host:1080` | `--proxy host:1080 --proxy-type socks5` |
| Cerrar al terminar stdin | `-N` / `-q 1` | `--send-only` / `--recv-only` |
| Sólo probar si conecta | `-z -v` | — |

## ss / netstat

```bash
ss -tan                  # TCP, todas, numérico: estados de cada conexión
ss -tulpn                # puertos en escucha TCP+UDP, con el proceso (con sudo)
ss -tan state time-wait
netstat -tulpn           # lo mismo con net-tools (más viejo)
```

## nmap (E72, E77, E78)

| Escaneo | Cómo | Cuándo |
|---|---|---|
| `-sS` **SYN scan** ("half-open", el default con root) | SYN → si vuelve **SYN/ACK** está *open* (y nmap manda RST sin completar), si vuelve **RST** está *closed*, si no vuelve nada o vuelve ICMP unreachable está *filtered* | rápido y discreto (la aplicación no ve la conexión); necesita root (raw sockets) |
| `-sT` **connect scan** | `connect()` del SO: handshake completo y después cierra | sin root, o con IPv6/proxies; más lento y **queda en los logs** del servicio |
| `-sU` **UDP** | datagrama (vacío o con el payload del protocolo): si vuelve **ICMP port unreachable** está *closed*, si vuelve una respuesta UDP está *open*, si no vuelve nada está *open\|filtered* | **lento** (los ICMP tienen rate limit en el kernel) |
| `-O` | detección del SO por la "huella" del stack (TTL inicial, ventana, opciones TCP, IP ID) | E78 |
| `-sV` | versión del servicio (banners, sondas) | |
| `-p 22,80` / `-p-` / `--top-ports 100` | qué puertos | |
| `-sn` | sólo descubrir qué hosts están vivos (ping sweep) | |

Estados de un puerto: **open**, **closed**, **filtered** (un firewall descarta),
**unfiltered**, **open|filtered**.

---

## En parciales anteriores

La resolución completa, paso a paso, está en `14-resoluciones-parciales.md`.

**2024 2C Ej III y 2025 2C Ej II**: "El host X es el gateway de la red 10.0.0.0/24.
Descubrí el servidor y sus servicios, accedé por HTTP y mostrá los routers". Se resuelve con
una ruta y después nmap:

```bash
sudo ip route add 10.0.0.0/24 via <GATEWAY>       # sin esto no llegás (ver apunte 09)
sudo nmap -sn 10.0.0.0/24                          # 2025: no sabés la IP -> descubrir hosts vivos
sudo nmap -Pn -p- --open 10.0.0.0/24               #   si el ping está filtrado
sudo nmap -sS -sV -Pn 10.0.0.X                     # servicios + versiones (-Pn: no hace falta que responda ping)
curl -v http://10.0.0.X:PUERTO/
traceroute -n 10.0.0.X                             # o -I / -T si salen asteriscos
```

| Flag | Para qué |
|---|---|
| `-sn` | sólo descubrir hosts (sin escanear puertos) |
| `-Pn` | no hacer el "ping" previo: escanea aunque el host parezca caído |
| `-sS` | SYN scan (root) |
| `-sV` | versión del servicio |
| `-p-` | los 65535 puertos |
| `--open` | mostrar sólo los abiertos |
| `--script broadcast-dhcp-discover` | simular un cliente DHCP (2025 Ej I) |

---

## Más práctica (material del repo Protos-ITBA)

**ncat como "servidor de juguete"** (Ej 2 y 8 de `15-ejercicios-extra.md`):

```bash
ncat -l 8080 -k -c "cat"                       # echo server iterativo (-k: no muere después de la 1ra conexión)
ncat -l 127.0.0.1 3333 -k -c "echo hola"       # atado a UNA IP: otro proceso puede usar el mismo puerto en otra IP
ncat 127.0.0.1 3333 --recv-only                # cliente que sólo recibe (cierra cuando el server cierra)
```

**Ctrl+D en nc** = EOF en stdin. nc hace `shutdown()` de **su mitad** de la conexión (manda
FIN), pero puede seguir recibiendo: TCP es full-duplex y cada lado cierra su dirección por
separado (*half-close*).

**nmap, más opciones**:

| Flag | Qué hace |
|---|---|
| `-A` | agresivo: `-sV` + `-O` + scripts por defecto + traceroute |
| `-sC` / `--script nombre` | scripts NSE (`ls /usr/share/nmap/scripts/`). Ej.: `broadcast-dhcp-discover`, `ssh-auth-methods` |
| `-T0` … `-T5` | velocidad (default `-T3`; `-T4` es rápido y razonable) |
| `--top-ports 20` | los N puertos más comunes |
| `-oN archivo` / `-oA base` | guardar la salida (normal / todos los formatos) |

**Qué buscar en Wireshark**:

| Situación | Qué se ve |
|---|---|
| conexión TCP aceptada | SYN → SYN,ACK → ACK |
| puerto TCP cerrado | SYN → RST,ACK |
| UDP | sólo datagramas, sin handshake (si el puerto está cerrado: ICMP port unreachable) |
| forwarding IP | en cada salto cambian las MAC; las IP no |
| DHCP | DISCOVER → OFFER → REQUEST → ACK |
| ARP | request en broadcast → reply en unicast |

**Corrección al cheat_04 del repo**: el payload máximo de UDP **sin fragmentar** sobre
Ethernet es **MTU − 20 (IP) − 8 (UDP) = 1472** bytes. El header Ethernet no cuenta, porque
la MTU (1500) ya es el tamaño del paquete IP.

---

## Del integrador (CTF Protolab, `~/Protos/recu/`)

Una pista decía que la clave del vault estaba en un servidor HTTP "en un puerto entre 49000
y 50000":

```bash
nmap -Pn -n --open -p49000-50000 192.168.0.238    # -p acepta rangos; -n: sin DNS inverso; --open: sólo abiertos
# 49681/tcp open
curl http://192.168.0.238:49681/                  # el listado del directorio (python http.server)
```

En la VM, `sudo nmap -Pn -n --open -p8000-8100 127.0.0.1` encuentra el `8080/tcp open` del
backend Python.

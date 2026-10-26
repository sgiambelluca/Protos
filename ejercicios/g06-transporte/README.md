# Guía 6: protocolos de transporte

Teoría (TCP vs UDP vs SCTP, estados TCP, escaneos): `../../apuntes/08-transporte-tcp-udp-nmap.md`

## Estado

Los servicios de xinetd ya estaban **habilitados en clase**, en TCP y en UDP:

| Servicio | Puerto | Archivo | Qué responde |
|---|---|---|---|
| echo | 7 | `/etc/xinetd.d/echo` | devuelve lo mismo que recibe |
| discard | 9 | `/etc/xinetd.d/discard` | descarta todo |
| daytime | 13 | `/etc/xinetd.d/daytime` | fecha y hora en texto |
| chargen | 19 | `/etc/xinetd.d/chargen` (sólo TCP) | genera caracteres sin parar |
| time | 37 | `/etc/xinetd.d/time` | segundos desde 1900 en 4 bytes binarios (big-endian) |

Son servicios `type = INTERNAL`: los implementa el propio xinetd, sin ningún `server =`.

En cada archivo hay **2 bloques**: `id = echo-stream` (TCP) e `id = echo-dgram` (UDP). Para
**E75** (sólo TCP) se pone `disable = yes` en el bloque dgram, y para **E76** (sólo UDP) en
el bloque stream. Después: `sudo systemctl restart xinetd`.

## Comandos

```bash
# E72: ¿qué servicios están activos? (sin acceso al host)
nmap -p 7,13,23,25,37 localhost              # TCP (connect scan si no sos root)
sudo nmap -sU -p 7,13,37 localhost           # UDP (lento: espera ICMP port unreachable)
nc -zv localhost 13                          # -z: sólo prueba si conecta
nc localhost 13                              # daytime -> "Mon Oct 26 17:40:01 2026"
nc localhost 37 | xxd                        # time -> 4 bytes binarios

# E73: conectarse a un puerto CERRADO
#   local (o a un host que existe):   SYN -> RST,ACK   (falla al instante: "Connection refused")
#   a un host con firewall que descarta: SYN, SYN retransmitido... (timeout)
nc -v localhost 5555
nc -v -w 5 google.com 25

# E74: transferir un archivo con TCP, UDP y SCTP (receptor primero)
ncat -l 4000 > recibido.txt                  #  TCP receptor
ncat --send-only localhost 4000 < /etc/services
ncat -l --udp 4000 > recibido.txt            #  UDP: no hay conexión ni fin -> cortar a mano con Ctrl-C
ncat --udp --send-only localhost 4000 < /etc/services
./sctp-recv.py 4000 > recibido.txt          #  SCTP receptor: en ESTA versión `ncat -l --sctp` acepta pero no entrega datos
ncat --sctp --send-only localhost 4000 < /etc/services   # el emisor ncat sí funciona (el módulo sctp se carga solo)
cmp /etc/services recibido.txt && echo IGUALES
#   Wireshark en "lo", filtros: tcp.port==4000 / udp.port==4000 / sctp
#   TCP: handshake de 3 vías, ACKs y FIN. UDP: sólo datagramas. SCTP: INIT, INIT_ACK, COOKIE_ECHO, COOKIE_ACK (4 vías), DATA/SACK y SHUTDOWN

# E75: echo TCP + estados (netstat / ss)
nc localhost 7                               # escribir de a una letra, rápido, Ctrl-C...
watch -n 0.5 'ss -tan "( sport = :7 or dport = :7 )"'
#   LISTEN -> ESTABLISHED. Al cerrar: quien cierra primero pasa por FIN_WAIT_1/2 y queda en TIME_WAIT;
#   el otro lado pasa por CLOSE_WAIT y LAST_ACK. Si matás el server: sudo systemctl stop xinetd
#   Con Nagle/eco: caracteres sueltos = 1 segmento cada uno; tecla apretada = varios caracteres por segmento

# E76: echo UDP
nc -u localhost 7                            # cada Enter = 1 datagrama, y vuelve 1 datagrama
#   no hay handshake ni estados. Si matás el server, el cliente no se entera hasta mandar algo
#   y recibir un ICMP port unreachable

# E77/E78: nmap (contra localhost o la red de tu casa; pampero está fuera del alcance)
sudo nmap -sS localhost                      # SYN scan ("half-open"): SYN -> SYN/ACK -> RST (no completa la conexión)
nmap -sT localhost                           # connect scan: handshake completo (no necesita root, queda en los logs)
sudo nmap -sU --top-ports 20 localhost       # UDP
sudo nmap -O 10.0.2.2                        # adivinar el SO por la "huella" del stack TCP/IP
sudo nmap -sV localhost                      # versión de cada servicio (lee banners)
```

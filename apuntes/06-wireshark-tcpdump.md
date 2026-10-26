# 06: Wireshark y tcpdump (todas las {W})

## Captura

- **Interfaz**: `lo` (Loopback) para todo lo que va a `localhost`/`127.0.0.1` (nginx, bind,
  postfix, dovecot, telnet y echo dentro de la VM). `enp0s8` para lo que sale a Internet.
  `any` = todas (en Linux).
- **Permisos**: tu usuario está en el grupo `wireshark` (hay que cerrar sesión y volver a
  entrar la primera vez). Si no, hay que usar `sudo`.
- Con **HTTPS** sólo se ve el handshake TLS (incluido el **SNI**, el nombre del sitio en
  texto plano). El contenido no. Para eso: DevTools (F12 → Network) o usar http.

## Filtros

| | Filtro de **captura** (BPF, también tcpdump) | Filtro de **visualización** (Wireshark) |
|---|---|---|
| Cuándo | antes de capturar (descarta lo que no coincide) | después: se puede cambiar cuando quieras |
| Puerto | `port 53`, `tcp port 80` | `tcp.port == 80`, `udp.port == 53` |
| Host | `host 10.0.2.15` | `ip.addr == 10.0.2.15`, `ip.src == ...` |
| Protocolo | `icmp`, `udp`, `arp` | `http`, `dns`, `smtp`, `pop`, `telnet`, `icmp`, `arp`, `dhcp`, `rip`, `sctp`, `tls` |
| Combinar | `and` / `or` / `not` | `&&` / `\|\|` / `!` |

Filtros de visualización útiles:

```
http.request                      solo los pedidos HTTP
http.response.code == 304
dns.flags.response == 0           sólo consultas DNS
dns.qry.name contains "itba"
tcp.flags.syn == 1 && tcp.flags.ack == 0     SYN iniciales (escaneos, E77)
tcp.flags.reset == 1              RST (puerto cerrado, E73)
tcp.analysis.retransmission       retransmisiones
icmp.type == 11                   Time Exceeded (traceroute, E79)
icmp.type == 3                    Destination Unreachable
ip.flags.mf == 1 || ip.frag_offset > 0       fragmentos (E81)
smtp || pop                       mail (E60)
tls.handshake.extensions_server_name         SNI
```

## Herramientas de análisis

- **Follow → TCP/UDP Stream** (clic derecho sobre un paquete): muestra la conversación como
  texto, con el cliente en rojo y el servidor en azul. Es ideal para HTTP, SMTP, POP3 y
  telnet.
- **Statistics → Conversations / Flow Graph**: ver el handshake y el cierre TCP.
- **Expert Info**: retransmisiones, resets, etc.
- En cada paquete se ve el árbol por capas: Frame → Ethernet (MAC) → IP → TCP/UDP →
  aplicación.

## tcpdump / tshark (consola)

```bash
sudo tcpdump -ni any port 53                    # -n: no resolver nombres. -i: interfaz
sudo tcpdump -ni lo tcp port 25 -A              # -A: muestra el contenido en ASCII
sudo tcpdump -ni enp0s8 icmp -c 10              # -c: cortar después de 10 paquetes
sudo tcpdump -ni any -w captura.pcap port 80    # guardar en un archivo (después se abre en Wireshark)
tshark -i lo -f "port 110" -Y pop               # -f captura, -Y visualización
tshark -r captura.pcap -Y http.request -T fields -e http.host -e http.request.uri
```

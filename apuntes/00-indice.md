# Apuntes: Protocolos de Comunicación (72.07)

Cada archivo junta la **teoría** (qué hace cada componente), la **sintaxis** (de las
configuraciones y los comandos) y los **errores comunes**, con ejemplos que corren en esta
VM. Los ejercicios resueltos están en `~/Protos/ejercicios/`.

| # | Archivo | Temas | Guía |
|---|---|---|---|
| 01 | `01-unix-y-codificaciones.md` | grep/tail, syscalls y sendfile, ASCII, ISO-8859-1, Unicode, UTF-8/16/32, endianness, serialización, ABNF | 1 |
| 02 | `02-uri-http.md` | URI, mensajes HTTP, métodos, códigos, headers, conexiones persistentes, chunked, cache, ETag, cookies, auth | 2 |
| 03 | `03-nginx.md` | arquitectura, archivos, server/location, proxy reverso, gzip, SSL, reload | 2, 3 |
| 04 | `04-dns-y-bind9.md` | jerarquía, zonas, registros, SOA, recursión, archivos de zona, bind9, dig, resolved | 3 |
| 05 | `05-correo-smtp-pop3-mime.md` | MUA/MTA/MDA, SMTP, sobre vs headers, relay, postfix, POP3, dovecot, MIME, base64, QP, SPF/DKIM | 4 |
| 06 | `06-wireshark-tcpdump.md` | captura, filtros, follow stream | todas las {W} |
| 07 | `07-telnet-xinetd.md` | super-server, xinetd, telnet NVT, IAC, eco | 5 |
| 08 | `08-transporte-tcp-udp-nmap.md` | puertos, TCP (handshake, estados, cierre), UDP, SCTP, netcat, ss, nmap | 6 |
| 09 | `09-ip-traceroute-ruteo.md` | header IPv4, TTL, fragmentación, ICMP, traceroute, tabla de ruteo, CIDR | 7 |
| 10 | `10-ssh.md` | host keys, known_hosts, claves de usuario, sshd_config, scp, túneles | 11 |
| 11 | `11-tls-y-certificados.md` | TLS, PKI, CA, certificados, mkcert, HSTS | 2 |
| 12 | `12-temas-multi-host.md` | DHCP (**salió en 2025**, en una sola VM), RIP, ARP, forwarding | 8, 9, 10 |
| 13 | `13-comandos-rapidos.md` | todos los comandos en una página + checklist cuando algo no anda + **checklist antes de entregar** | todas |
| **14** | **`14-resoluciones-parciales.md`** | **parciales prácticos 2022 a 2026 resueltos paso a paso** (y qué temas toman más), con **aclaraciones** de dudas y 3 conceptos que se repiten (resolución de nombres, IP y MAC, TTL); incluye los dos de 2022 que trae `ejercicios-practicos.md` | — |
| **15** | **`15-ejercicios-extra.md`** | **11 ejercicios tipo parcial** del repo (304, ncat, nginx con backend HTTPS, listen por IP, túneles, redirects, zona carlitos...) | — |
| 16 | `16-vim-y-nano.md` | editar configs en la VM: nano, vim y `sudo tee` | — |
| **17** | **`17-simulacro.md`** | **simulacro de parcial (7 ejercicios) para hacer a ciegas** en la VM con `simulacro.sh`, resoluciones y errores del PDF | — |
| **18** | **`18-dhcp-paso-a-paso.md`** | **DHCP desde cero**: DORA, el ejercicio de 2025 explicado paso a paso con pruebas, errores típicos y tu config de clase para corregir | 8 |

Además, en `~/Protos/referencias/Cheatsheet_lab_ip.pdf` está el **cheatsheet del laboratorio de
IP** de la cátedra, copiado tal cual del repo. Está sólo en la copia local: no se sube al repo de GitHub (el original está en `practica/` de rodrihern/Protos-ITBA).

Los apuntes 02, 03, 04, 05, 08, 09, 10, 11 y 12 terminan con una sección **"En parciales
anteriores"** que tiene los ejemplos tomados de ese tema. Las resoluciones completas están
todas juntas en el 14. Varios tienen además una sección **"Más práctica"** con lo útil del
material de práctica del repo, resuelto en el 15. Y ahí mismo dice qué ejercicio del **simulacro** (17) es de ese tema. Los 02, 04, 08, 09 y 10 cierran con **"Del integrador"**: lo útil del CTF Protolab (`~/Protos/recu/`).

## Antes del parcial

```bash
~/Protos/scripts/verificar-todo.sh     # todo tiene que dar OK
```

Cuando algo no anda, en este orden:

1. ¿El servicio está corriendo? `systemctl status X`
2. ¿Qué dice el log? `journalctl -u X -n 50`
3. ¿Está escuchando donde creo? `sudo ss -tulpn`
4. ¿La sintaxis está bien? `nginx -t`, `named-checkconf -z`, `postfix check`, `doveconf -n`
5. ¿Qué pasa por el cable? Wireshark o tcpdump

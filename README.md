# Protos: práctica y apuntes (VM UbuntuA)

Material para preparar el parcial de **Protocolos de Comunicación (ITBA 72.07)**. En la VM
está en `~/Protos` y también se puede abrir como `/root/Protos` (es un symlink) cuando
estás como root con `sudo -i`.

```
Protos/
├── README.md               <- este archivo: estado de cada ejercicio y qué se tocó del sistema
├── apuntes/                <- teoría + sintaxis + errores comunes, por tema (empezar por 00-indice.md)
│                              14 = parciales resueltos, 15 = ejercicios extra, 16 = vim/nano,
│                              17 = simulacro de parcial (13 tiene la checklist antes de entregar)
├── referencias/            <- Cheatsheet_lab_ip.pdf (cheatsheet del lab de IP de la cátedra, tal cual).
│                              Sólo en la copia local: no se sube al repo (ver "Material de terceros")
├── recu/                   <- ctf-protolab-resumen.md/.html: el CTF del integrador resuelto (el .html tiene las
│                              respuestas ocultas para practicar). Ejercicio_integrador.md (+ 2 imágenes) es sólo local
├── ejercicios/             <- un README por guía: qué está hecho, dónde está la config y cómo probarlo
│   ├── g01-intro/          (copy.c, Unicode.java, formato de log E11)
│   ├── g02-http/           (nginx: foo, bar, what, proxy reverso, gzip, HTTPS)
│   ├── g03-dns/            (bind9: zona foo.pdc.lab directa e inversa, forwarders, resolved)
│   ├── g04-correo/         (postfix, dovecot, mutt, base64, MIME)
│   ├── g05-telnet/         (xinetd + telnetd)
│   ├── g06-transporte/     (echo/daytime/time por xinetd, netcat TCP/UDP/SCTP, nmap)
│   ├── g07-ip/             (traceroute, rutas reject, alias de IP; sólo lo que se hace con 1 host)
│   ├── g11-ssh/            (fingerprints, login con clave, túneles)
│   ├── parciales/          (archivos de los parciales 2022-2026: zonas, nginx, dhcpd.conf, mail)
│   ├── simulacro/          (simulacro de Mateo Andrioli: zona sucursal.foo, nginx seguro, dhcpd.conf, mail;
│   │                        en catedra/ los servidores falsos que levanta simulacro.sh)
│   └── extra/              (configs de los ejercicios extra: zona carlitos, nginx puerro, nginx listen por IP)
├── config/                 <- copia "buena" de cada archivo de configuración, con la misma ruta que en /
├── scripts/
│   ├── verificar-todo.sh   <- prueba TODO y dice OK/FALLA por ejercicio (correrlo antes del parcial)
│   ├── instalar-configs.sh <- vuelve a aplicar config/ si rompiste algo practicando
│   ├── foo-modo.sh         <- cambia el sitio foo entre "estatico" (E36) y "proxy" (E39)
│   ├── practicar-dhcp.sh   <- practica un DHCP (parcial 2025, simulacro o tu conf) en una red virtual (no toca la red real)
│   └── simulacro.sh        <- montar | verificar | limpiar: el simulacro de parcial en la VM, con corrección automática
└── backups-originales/     <- cómo estaban los archivos de /etc ANTES del 26/10/2026
```

## Cómo usarlo

```bash
~/Protos/scripts/verificar-todo.sh       # estado de todo (debería dar 45 OK, 0 FALLA)
less ~/Protos/apuntes/00-indice.md       # empezar a estudiar
less ~/Protos/apuntes/14-resoluciones-parciales.md   # parciales anteriores resueltos
~/Protos/scripts/simulacro.sh montar     # simulacro de parcial: enunciados en apuntes/17-simulacro.md
```

Mientras el simulacro está montado, `verificar-todo.sh` da FALLA en `named-checkconf -z`
hasta que arregles la zona `sucursal.foo` (es el Ej 1). `simulacro.sh limpiar` lo saca todo.

Si practicando rompés una configuración, `~/Protos/scripts/instalar-configs.sh` la deja
como estaba. Ojo: pisa los archivos de `/etc` que están en `config/`.

**Repo git**: vive en la Mac (`/Users/maratorres/cosas protos/Protos`). A la VM se copia
con `rsync -a --exclude .git --exclude .DS_Store Protos/ ubuntua:Protos/`, así que en la VM
no hay `.git`. No se suben `backups-originales/` (sólo sirve en esa VM), los compilados de
la Guía 1 ni claves (ver `.gitignore`).

## Alcance

Según lo que se acordó para el parcial:

- **Afuera**: programación con sockets (Guía 12) y todo lo que necesita host H + R, la red
  del laboratorio, varias computadoras o pampero. Eso es DHCP entre dos hosts (G8), RIP (G9),
  ARP entre hosts (G10), E82 a E84, E87, E99 desde otro host y E101 a E104. Igual los conceptos están
  resumidos en `apuntes/12-temas-multi-host.md`, por si toman teoría.
- **Adentro**: todo lo que se puede hacer en una sola VM.
- **Corrección después de leer los parciales anteriores**: **DHCP sí se tomó** (2025 2C),
  configurado en una sola VM: se practica con `scripts/practicar-dhcp.sh`. También salen
  siempre ejercicios con pampero o con la red del laboratorio (túnel SSH, rutas + nmap). Todos
  están resueltos en `apuntes/14-resoluciones-parciales.md`, aunque desde casa no se pueden
  probar contra los servidores reales.

## Estado de cada ejercicio

| Guía | Ejercicios | Estado |
|---|---|---|
| 1 Intro | E1, E3–E10 | Teóricos. Respuestas en `apuntes/01-unix-y-codificaciones.md` |
| | E2 copy/sendfile | **Hecho ahora**: `ejercicios/g01-intro/copy.c` + `medir.sh` |
| | E6 Unicode Java | **Hecho ahora**: `ejercicios/g01-intro/Unicode.java` |
| | E11 formato de log | **Hecho ahora**: `FORMATO-LOG.md`, `logwrite.c`, `logread.c` |
| 2 HTTP | E12–E35 | netcat, curl y teoría. Comandos en `ejercicios/g02-http/README.md` |
| | "gugul" (proxy a Google) | **Ya estaba hecho en clase**. No se tocó |
| | E36 foo/bar/what | **Hecho ahora**: sitios nginx `foo`, `bar`, `what` |
| | E37 /etc/hosts | **Hecho ahora**: `127.0.0.1 foo bar` |
| | E39 proxy reverso a Python | **Hecho ahora**: `foo-proxy` + servicio `protos-python-http` |
| | E40 gzip | **Hecho ahora**: `snippets/protos-gzip.conf` en foo y bar |
| | E41 HTTPS con mkcert | **Hecho ahora**: `https://foo` con CA local (sistema + Firefox) |
| 3 DNS | E42–E46 | Comandos dig/whois en `ejercicios/g03-dns/README.md` |
| | E47 foo.pdc.lab → protos.foo | **Hecho ahora**: DNS + nginx proxy. protos.foo hoy está caído (da 502) |
| | E48 redirección | **Hecho ahora**: `alt.foo.pdc.lab` → 302 a protos.foo |
| | E49 | No aplica en Ubuntu (son rutas de Fedora/RHEL) |
| | zonas pepito.com y cachito.com | **Hechas en clase, pero NO cargaban**. Corregidas (ver abajo) |
| | E50 zona directa + inversa | **Hecho ahora**: `foo.pdc.lab` y `2.0.10.in-addr.arpa` |
| | E51–E52 | Comandos en el README de g03 |
| | E53 usar bind como DNS del host | **Hecho ahora**: drop-in de systemd-resolved |
| | E54 forwarders | **Preparado**: bloque comentado en `named.conf.options`, con pasos para compararlos |
| 4 Correo | E57–E58 postfix + dovecot POP3 + Maildir | **Ya estaba hecho en clase**. Se agregó `foo.pdc.lab` a mydestination |
| | E59–E60 MUA | **Hecho ahora**: mutt + `~/.muttrc` (SMTP a postfix, lee Maildir/POP3) |
| | E63–E69 base64/QP/MIME | Resueltos en `apuntes/05-correo-smtp-pop3-mime.md`. Imagen de E65 en `g04-correo/` |
| 5 Telnet | E71 | **Estaba hecho en clase, pero roto**. Corregido (ver abajo) |
| 6 Transporte | E72, E75, E76 xinetd echo/daytime/time | **Ya estaba hecho en clase** (TCP y UDP habilitados) |
| | E73, E74, E77, E78 | Comandos en `ejercicios/g06-transporte/README.md` |
| 7 IP | E79–E81 traceroute, E85 reject, E86 alias | Comandos en `ejercicios/g07-ip/README.md` |
| 11 SSH | E99 (fingerprint local), E100 login sin contraseña | **Hecho ahora**: `ssh localhost` con clave |

## Qué se corrigió de lo que ya estaba

1. **bind9 no cargaba `pepito.com` ni `cachito.com`.** En `named.conf.local` el path era
   `/etc/bind/bind/zones/...` (con `bind` dos veces). Ahora es `/etc/bind/zones/...`.
2. **`cachito.com` tenía `@ IN CNAME ipv6`.** Un CNAME en el apex es inválido porque ahí ya
   hay SOA, NS y MX ("CNAME and other data"). Se reemplazó por `@ IN AAAA ::1` y se subió
   el serial.
3. **telnet por xinetd ejecutaba el cliente.** Decía `server = /usr/bin/telnet` (el
   cliente), así que la conexión se cerraba enseguida. Ahora es `/usr/sbin/telnetd`.

## Qué se cambió en el sistema (para poder deshacerlo)

| Qué | Dónde |
|---|---|
| Paquetes nuevos | `curl` (apt, además del snap), `mkcert`, `libnss3-tools`, `mutt`, `build-essential`, `default-jdk-headless`, `tshark` |
| Grupo `wireshark` | Tu usuario quedó en el grupo: Wireshark captura sin sudo (hay que cerrar sesión y volver a entrar) |
| nginx | Sitios `foo`, `foo-proxy`, `bar`, `what`, `foo.pdc.lab`, `alt.foo.pdc.lab`. Se sacó de sites-enabled el `default`, pero el archivo sigue en sites-available. Certificados en `/etc/nginx/ssl/` |
| Webs | `/var/www/foo`, `/var/www/bar`, `/var/www/what`, `/srv/protos-python` |
| Servicio | `protos-python-http.service` (python http.server en 127.0.0.1:8080) |
| bind9 | `named.conf.options`, `named.conf.local`, zonas `db.foo.pdc.lab`, `db.10.0.2` y `db.cachito.com.local` |
| DNS del sistema | `/etc/systemd/resolved.conf.d/protos-bind.conf` |
| /etc/hosts | Bloque `PROTOS-E37` |
| postfix | `foo.pdc.lab` agregado a `mydestination` |
| xinetd | `/etc/xinetd.d/telnetd` |
| mkcert | CA local en `~/.local/share/mkcert`, instalada en el sistema y en Firefox |
| SSH | `~/.ssh/id_ed25519` (E100) en `authorized_keys`, y la clave de la Mac (`claude-ubuntua`) |
| sudo | `/etc/sudoers.d/90-claude-nopasswd`: sudo sin contraseña. **Borralo cuando termines**: `sudo rm /etc/sudoers.d/90-claude-nopasswd` |

## Material de terceros

Estos archivos están en la copia local pero **no se suben al repo**, porque son copias
textuales de material de otros (el repo
[rodrihern/Protos-ITBA](https://github.com/rodrihern/Protos-ITBA) no tiene licencia):

- `referencias/Cheatsheet_lab_ip.pdf`: el cheatsheet del laboratorio de IP de la cátedra.
  Original: [`practica/Cheatsheet_lab_ip.pdf`](https://github.com/rodrihern/Protos-ITBA/blob/main/practica/Cheatsheet_lab_ip.pdf).
- `recu/Ejercicio_integrador.md` y sus 2 imágenes. Original:
  [`practica/Ejercicio_integrador.md`](https://github.com/rodrihern/Protos-ITBA/blob/main/practica/Ejercicio_integrador.md).
  La copia local usa `192.168.123.200` en lugar de `192.168.124.80` y `192.168.124.53`. Para
  armarla desde el original:
  `perl -pe 's/192\.168\.124\.(80|53)(?!\d)/192.168.123.200/g' Ejercicio_integrador.md > recu/Ejercicio_integrador.md`

Los apuntes sí se basan en ese repo, en la guía práctica de la cátedra y en el simulacro
de Mateo Andrioli, pero con resoluciones propias, probadas en la VM y citando de dónde sale
cada cosa.

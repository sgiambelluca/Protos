# Hoja de Comandos — Parte Práctica Protocolos

<p class="meta"><span>12 nov 2026</span> · <span>Protocolos de Comunicación (72.07)</span></p>

Todos los comandos que usamos en la práctica, por tema: la **sintaxis**, las **opciones** que
importan y **para qué sirve** cada una. `<algo>` = completar, `[algo]` = opcional, `a|b` = una
de las dos. Probá siempre con `curl`, nunca con el navegador (HSTS en `*.foo`). El detalle y los
ejercicios resueltos están en los apuntes 01 a 20.

## 0. Sistema, servicios y archivos

### Root y servicios (systemd)

```bash
sudo -i                                   # shell de root (no hace falta sudo en cada línea)
systemctl status <servicio>               # ¿corre? + las últimas líneas del log
sudo systemctl start|stop|restart|reload <servicio>
sudo systemctl enable --now <servicio>    # arrancarlo ya y en cada booteo
journalctl -u <servicio> -n 50            # log de una unidad
journalctl -xeu <servicio>                # el error explicado, al final (cuando no arranca)
sudo apt install <paquete>
```

| Opción | Para qué |
|---|---|
| `restart` | para y arranca: corta conexiones y, si la config está mal, queda **caído** |
| `reload` | relee la config sin cortar a nadie. Si la config nueva es inválida, sigue con la vieja |
| `enable --now` | lo habilita al arranque y lo arranca ahora |
| `journalctl -u X` | log de esa unidad |
| `-f` | seguir el log en vivo |
| `-n 50` | últimas 50 líneas |
| `-b` | desde el último booteo |
| `-x -e` | agrega explicaciones y salta al final |

### Validar la config antes de aplicarla

| Servicio | Unidad | Validar | Aplicar |
|---|---|---|---|
| nginx | `nginx` | `sudo nginx -t` (`-T` = mostrar la config completa) | `systemctl reload nginx` |
| bind9 | `named` (= `bind9`) | `named-checkconf -z` · `named-checkzone <zona> <archivo>` | `rndc reload` |
| DHCP | `isc-dhcp-server` | `dhcpd -t -cf /etc/dhcp/dhcpd.conf` | `systemctl restart isc-dhcp-server` |
| postfix | `postfix` | `sudo postfix check` | `systemctl reload postfix` |
| dovecot | `dovecot` | `sudo doveconf -n` | `systemctl restart dovecot` |
| ssh | `ssh` | `sudo sshd -t` | `systemctl reload ssh` |
| xinetd | `xinetd` | `journalctl -u xinetd` | `systemctl restart xinetd` |

### Puertos y procesos

```bash
sudo ss -tulpn             # quién escucha en qué puerto (y qué proceso)
ss -tan                    # conexiones TCP con su estado (ESTABLISHED, TIME_WAIT...)
ss -tan state time-wait    # filtrar por estado
netstat -tulpn             # lo mismo con net-tools (más viejo)
```

| Opción | Para qué |
|---|---|
| `-t` / `-u` | TCP / UDP |
| `-l` | sólo los sockets en escucha (LISTEN) |
| `-a` | todos: en escucha y conexiones |
| `-p` | proceso dueño del socket (necesita sudo) |
| `-n` | numérico: no traduce puertos ni IPs a nombres |

### Editar archivos de /etc

```bash
sudo nano /etc/hosts
echo "127.0.0.1 sitio" | sudo tee -a /etc/hosts     # agregar una línea sin abrir el editor
#   "sudo echo ... >> /etc/hosts" NO anda: la redirección la hace tu shell, que no es root
sudo tee /etc/nginx/sites-available/x <<'EOF'
server { ... }
EOF
#   un archivo entero desde la terminal ('EOF' entre comillas: no expande las $variables)
```

- **nano**: `Ctrl+O` guardar · `Ctrl+X` salir · `Ctrl+W` buscar · `Ctrl+_` ir a la línea N ·
  `Ctrl+K` / `Ctrl+U` cortar / pegar la línea · `Alt+U` deshacer.
- **vim**: `i` escribir → `Esc` → `:wq` guardar y salir · `:q!` salir sin guardar · `/texto`
  buscar · `:45` ir a la línea 45 · `dd` borrar la línea · `u` deshacer · `:set paste` antes de pegar.

### Buscar, seguir archivos y resolver nombres

```bash
grep -rn "texto" /etc/nginx/    # buscar en una carpeta
tail -f archivo                  # mostrar lo que se va agregando (Ctrl-C para salir)
tail -F archivo                  # igual, pero lo reabre si lo rotan
getent hosts <nombre>            # cómo resuelve el sistema (/etc/hosts + DNS), igual que curl
```

| Opción | Para qué |
|---|---|
| `grep -r` | recursivo (entra a las subcarpetas) |
| `grep -n` / `-i` / `-l` | número de línea / sin distinguir mayúsculas / sólo el nombre del archivo |
| `tail -f` / `-F` | seguir el archivo / seguirlo aunque lo roten |
| `tail -n 50` | últimas 50 líneas |

## 1. Red base: interfaces, rutas, forwarding y NAT

### ip (iproute2)

```bash
sudo systemctl stop NetworkManager.service      # antes de configurar a mano (si no, te pisa)
ip -br addr                                     # resumen: interfaz, estado, IPs
ip -br link                                     # interfaces y MAC (para ver cómo se llaman)
ip addr                                         # detalle
sudo ip addr add 192.168.100.1/24 dev enp0s8    # asignar una IP (se pierde al reiniciar)
sudo ip addr del 192.168.100.1/24 dev enp0s8    # sacarla
sudo ip link set enp0s8 up                      # prender la interfaz (down = apagarla)
ifconfig                                        # sintaxis vieja: = ip addr
sudo ifconfig enp0s8 192.168.0.18/24            # sintaxis vieja: asignar IP
```

| Subcomando / opción | Para qué |
|---|---|
| `ip addr` (`ip a`) | las IPs de cada interfaz |
| `-br` | salida breve: una línea por interfaz |
| `addr add <ip>/<bits> dev <if>` | agrega una IP. Puede haber varias por interfaz |
| `link set <if> up\|down` | prende / apaga la interfaz |
| `ip neigh` | tabla ARP (ver §2) |

### Tabla de ruteo

```bash
ip route                                          # = route -n = netstat -rn
ip route get 10.0.0.5                             # qué ruta usaría: via (gateway), dev, src
sudo ip route add 10.0.0.0/24 via 192.168.80.250  # la red de atrás de un gateway (LA clave)
sudo ip route add default via 192.168.1.1         # gateway por defecto
sudo ip route del 10.0.0.0/24
sudo ip route add unreachable 192.168.14.0/27     # rechazar (devuelve ICMP unreachable)
sudo ip route add blackhole 192.168.14.0/27       # descartar en silencio
route -n                                          # sintaxis vieja (net-tools)
sudo route add -net 10.0.0.0/24 gw 192.168.80.250
sudo route add default gw 192.168.1.1
```

| Opción | Para qué |
|---|---|
| `via <gw>` | el próximo salto. Tiene que estar en una red conectada ("Nexthop has invalid gateway") |
| `dev <if>` | por qué interfaz sale (sin `via` = la red está conectada directo) |
| `default` | = `0.0.0.0/0`, la ruta menos específica |
| `route get <ip>` | qué ruta elige el kernel para ese destino |

- Gana la ruta **más específica** (*longest prefix match*): `/32` > `/24` > `default`.
- Para que dos redes se hablen hace falta ruta de **ida y de vuelta** (o NAT).
- Diagnóstico rápido: `ping`, después `ip route` / `route -n`. Si no llega, casi siempre falta una ruta.

### Forwarding (que el host rutee)

```bash
sysctl net.ipv4.ip_forward                # ver: 0 = host, 1 = router
sudo sysctl -w net.ipv4.ip_forward=1      # activarlo (persistente: en /etc/sysctl.d/*.conf)
```

### NAT con iptables

```bash
sudo iptables -t nat -L -n -v --line-numbers                   # ver las reglas, numeradas
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE     # SNAT: salir con la IP de este host
sudo iptables -t nat -A PREROUTING -i enp0s3 -p tcp --dport 8080 \
     -j DNAT --to-destination 192.168.100.10:80                 # DNAT: exponer un servicio interno
sudo iptables -t nat -D POSTROUTING 1                           # borrar la regla nº 1
sudo iptables -t nat -F                                         # borrar todas las reglas NAT
```

| Opción | Para qué |
|---|---|
| `-t nat` | tabla NAT (sin `-t` se usa `filter`, la del firewall) |
| `-A <cadena>` / `-I <cadena>` | agregar la regla al final / insertarla al principio |
| `-D <cadena> <n>` | borrar la regla número n |
| `-L -n -v --line-numbers` | listar, numérico, con contadores y número de regla |
| `-F` | *flush*: borrar todas las reglas de la tabla |
| `POSTROUTING` | después de rutear: ahí va el **SNAT / MASQUERADE** |
| `PREROUTING` | antes de rutear: ahí va el **DNAT** |
| `-o <if>` / `-i <if>` | interfaz de salida / de entrada |
| `-p tcp --dport N` | protocolo y puerto destino |
| `-j MASQUERADE` | cambia la IP origen por la de la interfaz de salida |
| `-j DNAT --to-destination ip:puerto` | cambia el destino |

> **Regla mental**: si "X hace NAT", su red queda oculta y nadie necesita una ruta hacia ella.
> Si X **no** hace NAT, los demás sí necesitan una ruta hacia esa red.

### ping y traceroute

```bash
ping -c 4 <ip>                     # conectividad básica (sin -c sigue hasta Ctrl-C)
ping -M do -s 1472 <ip>            # Don't Fragment: 1472 + 8 ICMP + 20 IP = 1500 (prueba de MTU)
traceroute -n <ip>                 # los routers del camino, sin DNS inverso
sudo traceroute -I <ip>            # sondas ICMP (como el tracert de Windows)
sudo traceroute -T -p 80 <ip>      # sondas TCP SYN al 80: pasan firewalls que tiran UDP
traceroute <ip> 4000               # paquetes de 4000 bytes: fuerza la fragmentación
```

| Opción | Para qué |
|---|---|
| `ping -c N` | mandar N y terminar |
| `ping -s N` | tamaño de los datos |
| `ping -M do` | prende el bit DF (no fragmentar) |
| `ping -I <if>` | salir por esa interfaz |
| `traceroute -n` | no resolver nombres (más rápido) |
| `traceroute -I` / `-T` | ICMP / TCP en lugar de UDP (el default: UDP a los puertos 33434+) |
| `traceroute -p N` | puerto destino |
| `traceroute -m N` | TTL máximo (cantidad de saltos) |
| número al final | tamaño del paquete |

Cada router responde **ICMP Time Exceeded** cuando el TTL llega a 0; el destino responde
Port Unreachable (o Echo Reply con `-I`). Un `*` = ese salto no contestó (no manda ICMP, un
firewall lo filtra o hay rate limit).

### Interfaces virtuales (practicar sin tocar la red)

```bash
sudo ip link add veth-srv type veth peer name veth-cli   # par veth: un "cable" con dos puntas
sudo ip addr add 192.168.90.1/24 dev veth-srv
sudo ip link set veth-srv up && sudo ip link set veth-cli up
sudo ip link del veth-srv                                # borra las dos puntas
```

## 2. Enlace: ARP

```bash
ip neigh                       # tabla ARP: IP ↔ MAC (REACHABLE, STALE, PERMANENT...) = arp -n
arp -n                         # -n: sin resolver nombres (-a: formato BSD)
sudo arp -s <ip> <mac>         # entrada estática (= ip neigh add <ip> lladdr <mac> dev <if>)
sudo arp -d <ip>               # borrarla          = ip neigh del <ip> dev <if>
sudo ip neigh flush all        # vaciar la tabla
```

**arping** (paquete `arping`): manda pedidos ARP a mano. No toca tu tabla.

```bash
sudo arping -I enp0s8 <ip>                          # ¿alguien tiene esta IP? (responde su MAC)
sudo arping -I enp0s8 -S <ip_router> <ip_victima>   # ARP haciéndome pasar por el router
```

| Opción | Para qué |
|---|---|
| `-I <if>` | interfaz por la que sale |
| `-c N` | cantidad de pedidos |
| `-S <ip>` / `-s <mac>` | IP / MAC **origen** que figura en el ARP |
| `-T <ip>` / `-t <mac>` | IP / MAC **destino** |

**ARP spoofing / MITM** (meterme entre la víctima y el router, sólo con consentimiento):

```bash
sudo sysctl -w net.ipv4.ip_forward=1                    # reenviar el tráfico de la víctima
sudo arping -I enp0s8 -S <ip_router> <ip_victima>       # "el router soy yo"
sudo iptables -t nat -A POSTROUTING -j MASQUERADE       # para que las respuestas vuelvan
```

- El request va por **broadcast** (`ff:ff:ff:ff:ff:ff`) y el reply por unicast. Para un destino
  de otra red se hace ARP de la IP **del gateway**.
- En cada salto cambian las **MAC**, **no** las IP; el **TTL** baja 1.
- Para ver tráfico ajeno en Wireshark: adaptador en **modo promiscuo** (Allow All).

## 3. Transporte: netcat, ncat, telnet y nmap

### nc (netcat-openbsd, el de Ubuntu)

```bash
nc -C host 80                      # cliente TCP; -C = líneas con CRLF (HTTP, SMTP, POP3)
nc -l 9090                         # servidor: escucha en el 9090 y muestra lo que llega
nc -l 127.0.0.1 8099 > archivo     # escuchar sólo en loopback y guardar lo que llega
nc -u localhost 7                  # UDP (el echo de xinetd)
nc -zv localhost 20-100            # qué puertos aceptan conexión
nc -X 5 -x proxy:1080 host 80      # a través de un proxy SOCKS5
printf 'GET / HTTP/1.1\r\nHost: foo\r\n\r\n' | nc -q 2 localhost 80   # pedido en una línea
```

| Opción | Para qué |
|---|---|
| `-l` | escuchar (modo servidor) |
| `-C` | terminar cada línea con CRLF: **obligatorio** para HTTP/SMTP/POP3 a mano |
| `-u` | UDP en lugar de TCP |
| `-v` | verbose: dice si conectó o el error |
| `-z` | sólo probar si el puerto acepta, sin mandar datos |
| `-k` | con `-l`: seguir escuchando después de la primera conexión |
| `-q N` / `-N` | cerrar N segundos después del EOF de stdin / cerrar la escritura al EOF |
| `-w N` | timeout de N segundos |
| `-X 5 -x host:puerto` | usar un proxy SOCKS5 (`-X connect` = proxy HTTP) |

`Ctrl+D` = EOF: nc manda FIN (cierra su mitad) y puede seguir recibiendo (*half-close*).

### ncat (el de nmap)

```bash
ncat -l 8080 -k -c "cat"                    # echo server
ncat -l 127.0.0.1 3333 -k -c "echo hola"    # atado a una IP (en las otras el puerto queda libre)
ncat 127.0.0.1 3333 --recv-only             # cliente que sólo recibe
ncat --sctp host 9999                        # SCTP
ncat -l 1234 -k -c 'printf "HTTP/1.1 302 Found\r\nLocation: http://localhost:1234\r\n\r\n"'
```

| Opción | Para qué |
|---|---|
| `-l` | escuchar |
| `-k` | aceptar varias conexiones (no muere después de la primera) |
| `-c "cmd"` / `-e prog` | correr un comando por conexión, con el socket como stdin/stdout |
| `--recv-only` / `--send-only` | sólo recibir / sólo enviar |
| `-u` / `--sctp` | UDP / SCTP |
| `-C` | CRLF |
| `--proxy host:puerto --proxy-type socks5` | conectarse por un proxy |

### telnet

```bash
telnet localhost 23        # terminal remota (todo viaja en texto plano, contraseña incluida)
telnet host 80             # también sirve como cliente TCP genérico
#   salir: Ctrl-]  y después  quit
```

### nmap

```bash
sudo nmap -sn 10.0.0.0/24                  # qué hosts están vivos (sin escanear puertos)
sudo nmap -sS -sV -Pn 10.0.0.5             # puertos abiertos + versión de cada servicio
nmap -p 13,22,25,80 -sV <ip>               # puertos puntuales
sudo nmap -Pn -n --open -p- <ip>           # los 65535 puertos, mostrando sólo los abiertos
sudo nmap -Pn -n --open -p49000-50000 <ip> # un rango
sudo nmap -sU -p 53,67 <ip>                # UDP (lento)
sudo nmap -A <ip>                          # agresivo: versiones + SO + scripts + traceroute
sudo nmap --script broadcast-dhcp-discover -e veth-cli \
     --script-args broadcast-dhcp-discover.mac=AA:BB:CC:DD:EE:FF   # simular un cliente DHCP
```

| Opción | Para qué |
|---|---|
| `-sn` | sólo descubrir hosts (*ping sweep*) |
| `-sS` | SYN scan, *half-open* (el default con root) |
| `-sT` | connect scan: handshake completo (sin root; queda en los logs) |
| `-sU` | UDP |
| `-sV` | versión del servicio (banner) |
| `-O` / `-A` | detectar el SO / agresivo (`-sV -O` + scripts + traceroute) |
| `-Pn` | no hacer el ping previo: escanea aunque el host no responda ICMP |
| `-n` | no resolver DNS inverso |
| `-p 22,80` / `-p 1-1000` / `-p-` | puertos puntuales / un rango / todos |
| `--open` | mostrar sólo los abiertos |
| `--top-ports N` | los N puertos más comunes |
| `-T4` | más rápido (`-T0` muy lento … `-T5` muy agresivo; default `-T3`) |
| `--script <nombre>` / `--script-args` | scripts NSE (`/usr/share/nmap/scripts/`) |
| `-e <if>` | interfaz por la que sale |
| `-oN archivo` | guardar la salida |

Estados: `open` (vuelve SYN/ACK) · `closed` (vuelve RST) · `filtered` (no vuelve nada:
firewall) · `open|filtered` (UDP sin respuesta). Antes de escanear una red de atrás: **la ruta** (§1).

## 4. HTTP: curl, wget y HTTP a mano

### curl

```bash
curl http://sitio/                          # GET, el cuerpo sale por stdout
curl -v http://sitio/                       # pedido + respuesta completos (> enviado, < recibido)
curl -i http://sitio/                       # incluye los headers de la respuesta
curl -I http://sitio/                       # sólo los headers (HEAD)
curl -H "Host: bar" http://127.0.0.1/       # elegir el virtual host sin tocar /etc/hosts
curl -X POST http://api/x -H "Content-Type: application/json" -d '{"k":"v"}'
curl -u user:pass http://sitio/             # Basic auth (arma solo el header Authorization)
curl -L http://sitio/                       # seguir las redirecciones (3xx + Location)
curl -o archivo URL                         # guardar con ese nombre (-O: con el nombre remoto)
curl -k https://sitio/                      # no verificar el certificado (sólo para probar)
```

| Opción | Para qué |
|---|---|
| `-v` | verbose: pedido, respuesta y handshake TLS |
| `-i` | headers de la respuesta + cuerpo |
| `-I` | sólo headers (método HEAD) |
| `-s` | silencioso (sin barra de progreso) |
| `-H "Clave: valor"` | agregar o pisar un header (`-H "Clave:"` lo saca) |
| `-X MÉTODO` | método: GET, POST, PUT, DELETE, OPTIONS, TRACE... |
| `-d 'datos'` | cuerpo. Implica POST y `Content-Type: application/x-www-form-urlencoded` |
| `-u user:pass` | Basic auth |
| `-L` | seguir redirects |
| `-o archivo` / `-O` | guardar en un archivo / con el nombre del servidor |
| `-x <proxy>` | usar un proxy: `http://`, `socks5://` o `socks5h://` |
| `-k` | aceptar cualquier certificado |
| `--compressed` | pedir gzip y descomprimir |
| `-r 0-99` | pedir sólo esos bytes (Range → 206) |
| `-b "k=v"` / `-c jar.txt` | mandar cookies / guardar las que llegan |
| `-A "agente"` | User-Agent |
| `--http1.1` / `--http2` | forzar la versión |

### Proxies (HTTP y SOCKS)

```bash
curl -x http://proxy.protos.foo:3126 http://hackerspace.protos.foo:8090/      # proxy HTTP
curl -x socks5h://proxy.protos.foo:1080 \
     -H "Accept: text/plain" -H "Accept-Language: es" \
     -u admin:secret123 http://recurso.protos.foo:8080/data/       # SOCKS + negociación + auth
ssh -fN -D 1080 user@host && curl -x socks5h://localhost:1080 URL    # tu propio SOCKS (§10)
echo YWRtaW46c2VjcmV0MTIz | base64 -d       # el <b64> de "Authorization: Basic" → admin:secret123
```

- `socks5h` (con **h**): el nombre lo resuelve **el proxy**. Usalo cuando el host sólo existe en
  la red del proxy. `socks5` sin h lo resuelve tu máquina. (= `--socks5-hostname` / `--socks5`.)
- Con un proxy HTTP el pedido sale en forma absoluta (`GET http://host/... HTTP/1.1`).

### Negociación de contenido y caché condicional

```bash
curl -i URL -H "Accept-Language: es"                # idioma (vuelve Content-Language)
curl -i URL -H "Accept: application/json"           # tipo (vuelve Content-Type)
curl -sI URL                                        # leer ETag y Last-Modified
curl -I URL -H 'If-None-Match: "6adf8f87-68c7"'     # → 304 si no cambió
curl -I URL -H "If-Modified-Since: Thu, 13 Mar 2025 19:51:16 GMT"   # → 304
curl -sI -H "Accept-Encoding: gzip" URL             # ¿comprime? (Content-Encoding: gzip)
```

### HTTP a mano y servidores rápidos

```bash
nc -C localhost 80                  # y después escribís:
GET / HTTP/1.1
Host: localhost
                                    # línea vacía = fin de los headers
nc -l 9090                          # "servidor": ver qué manda un cliente (curl localhost:9090)
python3 -m http.server 8000         # servir la carpeta actual (sin index.html, lista los archivos)
```

Sin `nc -C`: `Ctrl+V` y después `Enter` escribe el `\r` a mano.

### wget

```bash
wget -O backup.pcapng http://192.168.0.238:8000/backup.pcapng   # guardar con ese nombre
wget -c URL          # continuar una descarga cortada (usa Range)
wget -S URL          # mostrar los headers de la respuesta
wget -r URL          # recursivo (espejar un sitio)
```

Para bajar un archivo binario (una captura, una clave): `wget -O` o `curl -o`, **nunca** `curl -i`
(los headers HTTP quedan adentro del archivo). Después `file archivo` para confirmar el tipo.

### Códigos de estado

| Código | Significado |
|---|---|
| 200 · 201 · 204 · 206 | OK · Created · No Content · Partial Content (Range) |
| 301 · 302 · 304 | permanente · temporal · Not Modified (caché condicional) |
| 307 · 308 | temporal / permanente **sin cambiar el método** |
| 400 · 401 · 403 · 404 | mal formado (ej. sin `Host`) · falta autenticarse · prohibido · no existe |
| 405 · 415 | método no permitido (`Allow:`) · tipo no soportado |
| 502 · 503 · 504 | el proxy no pudo hablar con el backend · no disponible · el backend no contestó a tiempo |

## 5. nginx

### Comandos y archivos

```bash
sudo nano /etc/nginx/sites-available/sitio
sudo ln -s /etc/nginx/sites-available/sitio /etc/nginx/sites-enabled/   # habilitar el sitio
sudo rm /etc/nginx/sites-enabled/sitio                                  # deshabilitarlo
echo "127.0.0.1 sitio" | sudo tee -a /etc/hosts                         # que el nombre resuelva
sudo nginx -t && sudo systemctl reload nginx                            # validar y recargar
sudo nginx -T | less                                                    # la config completa cargada
curl -v http://sitio/
sudo tail -f /var/log/nginx/error.log                                   # 502, permisos, upstream
```

| Archivo | Para qué |
|---|---|
| `/etc/nginx/sites-available/` | un archivo por sitio (no se carga solo) |
| `/etc/nginx/sites-enabled/` | symlinks a los de available: lo que se carga |
| `/etc/nginx/nginx.conf` | el principal (incluye `conf.d/` y `sites-enabled/`) |
| `/var/log/nginx/access.log` · `error.log` | un pedido por línea · errores |
| `/var/www/` | contenidos |

### Directivas

| Directiva | Para qué |
|---|---|
| `listen 80;` / `listen 443 ssl;` | puerto (y TLS) |
| `listen 80 default_server;` | atiende cuando ningún `server_name` coincide |
| `listen 127.0.0.1:80;` | elegir el sitio por la IP destino, no por el nombre |
| `server_name a b *.foo;` | los nombres (header `Host`) de este sitio. `_` = ninguno |
| `root /var/www/x;` | carpeta: el archivo es root + URI |
| `alias /data/;` | reemplaza el prefijo de la location |
| `index index.html;` | qué archivo servir cuando piden una carpeta |
| `location / { }` | prefijo (gana el más largo) |
| `location = /x { }` | coincidencia exacta (ojo: `= /` sólo atiende `/`) |
| `location ~ \.php$ { }` / `~*` | regex sensible / insensible a mayúsculas |
| `location ^~ /static/ { }` | prefijo que gana a las regex |
| `try_files $uri $uri/ =404;` | probar el archivo, después la carpeta, si no 404 |
| `proxy_pass http://backend;` | proxy reverso: la URL que ve el usuario no cambia |
| `proxy_set_header Clave valor;` | agregar o pisar un header hacia el backend |
| `proxy_ssl_server_name on;` | mandar SNI cuando el backend es HTTPS (sin esto: 502) |
| `return 302 http://x$request_uri;` | redirect (la URL cambia) |
| `return 200 "texto\n";` + `default_type text/plain;` | respuesta fija sin archivos |
| `rewrite ^/viejo/(.*)$ /nuevo/$1 permanent;` | redirect con regex (`permanent` = 301, `redirect` = 302) |
| `ssl_certificate` / `ssl_certificate_key` | certificado (público) / clave privada |
| `gzip on;` + `gzip_types text/plain application/json;` | comprimir |

Variables: `$host` (el Host del pedido) · `$request_uri` (URI original con query) · `$uri` ·
`$remote_addr` · `$scheme` · `$proxy_host` · `$http_x_mi_header` (el header `X-Mi-Header` del cliente).

### Plantillas

```nginx
server {                                    # vhost estático
    listen 80;
    server_name sitio;
    root /var/www/sitio;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
```

```nginx
server {                                    # proxy reverso
    listen 80;
    server_name metadata.local;             # lo que escribe el usuario (+ /etc/hosts → 127.0.0.1)
    location / {
        proxy_pass http://metadata.protos.foo;      # sin "/" final: la URI pasa tal cual
        proxy_set_header Metadata true;             # agregar un header que el cliente no manda
        proxy_set_header Accept application/json;   # pisar uno que sí manda
        # NO pongas "proxy_set_header Host $host;" si el backend es otro sitio con nombre
    }
}
```

```nginx
server {                                    # HTTPS delante de un HTTP (certificado en §6)
    listen 443 ssl;
    server_name seguro.protos.foo;
    ssl_certificate     /etc/ssl/certs/seguro.crt;
    ssl_certificate_key /etc/ssl/private/seguro.key;
    location / { proxy_pass http://interno.protos.foo; }
}

server {                                    # redirect de dominio (cuando SÍ cambia la URL)
    listen 80;
    server_name viejo.foo;
    return 302 http://nuevo.foo$request_uri;
}
```

- `proxy_pass http://b:8080;` (sin URI) manda `/app/x` tal cual. `proxy_pass http://b:8080/;`
  (con `/`) reemplaza el prefijo de la location.
- nginx ya reenvía los headers del cliente (salvo los que tienen `_`) y por defecto manda
  `Host` = el nombre del upstream, que es lo que necesita un backend con virtual hosts.
- Si el upstream no resuelve, nginx **no arranca** ("host not found in upstream"). Antes:
  `getent hosts <backend>`. Si no resuelve, agregalo a `/etc/hosts` (nunca apuntando a 127.0.0.1).

| Error | Causa |
|---|---|
| `unexpected "}"` / `... sites-enabled/x:12` | falta un `;` en la línea anterior |
| `a duplicate default server` | dos `default_server` en el mismo puerto |
| `conflicting server name` | dos sitios con el mismo `server_name` (se usa el primero) |
| `Address already in use` | otro proceso en el puerto → `sudo ss -tlnp` |
| 403 | no hay index o www-data no puede leer |
| 502 | backend caído o puerto equivocado → `error.log` |

## 6. TLS y certificados

```bash
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
     -keyout /etc/ssl/private/seguro.key -out /etc/ssl/certs/seguro.crt \
     -subj "/CN=seguro.protos.foo" -addext "subjectAltName=DNS:seguro.protos.foo"
sudo cp /etc/ssl/certs/seguro.crt /usr/local/share/ca-certificates/seguro.crt   # .crt obligatorio
sudo update-ca-certificates            # al trust store del sistema ("1 added") → curl sin -k
openssl x509 -in /etc/ssl/certs/seguro.crt -noout -subject -issuer -dates -ext subjectAltName
openssl s_client -connect 127.0.0.1:443 -servername seguro.protos.foo </dev/null   # el handshake
```

| Opción de `openssl req` | Para qué |
|---|---|
| `-x509` | certificado autofirmado directo (sin CSR) |
| `-newkey rsa:2048` | generar la clave |
| `-nodes` | clave **sin passphrase** (si no, nginx no la puede leer solo) |
| `-days N` | validez |
| `-keyout` / `-out` | dónde guardar la clave privada / el certificado |
| `-subj "/CN=nombre"` | nombre del sujeto |
| `-addext "subjectAltName=DNS:nombre"` | **SAN**: lo exigen los navegadores |

**mkcert** (una CA local que también queda en los navegadores):

```bash
mkcert -install                      # crea la CA y la instala en el sistema y en Firefox/Chrome
mkcert foo bar localhost 127.0.0.1   # foo+3.pem (certificado) + foo+3-key.pem (clave)
mkcert -CAROOT                       # dónde quedó la CA
```

- `curl` usa el trust store **del sistema**; los navegadores, el suyo (mkcert los instala; a
  Firefox hay que reiniciarlo).
- `ssl_certificate` = el `.pem`/`.crt` (público); `ssl_certificate_key` = la clave (privada,
  permisos 600). Invertirlos da error al cargar.

## 7. DNS: dig y bind9

### dig y compañía

```bash
dig [@servidor] <nombre> [tipo] [+opciones]
dig www.itba.edu.ar                       # A por defecto
dig MX itba.edu.ar +short                 # a qué servidor mandar mail (sólo los datos)
dig @127.0.0.1 mizona.foo SOA             # preguntarle a un servidor puntual
dig -x 10.0.2.15                          # inversa (PTR)
dig +trace pampero.it.itba.edu.ar         # resolución paso a paso desde la raíz
dig +norec @127.0.0.1 mizona.foo ANY      # sin recursión: sólo lo que sabe ese server
dig @127.0.0.1 mizona.foo AXFR            # la zona entera (necesita allow-transfer)
dig +noall +answer @127.0.0.1 mizona.foo MX
host -t MX itba.edu.ar                    # versión corta
nslookup -type=SOA itba.edu.ar 8.8.8.8
whois itba.edu.ar                         # datos de registro del dominio (no es DNS)
resolvectl status                         # qué DNS usa el sistema (127.0.0.53 = systemd-resolved)
```

| Opción | Para qué |
|---|---|
| `@ip` | a qué servidor preguntar (si no, al de `/etc/resolv.conf`) |
| tipo | `A` `AAAA` `NS` `MX` `SOA` `TXT` `CNAME` `PTR` `ANY` `AXFR` |
| `-x <ip>` | consulta inversa |
| `+short` | sólo los datos |
| `+trace` | iterativa desde la raíz, mostrando cada referral |
| `+norec` | sin pedir recursión |
| `+noall +answer` | sólo la sección ANSWER |
| `+tcp` / `-p N` | por TCP / a otro puerto |

Leer la salida: **`status:`** NOERROR · NXDOMAIN (el nombre no existe) · SERVFAIL (zona rota) ·
REFUSED. **`flags:`** `aa` = autoritativa (tu zona cargó), `rd` / `ra` = recursión pedida /
disponible. Secciones: ANSWER · AUTHORITY (el SOA en un NXDOMAIN) · ADDITIONAL (las A de los NS y
MX). El número después del nombre es el **TTL**. `dig` no mira `/etc/hosts`; `getent`, `ping` y `curl` sí.

### bind9

```bash
sudo named-checkconf                         # sintaxis de named.conf*
sudo named-checkconf -z                      # + intenta cargar cada zona
named-checkzone mizona.foo /etc/bind/db.mizona.foo
sudo systemctl reload named                  # (o bind9)
sudo rndc reload [zona]                      # recargar una zona cuyo archivo cambió
sudo rndc reconfig                           # cargar zonas NUEVAS (no recarga las que cambiaron)
sudo rndc flush                              # vaciar la caché
sudo rndc dumpdb -cache                      # volcar la caché en /var/cache/bind/named_dump.db
journalctl -u named -n 30                    # "zone ... loaded serial N" o el error
```

| Archivo | Para qué |
|---|---|
| `/etc/bind/named.conf.local` | tus zonas (bloques `zone`) |
| `/etc/bind/named.conf.options` | recursión, forwarders, listen-on |
| `/etc/bind/db.<zona>` o `/etc/bind/zones/` | archivos de zona |

```c
// /etc/bind/named.conf.local
zone "mizona.foo" {
    type master;
    file "/etc/bind/db.mizona.foo";
    allow-transfer { 127.0.0.1; };     // para poder comparar con dig AXFR
};
// named.conf.options:  forwarders { 8.8.8.8; 1.1.1.1; };  forward only;
```

Archivo de zona. Sintaxis: `nombre [ttl] IN tipo [prioridad] valor`

```dns
$TTL 1h
$ORIGIN mizona.foo.
@   IN SOA ns1.mizona.foo. admin.mizona.foo. (
        2026111201 ; serial  (AAAAMMDDnn: SUBIRLO en cada cambio)
        1h         ; refresh
        15m        ; retry
        1w         ; expire  (siempre > refresh + retry)
        5m )       ; minimum (TTL del caché negativo)
@       IN NS     ns1
ns1     IN A      192.0.2.10                  ; todo NS y MX necesita su A
@       IN MX 10  mail                        ; menor número = más prioridad
mail    IN A      192.0.2.20
@       IN A      192.0.2.30
www     IN CNAME  @                           ; alias: nunca en el apex ni junto a otro registro
ext     IN CNAME  www.google.com.             ; nombre de afuera: punto final obligatorio
meme 864000 IN TXT "https://xkcd.com/927/"    ; TTL propio
@       IN TXT    "v=spf1 ip4:192.0.2.20 -all"
```

Zona inversa de `10.0.2.0/24` → `zone "2.0.10.in-addr.arpa"`, con líneas `15 IN PTR host.mizona.foo.`

| Tipo | Valor |
|---|---|
| `SOA` | primario, mail del responsable (con `.`), serial, refresh, retry, expire, minimum |
| `NS` | un servidor autoritativo (un nombre con su A) |
| `A` / `AAAA` | IPv4 / IPv6. Nunca un nombre ("bad dotted quad") |
| `CNAME` | otro nombre |
| `MX` | preferencia + nombre (nunca un CNAME ni una IP) |
| `TXT` | texto entre comillas (SPF, verificaciones) |
| `PTR` | nombre (en la zona inversa) |

- Mail del SOA con `@` → va con `.` (`admin.mizona.foo.`). Si el usuario tiene un punto, se
  escapa: `example\.admin.foo.com.ar.`
- Nombre sin `.` final → se le pega el origen (`ns1.mizona.foo` = `ns1.mizona.foo.mizona.foo.`).
  Usá `ns1` a secas o el FQDN con punto.
- NS sin su A → la zona **no carga**. MX sin A → sólo un aviso (corregilo igual).
- Serial sin subir (o "más chico": 8 dígitos < 10) → los secundarios no se enteran.
- Respuesta **sin** `aa` → no la contestó tu zona (no cargó): `journalctl -u named`.

### Zona desde una captura (PCAP)

```bash
tshark -r cap.pcap -Y 'dns.flags.response == 1' -O dns | less    # todas las respuestas, en detalle
tshark -r cap.pcap -Y 'dns.qry.type == 252'                      # ¿hay un AXFR? (252 = AXFR)
tshark -r cap.pcap -Y 'dns.flags.response == 1 && dns.flags.authoritative == 1' -O dns
```

De cada respuesta, las 3 secciones y cada registro **desplegado** (el TTL está adentro): el SOA
sale del AUTHORITY de un NXDOMAIN, las A de los NS/MX del ADDITIONAL, `$TTL` = el TTL que más se
repite, el resto en su línea; ignorar `OPT`; lo nuevo + **serial + 1**. Después repetir cada
consulta con `dig @127.0.0.1` y comparar.

## 8. DHCP (isc-dhcp-server)

```bash
sudo systemctl stop NetworkManager.service
sudo apt install isc-dhcp-server
sudo ip addr add 192.168.90.1/24 dev enp0s9     # el server necesita una IP en la red que reparte
sudo ip link set enp0s9 up
sudo nano /etc/default/isc-dhcp-server           # INTERFACESv4="enp0s9"   (sólo esa interfaz)
sudo nano /etc/dhcp/dhcpd.conf
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf           # validar la sintaxis
sudo systemctl restart isc-dhcp-server
journalctl -xeu isc-dhcp-server                  # si no arranca
sudo nmap --script broadcast-dhcp-discover \
     --script-args broadcast-dhcp-discover.mac=08:00:27:1A:2B:3C   # verificar (desde un cliente;
#   con un par veth: -e veth-cli). Muestra "IP Offered: ..."
sudo dhclient -v enp0s3                          # (en un cliente) pedir IP;  -r = liberarla
```

```
# /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
authoritative;
subnet 192.168.90.0 netmask 255.255.255.0 {
    range 192.168.90.20 192.168.90.150;
    option routers 192.168.90.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.90.255;
    option domain-name-servers 1.1.1.1, 1.0.0.1;     # separados por COMA
}
host impresora {                                      # IP fija por MAC
    hardware ethernet 08:00:27:1A:2B:3C;
    fixed-address 192.168.90.8;                       # FUERA del range
}
host bloqueado { hardware ethernet aa:bb:cc:dd:ee:ff; deny booting; }   # no responderle
```

| Directiva | Para qué |
|---|---|
| `subnet <red> netmask <máscara> { }` | la red que se reparte (la interfaz tiene que tener una IP ahí) |
| `range <desde> <hasta>;` | IPs para cualquier cliente |
| `option routers <ip>;` | gateway que se informa |
| `option domain-name-servers a, b;` | DNS |
| `option subnet-mask` / `option broadcast-address` | máscara / broadcast |
| `default-lease-time` / `max-lease-time` | duración del préstamo, en segundos |
| `host x { hardware ethernet <mac>; fixed-address <ip>; }` | reserva por MAC |
| `deny booting;` | ignorar esa MAC (no hay OFFER ni NAK) |
| `authoritative;` | es EL servidor de esa red |

- `No subnet declaration for <if>` = la interfaz no tiene una IP de esa subnet.
- `INTERFACESv4` vacío = atiende en **todas** (DHCP trucho en la red del lab).
- Rompen el arranque: DNS separados con espacio, un `;` de menos, opciones mal escritas.
- La MAC con el primer byte **impar** es multicast: está mal copiada.
- AppArmor sólo deja a dhcpd leer `/etc/dhcp/`: probá las configs copiadas ahí.
- **DORA**: Discover → Offer → Request → ACK (el nmap sólo hace las dos primeras).

## 9. Mail: SMTP, POP3, MIME y base64

### SMTP a mano

```bash
dig MX dominio +short          # a qué servidor conectarse (menor número = primero)
nc -C mail.sebikul.com 25      # -C obligatorio (CRLF)
```

```
EHLO localhost
MAIL FROM:<LEGAJO@itba.edu.ar>
RCPT TO:<LEGAJO@mail.sebikul.com>
DATA
Date: Thu, 12 Nov 2026 16:00:00 -0300
From: Nombre Apellido <LEGAJO@itba.edu.ar>
To: <LEGAJO@mail.sebikul.com>
Subject: =?UTF-8?B?wqFCdWVub3MgZMOtYXMh?=
X-Parcial: 2026/2
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

wqFIb2xhIG11bmRvIQ==
.
QUIT
```

| Comando | Para qué |
|---|---|
| `EHLO <nombre>` | saludo ESMTP (responde las extensiones). `HELO` = el viejo. `HELLO` no existe |
| `MAIL FROM:<dir>` | remitente del **sobre** (a esa dirección van los rebotes) |
| `RCPT TO:<dir>` | destinatario del **sobre**: el que decide la entrega (uno por línea) |
| `DATA` | empieza el mensaje (responde 354) |
| línea vacía | separa los headers del cuerpo |
| `.` sola en una línea | fin del mensaje → `250 ... queued as <ID>` |
| `RSET` / `NOOP` / `QUIT` | abortar la transacción / no hacer nada / cerrar |

Respuestas: `2xx` ok · `354` seguí mandando · `4xx` error temporal · `5xx` permanente (ej.
`554 Relay access denied`). `From:` y `To:` son lo que **muestra** el MUA; entrega el `RCPT TO`.

### POP3 a mano

```
nc -C mail.sebikul.com 110
USER LEGAJO@mail.sebikul.com
PASS ********
STAT          # cantidad de mails y bytes
LIST          # número + tamaño de cada uno
RETR 1        # leer el mail 1
TOP 1 0       # sólo los headers del mail 1
UIDL          # id único de cada mail
DELE 1        # marcarlo para borrar (se aplica al QUIT)
RSET          # desmarcar
QUIT
```

Respuestas: `+OK` / `-ERR`. Si cortás con Ctrl+C antes del `QUIT`, no se borra nada.

### MIME

| Header | Para qué |
|---|---|
| `MIME-Version: 1.0` | habilita MIME |
| `Content-Type: text/plain; charset=UTF-8` | tipo del cuerpo + charset |
| `Content-Transfer-Encoding: base64` | cómo viaja: `7bit`, `8bit`, `quoted-printable` o `base64` |
| `Content-Disposition: attachment; filename="x.png"` | adjunto (o `inline`) |
| `=?UTF-8?B?<base64>?=` | *encoded-word*: acentos o `¡` en Subject y From (`?Q?` = quoted-printable) |

```
Content-Type: multipart/alternative; boundary="lim123"

--lim123
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: base64

<cuerpo en base64>
--lim123
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: base64

<html en base64>
--lim123--
```

`multipart/mixed` = cuerpo + adjuntos · `multipart/alternative` = lo mismo en texto y en HTML ·
`multipart/related` = HTML + imágenes embebidas (`cid:`). Si piden que lo lean MUAs sin
quoted-printable: cuerpo en **base64**.

### base64 y codificaciones

```bash
echo -n '¡Hola mundo!' | base64            # → wqFIb2xhIG11bmRvIQ==   (-n: sin el \n del final)
printf '%s' '¡Buenos días!' | base64        # → wqFCdWVub3MgZMOtYXMh
echo 'wqFIb2xhIG11bmRvIQ==' | base64 -d     # decodificar
base64 -w 76 foto.png                       # adjunto en líneas de 76 caracteres (MIME)
base64 -w 0 archivo                         # todo en una sola línea
xxd archivo | head                          # los bytes en hexa
file archivo                                # qué tipo de archivo es (por el magic number)
iconv -f latin1 -t utf8 archivo             # convertir de codificación
```

| Opción | Para qué |
|---|---|
| `base64 -d` | decodificar |
| `base64 -w N` | cortar las líneas cada N caracteres (`-w 0` = sin cortar) |
| `echo -n` / `printf '%s'` | no agregar el salto de línea final (si no, entra en el base64) |

base64 crece 4/3 (9 MB → 12 MB).

### postfix, dovecot y mutt (servidor local)

```bash
postconf -n                                  # lo que configuraste en main.cf
sudo postconf -e 'mydestination = ...'       # cambiar un parámetro
sudo postfix check
mailq                                        # cola de salida (= postqueue -p)
sudo postqueue -f                            # reintentar la cola ya
sudo postsuper -d ALL                        # vaciar la cola (-d <ID> para uno)
sudo tail -f /var/log/mail.log               # status=sent / deferred / bounced
sudo doveconf -n                             # config efectiva de dovecot
mutt                                         # cliente de correo de consola
```

Puertos: 25 SMTP · 587 submission (STARTTLS + AUTH) · 465 SMTPS · 110 POP3 · 995 POP3S ·
143 IMAP · 993 IMAPS.

## 10. SSH

### Conectarse y manejar claves

```bash
ssh user@host
ssh -p 2222 user@host                 # otro puerto
ssh -i ./clave user@host              # otra clave privada (antes: chmod 600 ./clave)
ssh -v user@host                      # debug: qué clave y método usó
ssh user@host 'comando'               # correr un comando remoto y volver
ssh -o IPQoS=none user@host           # si se cuelga en la red del lab (DSCP)
ssh-keygen -t ed25519                 # crear un par de claves (~/.ssh/id_ed25519 y .pub)
ssh-copy-id user@host                 # copiar la .pub al authorized_keys del server
ssh-keygen -R host                    # sacarlo de known_hosts (tras "HOST ... HAS CHANGED")
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub   # fingerprint del server, para comparar
ssh-keygen -y -f ./clave              # derivar la pública (pide la passphrase si tiene)
eval "$(ssh-agent)" && ssh-add ./clave    # cargar la clave: la passphrase se pide una sola vez
```

| Opción de `ssh` | Para qué |
|---|---|
| `-p N` | puerto del servidor |
| `-i clave` | clave privada a usar |
| `-v` | debug |
| `-L` / `-R` / `-D` | túneles (abajo) |
| `-N` | no abrir shell: sólo el túnel |
| `-f` | pasar a segundo plano |
| `-J salto` | pasar por un bastión |
| `-o Opción=valor` | cualquier opción de ssh_config |

| Opción de `ssh-keygen` | Para qué |
|---|---|
| `-t ed25519` | tipo de clave |
| `-f archivo` | archivo de la clave |
| `-l -f x.pub` | mostrar el fingerprint |
| `-R host` | sacar ese host de known_hosts |
| `-y -f privada` | sacar la pública de la privada |
| `-p -f privada` | cambiar la passphrase |

Permisos: `~/.ssh` **700**, `authorized_keys` **600**, la clave privada **600** (si no:
"UNPROTECTED PRIVATE KEY FILE" y la ignora). La passphrase descifra la clave en **tu** máquina;
el server nunca la ve.

### Túneles

```bash
# -L LOCAL: abro un puerto en MI máquina que llega a algo que ve el server
ssh -L 6402:localhost:8080 user@pampero.itba.edu.ar     # en mi PC: curl localhost:6402
# -R REMOTO: abro un puerto en el SERVER que llega a algo mío (sirve si estoy detrás de NAT)
ssh -R 6402:localhost:8080 user@pampero.itba.edu.ar     # en pampero: curl localhost:6402
# -D DINÁMICO: el server pasa a ser mi proxy SOCKS
ssh -fN -D 1080 user@pampero.itba.edu.ar                # curl -x socks5h://localhost:1080 URL
```

| Forma | Quién escucha | Quién se conecta al destino |
|---|---|---|
| `-L local:destino:puerto` | mi máquina | el server |
| `-R remoto:destino:puerto` | el server (sólo en su 127.0.0.1, salvo `GatewayPorts yes`) | mi máquina |
| `-D puerto` | mi máquina, como proxy SOCKS5 | el server, a donde pida cada aplicación |

Adelante se puede poner `bind:` (en qué IP escuchar). `destino` lo resuelve el lado que hace la conexión final.

**Seguir en vivo un archivo del server** (`tail -f` + túnel; el orden importa):

```bash
# 1) en MI PC, PRIMERO: un listener que guarda lo que llega
nc -l localhost 8099 > archivo.log
# 2) en MI PC: túnel remoto, y en el server mandar el archivo al túnel
ssh -R LEGAJO:localhost:8099 user@pampero 'tail -f /tmp/pdc | nc localhost LEGAJO'
# 3) en MI PC, en otra terminal: seguir en vivo
tail -f archivo.log
```

El `nc -l` tiene que estar **antes** que el `nc` del server. Sin túnel vale la mitad
(`ssh user@pampero 'tail -f /tmp/pdc' > archivo.log`).

### Copiar archivos

```bash
scp user@host:/etc/passwd ./copia.txt     # remoto → local
scp ./archivo user@host:/tmp/             # local → remoto
scp -P 2222 -r carpeta user@host:~        # -P (mayúscula) = puerto, -r = carpetas
sftp user@host                            # interactivo: ls, get, put
rsync -av dir/ user@host:dir/             # sincronizar (sólo copia lo que cambió)
```

### Servidor y config del cliente

```bash
sudo sshd -t                     # validar /etc/ssh/sshd_config
sudo systemctl reload ssh
```

| Archivo / directiva | Para qué |
|---|---|
| `PermitRootLogin no\|prohibit-password` | root sin login / sólo con clave |
| `PasswordAuthentication no` | sólo claves |
| `AllowTcpForwarding yes` | permitir túneles |
| `GatewayPorts yes` | que los `-R` escuchen en todas las interfaces del server |
| `~/.ssh/config`: `Host x` + `HostName`, `Port`, `User`, `IdentityFile` | alias: `ssh x` |

## 11. Captura y análisis: tcpdump, tshark y Wireshark

### tcpdump

```bash
sudo tcpdump -ni lo port 25 -A               # SMTP local, con el contenido en ASCII
sudo tcpdump -ni any port 53                 # DNS por cualquier interfaz
sudo tcpdump -ni enp0s8 icmp -c 10           # 10 paquetes ICMP y termina
sudo tcpdump -ni any -w cap.pcap port 80     # guardar para abrir después en Wireshark
tcpdump -nr cap.pcap                         # leer una captura
```

| Opción | Para qué |
|---|---|
| `-i <if>` | interfaz: `lo` (todo lo que va a localhost), `enp0s8`, `any` |
| `-n` | no resolver nombres |
| `-A` / `-X` | mostrar el contenido en ASCII / en hexa + ASCII |
| `-c N` | cortar después de N paquetes |
| `-w` / `-r archivo` | guardar / leer un pcap |
| `-v` | más detalle |
| filtro (BPF) | `port 53` · `host 10.0.0.5` · `tcp` · `udp` · `icmp` · `arp` · `and` / `or` / `not` |

### tshark

```bash
tshark -i lo -f "port 110" -Y pop                    # capturar (-f) y mostrar (-Y)
tshark -r cap.pcap -Y dns -O dns | less              # leer: detalle de la capa DNS
tshark -r cap.pcap -Y http.request -T fields -e http.host -e http.request.uri
tshark -r - < ~/captura.pcap                         # en la VM: AppArmor no lo deja leer tu home
capinfos cap.pcap                                    # cuántos paquetes, duración
wireshark cap.pcap &                                 # la interfaz gráfica
```

| Opción | Para qué |
|---|---|
| `-i <if>` / `-r archivo` | capturar de una interfaz / leer un archivo (`-r -` = stdin) |
| `-f "filtro"` | filtro de **captura** (BPF, como tcpdump) |
| `-Y "filtro"` | filtro de **visualización** (sintaxis de Wireshark) |
| `-O proto` | detalle completo sólo de ese protocolo |
| `-V` | detalle de todas las capas |
| `-T fields -e campo` | imprimir sólo esos campos |

### Filtros de Wireshark (visualización)

| Filtro | Muestra |
|---|---|
| `http.request` · `http.response.code == 304` | pedidos HTTP · respuestas 304 |
| `dns` · `dns.flags.response == 1` | DNS · sólo las respuestas |
| `dns.flags.authoritative == 1` | respuestas autoritativas (`aa`) |
| `dns.qry.type == 252` · `dns.qry.name contains "itba"` | transferencias de zona · consultas por un nombre |
| `ip.addr == 10.0.0.5` · `tcp.port == 80` · `udp.port == 53` | por host · por puerto |
| `tcp.flags.syn == 1 && tcp.flags.ack == 0` | SYN iniciales (escaneos) |
| `tcp.flags.reset == 1` | RST (puerto cerrado) |
| `icmp.type == 11` · `icmp.type == 3` | Time Exceeded (traceroute) · Unreachable |
| `smtp \|\| pop` · `dhcp` · `arp` · `tls` | por protocolo |
| `tls.handshake.extensions_server_name` | SNI (el nombre del sitio en HTTPS) |
| `ip.flags.mf == 1 \|\| ip.frag_offset > 0` | fragmentos |

Combinar: `&&`, `||`, `!` (en BPF: `and`, `or`, `not`). Clic derecho → **Follow → TCP Stream**:
la conversación como texto (HTTP, SMTP, POP3, telnet, AXFR). Statistics → Conversations / Flow Graph.

## 12. xinetd y telnet

```
# /etc/xinetd.d/telnet       (los comentarios, sólo en líneas enteras)
service telnet
{
    disable     = no
    socket_type = stream            # stream = TCP, dgram = UDP
    protocol    = tcp
    wait        = no                # no: un proceso por conexión
    user        = root
    server      = /usr/sbin/telnetd # el DEMONIO, no el cliente /usr/bin/telnet
}
```

| Directiva | Para qué |
|---|---|
| `disable = no` | habilitado |
| `socket_type` / `protocol` | `stream` + `tcp` o `dgram` + `udp` |
| `wait` | `no` = un proceso por conexión · `yes` = uno solo (lo típico en UDP) |
| `server` / `server_args` | el programa que se lanza y sus argumentos |
| `type = INTERNAL` | lo implementa xinetd (echo, daytime, time, chargen) |
| `type = UNLISTED` + `port = N` | servicio que no está en `/etc/services` |
| `id` | distinguir dos bloques del mismo servicio (`echo-stream` / `echo-dgram`) |
| `only_from` | quién se puede conectar |

```bash
sudo systemctl restart xinetd && journalctl -u xinetd -n 20
nc localhost 7   ·   nc localhost 13   ·   nc -u localhost 7      # echo · daytime · echo UDP
```

## 13. Cuando algo no anda (en este orden)

1. ¿Corre? `systemctl status X`
2. ¿Qué dice el log? `journalctl -u X -n 50` · `/var/log/nginx/error.log` · `/var/log/mail.log`
3. ¿Escucha donde creo? `sudo ss -tulpn`
4. ¿La sintaxis está bien? `nginx -t` · `named-checkconf -z` · `dhcpd -t` · `postfix check` · `sshd -t`
5. ¿Resuelve? `getent hosts X` (lo que usa curl) contra `dig X` (sólo DNS)
6. ¿Hay ruta? `ping`, `ip route get X`, `traceroute -n X`
7. ¿Qué pasa por el cable? `tcpdump` o Wireshark

## 14. Puertos de referencia

| Puerto | Servicio | Puerto | Servicio |
|---|---|---|---|
| 7 · 13 · 37 | echo · daytime · time | 110 · 995 | POP3 · POP3S |
| 22 · 23 | SSH · telnet | 143 · 993 | IMAP · IMAPS |
| 25 · 587 · 465 | SMTP · submission · SMTPS | 443 | HTTPS |
| 53 | DNS (UDP y TCP) | 520 | RIP (UDP) |
| 67 · 68 | DHCP servidor · cliente (UDP) | 1080 | SOCKS |
| 80 | HTTP | 33434+ | traceroute (UDP) |

## 15. Scripts de práctica en la VM

| Script | Para qué |
|---|---|
| `~/Protos/scripts/verificar-todo.sh` | prueba todo: OK / FALLA por ejercicio |
| `~/Protos/scripts/instalar-configs.sh` | vuelve a aplicar las configs buenas (pisa `/etc`) |
| `~/Protos/scripts/simulacro.sh montar\|verificar\|limpiar` | el simulacro 1 |
| `~/Protos/practica-simulacro-2/simulacro-2.sh montar\|verificar\|pista\|solucion\|limpiar [ejN]` | el simulacro 2 |
| `~/Protos/scripts/parcial-2026-2c.sh montar\|verificar\|solucion\|limpiar [ejN]` | el parcial 2026 2C |
| `~/Protos/scripts/practicar-dhcp.sh [archivo.conf]` | DHCP en una red virtual (veth), sin tocar la red |
| `~/Protos/scripts/practicar-dns-pcap.sh verificar\|solucion\|limpiar [captura]` | zona DNS desde una captura |
| `~/Protos/scripts/foo-modo.sh estatico\|proxy` | cambia el sitio `foo` entre estático y proxy |

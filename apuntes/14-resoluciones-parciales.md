# 14: Resoluciones de parciales prácticos anteriores (paso a paso)

**Fuente**: repo [rodrihern/Protos-ITBA](https://github.com/rodrihern/Protos-ITBA), carpeta `examenes/`.
Hay una copia en `/Users/maratorres/cosas protos/Protos-ITBA` de la Mac. Parciales que
cubre:

| Parcial | Ejercicios | Consigna |
|---|---|---|
| 2022 2C | Ej 2 (el único que está en el repo), más nginx y la zona `demiloo.com.ar` | captura en el repo; los otros dos, de `ejercicios-practicos.md` |
| 2024 2C | Ej I, II, III, IV | capturas en el repo |
| 2025 2C | Ej I, II, III, IV | fotos en el repo |
| 2026 1C | Ej 1, 2, 3, 4 | **no hay consigna** en el repo: la reconstruí desde la resolución |

Cada resolución de abajo **se probó en la VM** el 26/10/2026, simulando los servidores de
la cátedra con servicios locales. Las excepciones se aclaran (los ejercicios de la red del
laboratorio no se pueden probar desde casa). Los archivos listos para copiar están en
`~/Protos/ejercicios/parciales/`.

## Qué toman (frecuencia)

| Tema | 2022 2C | 2024 2C | 2025 2C | 2026 1C | Apunte |
|---|---|---|---|---|---|
| **nginx proxy reverso** (la URL no cambia) | sí | Ej I | Ej IV (con HTTPS) | Ej 2 (con headers) | 03 |
| **Túnel SSH + `tail -f` + nc** | Ej 2 | | | Ej 4 | 10 |
| **curl + proxy SOCKS5h + headers / Basic auth** | | Ej II | | Ej 3 | 02 |
| **bind9: armar o corregir una zona** | sí | | Ej III | Ej 1 | 04 |
| **Ruta a otra red + nmap + curl + traceroute** | | Ej III | Ej II | | 08, 09 |
| **Mail por SMTP a mano (MIME, encoded-words) + POP3** | | Ej IV | | | 05 |
| **DHCP (isc-dhcp-server)** | | | Ej I | | 12 |
| **TLS / certificado confiable** | | | Ej IV | | 11 |

**Patrón**: casi siempre hay **un ejercicio de nginx como proxy reverso**, **uno de DNS o
redes**, **uno de "llegar a algo" (túnel SSH o proxy SOCKS)** y **uno de protocolos de
aplicación a mano** (mail o curl). En 2022 2C el número de los ejercicios de nginx y de la
zona no se sabe: la fuente no lo aclara (y el Ej 3 no aparece en ninguna).

## Errores que encontré en las resoluciones del repo

| Ejercicio | Lo que dice el repo | Lo correcto |
|---|---|---|
| 2022 Ej 2 | `tail -f /etc/pdc` | El archivo es **`/tmp/pdc`** |
| 2024 Ej I | `proxy_pass http://localhost:8080;` | El upstream es **`http://protos.sebikul.com`**. `localhost:8080` no es lo que pide la consigna |
| 2024 Ej I | "Por defecto nginx no pasa headers personalizados" | **Falso**: nginx reenvía todos los headers del cliente al backend y todos los de la respuesta al cliente. Probado: `X-Parcial-Protos` pasa en los dos sentidos sin configurar nada |
| 2024 Ej II | usa `socks5://` | La consigna dice **`socks5h://`**: que el **proxy** resuelva el nombre. Si tu máquina no puede resolver ese host, `socks5://` falla |
| 2024 Ej IV | manda a su propia cuenta del ITBA, sin `X-Parcial`, con una parte quoted-printable y un From inventado | Hay que mandar a `{legajo}@mail.sebikul.com`, con `X-Parcial: 2024/2`, el From con tu nombre y tu cuenta ITBA, y el cuerpo **sólo en base64** (el requisito f prohíbe QP) |
| 2025 Ej I | red `192.168.108.0`, MAC `0B:08:27:...` | En la foto es **`192.168.100.0/24`** y la MAC es **`08:00:27:AE:C8:6A`** (08:00:27 es el prefijo de VirtualBox). La IP fija es `192.168.100.8`. Tampoco hace falta parar NetworkManager |
| 2025 Ej II | `nmap -sn 10.0.0.0/24` y `nmap -sV -p- 10.0.0.0/24` sin agregar la ruta | Sin `ip route add 10.0.0.0/24 via 192.168.50.250` los paquetes salen por la default y no llega nada. Además `-p-` sobre toda la /24 tarda muchísimo: primero encontrar el host |
| 2025 Ej III | serial nuevo `20260723` | Es **menor** que `2025060500` (8 dígitos contra 10), así que los secundarios **no** transfieren la zona. Usar `2025060501` o la fecha de hoy + NN (10 dígitos) |
| 2025 Ej III | "Error 0: falta `$ORIGIN`" | **No es un error**: sin `$ORIGIN`, el origen es el nombre de la zona de named.conf. Lo que faltó explicar es que el SOA tenía refresh y TTL negativo de 1 semana |

---

## 2022 2C, Ej 2 (y 2026 1C Ej 4, que es el mismo): seguir `/tmp/pdc` de pampero con `tail -f`

**Consigna (resumida)**: que en tu host `tail -f archivo.log` muestre en vivo los cambios de
`/tmp/pdc` que está en pampero.itba.edu.ar. Si no usás túneles, tenés la mitad del puntaje.
Si necesitás un puerto, usá tu legajo. Pista: `tail -f`, netcat, pipes y redirecciones.

### Idea

Los datos tienen que viajar de **pampero → mi máquina**, y pampero no puede abrir
conexiones hacia mi máquina (estoy detrás de NAT). Con un **túnel remoto (`-R`)**, pampero
escucha en un puerto suyo y todo lo que entra ahí aparece en un puerto de mi máquina.

```
pampero:  tail -f /tmp/pdc | nc localhost LEGAJO ──► (túnel -R) ──► mi máquina: nc -l 8099 > archivo.log
                                                                              tail -f archivo.log
```

### Paso a paso

```bash
# 1) EN MI MÁQUINA, terminal 1: escuchar y volcar a archivo.log
nc -l 127.0.0.1 8099 > archivo.log          # cualquier puerto LIBRE (en la VM el 8080 ya lo usa E39)

# 2) EN MI MÁQUINA, terminal 2: abrir el túnel remoto y, por el mismo ssh, mandar los datos
ssh -R 65522:localhost:8099 legajo@pampero.itba.edu.ar 'tail -f /tmp/pdc | nc localhost 65522'
#      ^^^^^ puerto EN PAMPERO (= legajo, para no chocar con otros alumnos; tiene que ser <= 65535)
#      el comando entre comillas corre EN pampero: tail -f escribe en nc, nc entra al túnel

# 3) EN MI MÁQUINA, terminal 3: lo que pide la consigna
tail -f archivo.log
```

El repo lo hace en dos pasos (primero `ssh -R ...` y después, ya adentro de pampero,
`tail -f /tmp/pdc | nc localhost PUERTO`). Es equivalente.

**Variante con túnel local (`-L`)**: en pampero `tail -f /tmp/pdc | nc -l 65522`. En mi
máquina, `ssh -N -L 8099:localhost:65522 legajo@pampero` y después
`nc localhost 8099 > archivo.log`.

**Sin túnel (mitad de puntaje)**: `ssh legajo@pampero 'tail -f /tmp/pdc' > archivo.log`.

### Errores típicos

- **Confundir `-R` con `-L`**: con `-R` el puerto **remoto** (el primero) se abre en pampero.
- Usar como puerto local uno que ya está ocupado: `nc: Address already in use`.
- Un legajo de más de 65535 no sirve como puerto: usar, por ejemplo, los últimos 4 dígitos
  con un prefijo.
- Arrancar el `nc` de pampero **antes** del `nc -l` local: la conexión del túnel falla
  ("connect_to localhost port 8099: failed").

**Probado en la VM** con `localhost` haciendo de pampero: aparecieron en `archivo.log` las
líneas que se iban agregando a `/tmp/pdc` en vivo.

---

## 2022 2C, los otros dos: nginx a foo.leak.com.ar y la zona demiloo.com.ar

**Fuente**: `ejercicios-practicos.md` (en `/Users/maratorres/cosas protos/` de la Mac), que
los tomó de una "Recopilación" del drive que no tenemos. Allí no dice cuál es el Ej 1 y cuál
el Ej 4.

### nginx: http://foo.example.org/ tiene que servir http://foo.leak.com.ar/

Es el mismo esquema que **2024 Ej I**: proxy reverso (la URL no cambia) y `curl` sin
opciones.

```nginx
server {
    listen 80;
    server_name foo.example.org;
    location / {
        proxy_pass http://foo.leak.com.ar;
    }
}
```

Más `127.0.0.1 foo.example.org` en `/etc/hosts`. **Ojo**: al 26/10/2026 `foo.leak.com.ar` ya
no existe en el DNS, así que hoy `nginx -t` falla con "host not found in upstream". Para
practicarlo, ponelo en `/etc/hosts` apuntando a un server local (ver "Cómo practicar" al
final).

### BIND: servir demiloo.com.ar

**Consigna (resumida)**: tu servidor es la autoridad de `demiloo.com.ar`; contacto
`demiloo@leak.com.ar`; el A del apex es la IP de `foo.leak.com.ar`, con TTL de 1 hora; `www`
es un CNAME al apex con TTL de 2 semanas; los mismos MX que `proto.leak.com.ar`, en el mismo
orden y con TTL de 1 semana. Mostrarlo con `dig`.

**Paso 1: sacar los datos de afuera.**

```bash
dig +short foo.leak.com.ar          # la IP (si da varias, un A por cada una)
dig +short MX proto.leak.com.ar     # los MX con sus preferencias
```

Hoy ninguno de los dos resuelve, así que el archivo usa IPs y MX de ejemplo.

**Paso 2: la zona** (`~/Protos/ejercicios/parciales/2022-2c-demiloo.com.ar.db`):

```
$TTL 1d
@       IN SOA ns.demiloo.com.ar. demiloo.leak.com.ar. (
        2022110101 ; Serial
        1h         ; Refresh
        15m        ; Retry
        1w         ; Expire
        5m )       ; Negative Cache TTL
@           IN NS    ns.demiloo.com.ar.
ns          IN A     192.0.2.53              ; la IP de TU servidor
@       1h  IN A     203.0.113.10            ; = IP de foo.leak.com.ar
www     2w  IN CNAME @
@       1w  IN MX    10 mx1.example.net.     ; = MX de proto.leak.com.ar, mismas preferencias
@       1w  IN MX    20 mx2.example.net.
```

- **Contacto**: `demiloo@leak.com.ar` → `demiloo.leak.com.ar.` (el `@` pasa a `.`).
- **TTL propio de un registro**: va entre el nombre y el `IN`. `2w` = 2 semanas.
- **`www CNAME @`** está bien: lo que no se puede es un CNAME **en** el apex, no un CNAME
  **hacia** el apex.
- **"En el mismo orden"** = las **mismas preferencias**. El orden de los MX lo da el número
  (menor = primero), no el orden de las líneas en el archivo.

**Paso 3: cargarla y mostrarla.**

```bash
# /etc/bind/named.conf.local:  zone "demiloo.com.ar" { type master; file "/etc/bind/zones/db.demiloo.com.ar"; };
sudo named-checkzone demiloo.com.ar /etc/bind/zones/db.demiloo.com.ar
sudo rndc reconfig                          # zona nueva en named.conf -> reconfig (o reload)
dig +norec @localhost demiloo.com.ar ANY    # SOA, NS, A y MX con sus TTL
dig +norec @localhost www.demiloo.com.ar
```

**Probado en la VM**: `named-checkzone` da OK. Avisa que `mx1.example.net` y
`mx2.example.net` no tienen A, porque son de ejemplo; con los MX reales no pasa. Cargada en
bind de forma temporal, `dig ANY` mostró el A con TTL 3600, los MX con 604800 y `www` con
1209600. Después se sacó.

---

## 2024 2C

### Ej I: http://foo.example.org/ tiene que servir http://protos.sebikul.com/ conservando X-Parcial-Protos

**Requisitos**: que no cambie la URL del browser (o sea, **no redirect**), que funcione
`curl http://foo.example.org/` **sin opciones**, y se puede pedir cualquier recurso.

1. **¿Proxy o redirect?** La URL no puede cambiar, así que es un **proxy reverso**
   (`proxy_pass`). Un `return 301/302` cambiaría la URL.
2. **Resolver el nombre a nuestra máquina**: `echo "127.0.0.1 foo.example.org" | sudo tee -a /etc/hosts`.
3. **Sitio de nginx** (`~/Protos/ejercicios/parciales/2024-2c-ej1-nginx-foo.example.org`):

   ```nginx
   server {
       listen 80;
       server_name foo.example.org;
       location / {
           proxy_pass http://protos.sebikul.com;     # sin "/" final: la ruta pasa igual
           proxy_set_header X-Parcial-Protos $http_x_parcial_protos;   # redundante, pero explícito
           ; para que sirve lo de arriba??
       }
   }
   ```

4. **Habilitar y recargar**:

   ```bash
   sudo ln -s /etc/nginx/sites-available/foo.example.org /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```

   ;sudo nginx -t hace una prueba de sintaxis para corroborar que este todo escrito correctamente y no falte algo tipo un punto y coma

5. **Verificar**: `curl -v http://foo.example.org/` (la respuesta trae `X-Parcial-Protos`)
   y `curl http://foo.example.org/cualquier/cosa`.
   ;debe de poder pedir cualquier recurso

**Puntos clave**:

- **`Host`**: no hay que pisarlo con `$host`. protos.sebikul.com es un virtual host y
  necesita recibir `Host: protos.sebikul.com`, que es el default de nginx. Si le llega
  `Host: foo.example.org`, devuelve otra cosa.
  ;no entendi esta parte
- **`$http_x_parcial_protos`**: cada header del pedido está disponible como `$http_` + el
  nombre en minúsculas, con `-` → `_`.
  ;para que funcionaria esto?
- **Por qué alcanza sin configurar nada**: nginx ya pasa los headers en los dos sentidos.
  Lo probé con un backend que devuelve los headers que recibe: un `X-Parcial-Protos` que
  manda el cliente llega al backend, y uno que pone el backend en la respuesta llega a curl.
  Las únicas excepciones por defecto son algunos headers que oculta (`Server`, `Date`,
  `X-Accel-*`) y los headers con `_` en el nombre.

### Ej II: obtener text/plain en español de http://ejercicio2.sebikul.com:8080/foo/ por un proxy SOCKS
; que es un proxy socks?
**Datos**: la red no rutea hacia ese host, pero es accesible por el proxy
`socks5h://proxy.sebikul.com:1080`. Te dan un pedido de ejemplo que tiene
`Authorization: Basic dXN1YXJpbzpwYXNzd29yZA==`.

1. **Decodificar las credenciales**: `echo dXN1YXJpbzpwYXNzd29yZA== | base64 -d` →
   `usuario:password`.
2. **Armar el pedido**: negociación de contenido con `Accept: text/plain` y
   `Accept-Language: es`, más Basic auth.

   ```bash
   curl -x socks5h://proxy.sebikul.com:1080 \
        -u usuario:password \
        -H 'Accept: text/plain' \
        -H 'Accept-Language: es' \
        http://ejercicio2.sebikul.com:8080/foo/
   ```

   - `-x socks5h://`: con la **h**, el DNS lo resuelve **el proxy**. Es lo que dice el
     enunciado y lo que hace falta si tu red no conoce ese nombre.
     ;no entendi jeje
   - `-u usuario:password` genera exactamente
     `Authorization: Basic dXN1YXJpbzpwYXNzd29yZA==`. Lo verifiqué: es idéntico al del
     pedido filtrado. Otra opción es `-H 'Authorization: Basic dXN1...'`.
   - En el pedido de ejemplo hay un `Accept-Language: en,it;q=0.9,es-AR;q=0.8,es;q=0.7`:
     prefiere inglés. Por eso hay que pedir **sólo** `es`.

**Puntaje parcial**: reproducir el pedido del PCAP por el proxy SOCKS ya daba 1 punto.

**Probado en la VM** con `ssh -fN -D 1080 localhost` como proxy SOCKS5 y un backend que
muestra los headers: llegaron `Accept: text/plain`, `Accept-Language: es` y el mismo
`Authorization`.

### Ej III: 192.168.1.3 es el gateway de 10.0.0.0/24. Servicios de 10.0.0.1, acceso HTTP y routers

Necesita la red del laboratorio (la VM en **Bridge** a la red Lab), así que no se puede
probar desde casa.

```bash
ip addr                                         # 0) ¿estoy en 192.168.1.x? (si no, no veo al gateway)
;Consigue la ip propia de la maquina
ping -c2 192.168.1.3                            # 1) llego al gateway
;hace ping al gateway, pero que hace -c2?
sudo ip route add 10.0.0.0/24 via 192.168.1.3   # 2) LA CLAVE: ruta a la red de atrás del gateway
ip route get 10.0.0.1                           #    -> "via 192.168.1.3 dev ..."
;es un chequeo de prueba supongo
sudo nmap -sS -sV -Pn 10.0.0.1                  # 3) servicios. -Pn: no descartar el host si no responde ping
#   (para UDP:  sudo nmap -sU --top-ports 50 10.0.0.1)
;consigue los servicios que tiene corriendo para algunos de los puertos en dicha ip, no prueba todos
curl -v http://10.0.0.1/                        # 4) si nmap mostró http (80 u otro puerto: curl http://10.0.0.1:PUERTO/)
traceroute -n 10.0.0.1                          # 5) routers: el primer salto tiene que ser 192.168.1.3
#   si aparecen *: traceroute -I (ICMP) o sudo traceroute -T -p 80 (TCP al puerto abierto)
```

**Por qué hace falta el paso 2**: sin esa ruta, los paquetes a 10.0.0.1 salen por la
**default route** (el router del laboratorio, que no conoce esa red) y no llegan. La ruta
hace que la trama vaya a la **MAC de 192.168.1.3**, aunque la IP destino siga siendo
10.0.0.1.

### Ej IV: mandar un mail que cumpla los estándares

**Requisitos**: (a) header `X-Parcial: 2024/2`; (b) Subject `¡Buenos días!`; (c)
remitente con tu nombre, apellido y cuenta ITBA; (d) texto `¡Hola mundo!`; (e) entregar a
`{legajo}@mail.sebikul.com`; (f) **que se lea en MUAs que no soportan quoted-printable**.
Verificar por POP3 en mail.sebikul.com con usuario y contraseña `{legajo}@mail.sebikul.com`.

**Análisis de cada requisito**:

- El Subject y el cuerpo tienen caracteres **no ASCII** (`¡`, `í`). Los headers sólo
  admiten ASCII, así que el Subject va como **encoded-word** (RFC 2047):
  `=?UTF-8?B?<base64>?=`. `B` = base64, `Q` = parecido a quoted-printable.
- **(f)** El cuerpo no puede ir en quoted-printable. Va con
  **`Content-Transfer-Encoding: base64`** y `charset=UTF-8`. Por coherencia, el Subject
  también con `B`.
- **Buenas prácticas** (RFC 5322 y MIME): `Date`, `Message-ID`, `From`, `To`, `Subject`,
  `MIME-Version: 1.0`, `Content-Type` con charset.

```bash
printf '%s' '¡Buenos días!'   | base64     # wqFCdWVub3MgZMOtYXMh
printf '¡Hola mundo!\r\n'     | base64     # wqFIb2xhIG11bmRvIQ0K
# si el nombre tiene tildes:   From: =?UTF-8?B?<base64 del nombre>?= <legajo@itba.edu.ar>
```

```
$ nc -C mail.sebikul.com 25
EHLO mi-host
MAIL FROM:<legajo@itba.edu.ar>
RCPT TO:<65522@mail.sebikul.com>
DATA
Date: Mon, 26 Oct 2026 15:00:00 -0300
Message-ID: <20261026150000.65522@itba.edu.ar>
From: Nombre Apellido <legajo@itba.edu.ar>
To: <65522@mail.sebikul.com>
Subject: =?UTF-8?B?wqFCdWVub3MgZMOtYXMh?=
X-Parcial: 2024/2
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

wqFIb2xhIG11bmRvIQ0K
.
QUIT
```

**Puntaje parcial** (según la Recopilación del drive, citada en `ejercicios-practicos.md`):
daba 1 punto asumir que el server soporta SMTPUTF8 y mandar los acentos crudos.

**Verificar por POP3**:

```
$ nc -C mail.sebikul.com 110
USER 65522@mail.sebikul.com
PASS 65522@mail.sebikul.com
LIST
RETR <n>          <- ver X-Parcial, Subject codificado, cuerpo en base64
QUIT
```

**Errores típicos**:

- Escribir `Subject: ¡Buenos días!` con tildes crudas: no cumple el estándar.
- Usar `quoted-printable`: no cumple el requisito (f).
- Olvidar la **línea vacía** entre los headers y el cuerpo.
- Olvidar el `.` final.
- Hacer `nc` sin `-C`: SMTP exige CRLF.

**Probado en la VM**: se mandó
`~/Protos/ejercicios/parciales/2024-2c-ej4-mail-PRUEBA-LOCAL.txt` a postfix (con
direcciones locales) y, al parsearlo, se obtuvo Subject `¡Buenos días!`,
`X-Parcial: 2024/2` y cuerpo `¡Hola mundo!`.

---

## 2025 2C

### Ej I: DHCP para la oficina 192.168.100.0/24

**Requisitos**: (1) la impresora `08:00:27:AE:C8:6A` siempre con `192.168.100.8`; (2) DNS
`8.8.8.8` y `8.8.4.4`; (3) asignar del .10 al .200. Hay que verificarlo con
`sudo nmap --script broadcast-dhcp-discover --script-args "broadcast-dhcp-discover.mac=AA:BB:CC:DD:EE:FF"`.
**Aviso de la consigna**: no hacerlo sobre la interfaz conectada al WiFi del laboratorio,
sino en una red interna o una interfaz virtual.

```bash
# 1) una interfaz en red INTERNA (VirtualBox: Adaptador 2 -> "Red interna") con IP en esa red
ip -br link                                     # ver el nombre, ej. enp0s9
sudo ip addr add 192.168.100.1/24 dev enp0s9
sudo ip link set enp0s9 up

# 2) instalar y decirle en qué interfaz atender (si no, atiende en TODAS -> problema en el lab)
sudo apt install isc-dhcp-server
sudo nano /etc/default/isc-dhcp-server          # INTERFACESv4="enp0s9"

# 3) /etc/dhcp/dhcpd.conf   (copia en ~/Protos/ejercicios/parciales/2025-2c-ej1-dhcpd.conf)
```

```
ddns-update-style none;
authoritative;
default-lease-time 600;
max-lease-time 7200;

subnet 192.168.100.0 netmask 255.255.255.0 {
    range 192.168.100.10 192.168.100.200;
    option routers 192.168.100.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.100.255;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
}
host impresora {
    hardware ethernet 08:00:27:AE:C8:6A;
    fixed-address 192.168.100.8;            # FUERA del range
}
```

```bash
# 4) validar, reiniciar y mirar el log
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf
sudo systemctl restart isc-dhcp-server
journalctl -u isc-dhcp-server -n 20     # "No subnet declaration for enpXXX" = la interfaz no tiene IP en esa subnet

# 5) verificar (el comando del enunciado)
sudo nmap --script broadcast-dhcp-discover --script-args "broadcast-dhcp-discover.mac=AA:BB:CC:DD:EE:FF"   # -> IP Offered: 192.168.100.10
sudo nmap --script broadcast-dhcp-discover --script-args "broadcast-dhcp-discover.mac=08:00:27:AE:C8:6A"   # -> IP Offered: 192.168.100.8
```

**Errores típicos**:

- La interfaz **no tiene una IP dentro de la subnet** declarada: dhcpd no arranca ("No
  subnet declaration for ...").
- Separar los DNS con espacio en vez de **coma**.
- Olvidar el `;` al final de cada línea.
- Poner la IP fija **dentro** del range.
- Dejar `INTERFACESv4` vacío: el server atiende en todas las interfaces y le da IPs a la
  red del laboratorio.
- Probar un .conf que está en tu home con `dhcpd -t -cf ~/x.conf`: en Ubuntu **AppArmor sólo
  deja a dhcpd leer `/etc/dhcp/`** y falla con "exiting", aunque el archivo esté bien.
  Copialo a `/etc/dhcp/` antes (así hace `practicar-dhcp.sh`).

**Probado en la VM** con `~/Protos/scripts/practicar-dhcp.sh`, que arma una red virtual veth
y lanza el nmap del enunciado: la MAC cualquiera recibió `.10` con gateway, máscara y los
DNS de Google, y la impresora `.8`.

### Ej II: 192.168.50.250 es el gateway de 10.0.0.0/24. Encontrar el servidor, sus servicios, HTTP y routers

Es el mismo esquema que **2024 Ej III**, con un paso más: **no sabés la IP del servidor**.

```bash
sudo ip route add 10.0.0.0/24 via 192.168.50.250    # 1) ruta a la red de atrás del gateway
sudo nmap -sn 10.0.0.0/24                            # 2) descubrir hosts vivos (ping sweep: ICMP + TCP 80/443)
#   si no aparece nada (ICMP filtrado):  sudo nmap -Pn -p 22,80,443,8080 10.0.0.0/24 --open
#   el gateway también aparece (su IP en 10.0.0.x): el servidor es el OTRO
sudo nmap -sS -sV -Pn 10.0.0.X                       # 3) servicios del servidor encontrado
curl -v http://10.0.0.X:PUERTO/                      # 4) acceso HTTP
traceroute -n 10.0.0.X                               # 5) routers (el primero, 192.168.50.250)
```

### Ej III: zona it.itba.edu.ar rota

**Consigna**: los clientes no resuelven nada de la zona (por ejemplo
`pampero.it.itba.edu.ar`) y BIND se queja al cargar `/etc/bind/db.it.itba.edu.ar`. Hay que
encontrar y corregir **todos** los errores de sintaxis y de lógica, y ajustar el **SOA**
para que los cambios se propaguen **bien y rápido**.

El archivo original está transcrito en
`~/Protos/ejercicios/parciales/2025-2c-ej3-zona-ORIGINAL-con-errores.db`. Así se encara:

**Paso 1: hacer que BIND diga los errores.** `named-checkzone` corta en el primer error,
así que hay que ir corrigiendo de a uno:

```
$ named-checkzone it.itba.edu.ar zona-original.db
dns_rdata_fromtext: ...:20: near 'pampero': bad dotted quad        <- error 1 (www IN A pampero)
$ (corregido) named-checkzone ...
NS 'ns1.it.itba.edu.ar' has no address records (A or AAAA)        <- error 2 (ns1 sin punto final)
zone it.itba.edu.ar/IN: not loaded due to errors.
$ (corregido) named-checkzone ...
MX 'mail.it.itba.edu.ar' has no address records (A or AAAA)       <- error 4 (es sólo un aviso: la zona carga igual)
```

**Paso 2: la lista completa.**

| # | Línea original | Problema | Corrección |
|---|---|---|---|
| E1 | `... admin@it.itba.edu.ar. (` | en el SOA el mail va con **`.`** en vez de `@`. Ojo: **BIND no da error** (acepta `@` dentro de una etiqueta), pero el mail queda mal | `admin.it.itba.edu.ar.` |
| E2 | `ns1.it.itba.edu.ar  IN A 192.168.70.1` | **sin punto final** se convierte en `ns1.it.itba.edu.ar.it.itba.edu.ar.`, así que el NS `ns1.it.itba.edu.ar.` no tiene A y **la zona no carga**. Por esto **no resolvía nada** | `ns1  IN A 192.168.70.1` (o con punto final) |
| E3 | `www  IN A pampero` | un **A lleva una IPv4**, no un nombre ("bad dotted quad") | `www  IN CNAME pampero` |
| E4 | `@ IN MX 10 mail` | `mail` **no existe** (sin A). El MX tampoco puede apuntar al CNAME `correo` | agregar `mail IN A 192.168.70.x`, o `MX 10 pampero` |
| E5 | serial `2025060500` | si no **se sube**, los secundarios no piden la zona nueva | `2025060501` (o la fecha de hoy + NN) |
| E6 | refresh `604800`, negative TTL `604800` | refresh de 1 semana: los secundarios tardan una semana en enterarse. Negative TTL de 1 semana: **los NXDOMAIN de estos días quedan cacheados una semana** en los resolvers de los ISP | refresh `1h`, retry `15m`, negative `5m` |
| E7 | `$TTL 604800` | todo se cachea una semana: los próximos cambios tardan en verse | `$TTL 1h` (bajarlo **antes** de hacer cambios) |
| ¿? | `]` cerrando el SOA (así parece en la foto) | si es `]` y no `)`, es error de sintaxis ("extra input text"). Lo probé | `)` |

**Paso 3: el archivo corregido** (`2025-2c-ej3-zona-CORREGIDA.db`, que pasa
`named-checkzone` con OK):

```
$TTL 1h
$ORIGIN it.itba.edu.ar.
@ IN SOA ns1.it.itba.edu.ar. admin.it.itba.edu.ar. (
        2025060501 ; Serial
        1h         ; Refresh
        15m        ; Retry
        2419200    ; Expire
        5m )       ; Negative Cache TTL
@       IN NS ns1.it.itba.edu.ar.
@       IN MX 10 mail
ns1     IN A 192.168.70.1
pampero IN A 192.168.70.10
mail    IN A 192.168.70.10
www     IN CNAME pampero
correo  IN CNAME pampero
```

**Paso 4: aplicar y propagar.**

```bash
sudo named-checkzone it.itba.edu.ar /etc/bind/db.it.itba.edu.ar
sudo rndc reload it.itba.edu.ar       # carga la zona y manda NOTIFY a los secundarios (por el serial nuevo)
dig @localhost pampero.it.itba.edu.ar # flag "aa" + la IP
dig @localhost www.it.itba.edu.ar     # CNAME -> pampero -> A
```

Sobre "rápido": lo ya cacheado en otros resolvers **no se puede borrar desde acá**: dura lo
que decía el TTL viejo. Lo que sí está en tus manos es el serial (más NOTIFY) para los
secundarios, y valores chicos de refresh, negative TTL y $TTL para lo que venga.

### Ej IV: https://seguro.protos.foo tiene que servir lo de http://parcial.protos.foo

**Requisitos**: que no cambie la URL y que funcione `curl https://seguro.protos.foo` **sin
opciones** (o sea, sin `-k`). El certificado tiene que ser confiable.

```bash
# 1) nombres
echo "127.0.0.1 seguro.protos.foo" | sudo tee -a /etc/hosts
getent hosts parcial.protos.foo        # tiene que resolver (por DNS del lab o con /etc/hosts); si no, nginx -t falla

# 2) certificado autofirmado CON SAN (los navegadores exigen SAN; curl acepta también sólo CN)
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
     -keyout /etc/ssl/private/seguro.key -out /etc/ssl/certs/seguro.crt \
     -subj "/CN=seguro.protos.foo" -addext "subjectAltName=DNS:seguro.protos.foo"
#   (alternativa si mkcert está instalado y su CA ya es confiable:  mkcert seguro.protos.foo)

# 3) hacerlo confiable para el SISTEMA (curl usa este trust store)
sudo cp /etc/ssl/certs/seguro.crt /usr/local/share/ca-certificates/seguro.crt    # la extensión .crt es obligatoria
sudo update-ca-certificates                                                      # "1 added"

# 4) nginx  (~/Protos/ejercicios/parciales/2025-2c-ej4-nginx-seguro.protos.foo)
sudo nano /etc/nginx/sites-available/seguro
```

```nginx
server {
    listen 443 ssl;
    server_name seguro.protos.foo;
    ssl_certificate     /etc/ssl/certs/seguro.crt;
    ssl_certificate_key /etc/ssl/private/seguro.key;
    location / {
        proxy_pass http://parcial.protos.foo;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/seguro /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl https://seguro.protos.foo          # el contenido de parcial.protos.foo, sin error de TLS
```

**Por qué funciona**: el cliente hace TLS con **nuestro** nginx (que presenta un certificado
para seguro.protos.foo, firmado por algo que el sistema confía). nginx termina TLS y pide por
HTTP plano a parcial.protos.foo, con `Host: parcial.protos.foo`.

**Probado en la VM**: con `parcial.protos.foo` simulado por otro server de nginx, antes de
`update-ca-certificates` curl falló con exit 60 (certificado no confiable) y después
devolvió el contenido. Funcionó tanto con el certificado sólo con CN como con SAN. Después
se borró todo.

---

## 2026 1C (consignas reconstruidas: el repo sólo tiene las resoluciones)

### Ej 1: zona foo.example.org en bind9

Requisitos deducidos: NS `ns` (1.2.3.4), responsable `example.admin@foo.com.ar`, refresh 7
días, retry 1 día, expire 10 días, negative TTL y $TTL de 1 minuto, MX 10
`mx1.protos.foo` y MX 5 `mx2.protos.foo` con TTL 7 días, A `123.123.123.123` con TTL 1
hora, `www` como alias con TTL 7 días y SPF que sólo autoriza a 1.2.3.4.

```
// /etc/bind/named.conf.local
zone "foo.example.org" {
    type master;
    file "/etc/bind/zones/db.foo.example.org";
};
```

El archivo de zona es `~/Protos/ejercicios/parciales/2026-1c-ej1-foo.example.org.db` (pasa
`named-checkzone` con OK):

```
$ORIGIN foo.example.org.
$TTL 1m
@ IN SOA ns.foo.example.org. example\.admin.foo.com.ar. (
        2026052801 ; Serial
        7d         ; Refresh
        1d         ; Retry
        10d        ; Expire
        1m )       ; Negative TTL
@        IN NS ns
ns       IN A  1.2.3.4
@    7d  IN MX 10 mx1.protos.foo.
@    7d  IN MX 5  mx2.protos.foo.
@    1h  IN A  123.123.123.123
www  7d  IN CNAME @
@        IN TXT "v=spf1 ip4:1.2.3.4 -all"
```

**Puntos clave**:

- **`example\.admin`**: el punto dentro del usuario del mail se **escapa**. Si no, se lee
  como `example@admin.foo.com.ar`.
- **`mx1.protos.foo.`** lleva punto final porque es de otra zona.
- **`ns IN A`** es obligatorio: el NS está dentro de la zona (glue).
- **`www CNAME @`** es válido: el CNAME está en `www`, no en el apex.

```bash
sudo named-checkconf -z && sudo systemctl reload named
dig @localhost foo.example.org SOA
dig @localhost foo.example.org MX        # 5 mx2... y 10 mx1...
dig @localhost www.foo.example.org       # CNAME + A, con sus TTL
dig @localhost foo.example.org TXT
```

### Ej 2: http://metadata.local → http://metadata.protos.foo agregando los headers `Metadata: true` y `Accept: application/json`

Es como el servicio de *metadata* de las nubes, que exige `Metadata: true`.

```nginx
server {
    listen 80;
    server_name metadata.local;
    location / {
        proxy_pass http://metadata.protos.foo;
        proxy_set_header Metadata true;
        proxy_set_header Accept application/json;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/metadata.local /etc/nginx/sites-enabled/
echo "127.0.0.1 metadata.local" | sudo tee -a /etc/hosts
sudo nginx -t && sudo systemctl reload nginx
curl http://metadata.local
```

**Probado en la VM**: el backend recibió `Metadata: true` y `Accept: application/json`.
`proxy_set_header` **reemplaza** el `Accept: */*` que manda curl.

### Ej 3: POST por proxy SOCKS con headers, JSON y Basic auth

```bash
curl -x socks5h://proxy.protos.foo:1080 \
     -u admin:admin \
     -H 'X-legajo: 65522' \
     -H 'Accept-Language: es' \
     -H 'Content-Type: application/json' \
     -d '{"fix": "yes"}' \
     http://ejercicio3.protos.foo:3126/debugger
```

- `-d` **ya hace POST**. El `-X POST` del repo no está mal, pero sobra. Ojo: `-X POST` sin
  `-d` manda un POST sin cuerpo.
- `-d` por defecto pone `Content-Type: application/x-www-form-urlencoded`. Por eso hay que
  pisarlo con `-H 'Content-Type: application/json'`.
- El JSON va entre **comillas simples** para que el shell no se coma las dobles.

**Probado en la VM** con `ssh -D` como proxy: llegó `POST /debugger` con
`Authorization: Basic YWRtaW46YWRtaW4=`, los headers y el cuerpo `{"fix": "yes"}`.

### Ej 4: túnel SSH + `tail -f` (archivo `/tmp/parcial-20261`)

Es idéntico a **2022 2C Ej 2** (ver arriba), cambiando el archivo:

```bash
nc -l 127.0.0.1 8099 > archivo.log                                                   # mi máquina
ssh -R 55522:localhost:8099 legajo@pampero.itba.edu.ar 'tail -f /tmp/parcial-20261 | nc localhost 55522'
tail -f archivo.log                                                                  # mi máquina
```

---

## Cómo practicar todo esto en la VM

| Ejercicio | Cómo |
|---|---|
| Zonas (2025 Ej III, 2026 Ej 1, 2022 demiloo) | `cd ~/Protos/ejercicios/parciales && named-checkzone it.itba.edu.ar 2025-2c-ej3-zona-ORIGINAL-con-errores.db`. Copiar el ORIGINAL y corregirlo vos de a un error |
| DHCP (2025 Ej I, simulacro Ej 4) | `~/Protos/scripts/practicar-dhcp.sh [tu.conf]`: arma veth, dhcpd y el nmap del enunciado, y después limpia |
| Proxies nginx (2024 Ej I, 2026 Ej 2, 2025 Ej IV, 2022 foo.leak) | copiar el archivo de `ejercicios/parciales/` a sites-available. Para que el upstream resuelva sin la red del parcial, poné el nombre en `/etc/hosts` apuntando a 127.0.0.1 y servilo con otro `server {}` de nginx |
| SOCKS (2024 Ej II, 2026 Ej 3) | `ssh -fN -D 1080 localhost` y usar `-x socks5h://127.0.0.1:1080` contra `http://foo/` |
| Túnel (2022 Ej 2, 2026 Ej 4) | lo mismo que en el parcial, con `localhost` en lugar de pampero (ya funciona `ssh localhost` sin contraseña) |
| Mail (2024 Ej IV) | `nc -C -q 3 localhost 25 < ~/Protos/ejercicios/parciales/2024-2c-ej4-mail-PRUEBA-LOCAL.txt` y leerlo con `mutt` o POP3 |
| Simulacro (los 7 tipos, con otros datos) | `~/Protos/scripts/simulacro.sh montar`, resolver los enunciados de `17-simulacro.md`, `simulacro.sh verificar` y `simulacro.sh limpiar` |

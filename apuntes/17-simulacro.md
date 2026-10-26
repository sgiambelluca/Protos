# 17: Simulacro de parcial práctico (armado por Mateo Andrioli)

**Fuente**: el PDF "Simulacro Parcial Práctico — Protocolos de Comunicación" (24/10/2026),
en `/Users/maratorres/cosas protos/` de la Mac. Lo armó un compañero a partir de los
parciales viejos: **un ejercicio por cada tipo que tomaron**. No trae consignas nuevas (las 7
ya están resueltas en el 14), pero sirve para **practicar a ciegas, con otros datos y con
tiempo**.

| Simulacro | Mismo tipo que (apunte 14) | ¿Se practica en la VM? |
|---|---|---|
| Ej 1: zona `sucursal.foo` rota | 2025 2C Ej III | sí, con `simulacro.sh` |
| Ej 2: `https://seguro.protos.foo` → `http://interno.protos.foo` | 2025 2C Ej IV (casi idéntico) | sí |
| Ej 3: curl por SOCKS + Basic auth | 2024 2C Ej II, 2026 1C Ej 3 | sí |
| Ej 4: DHCP `192.168.90.0/24` | 2025 2C Ej I | sí, con `practicar-dhcp.sh` |
| Ej 5: túnel + `tail -f` de pampero | 2022 2C Ej 2, 2026 1C Ej 4 | sí, con `localhost` haciendo de pampero |
| Ej 6: ruta + nmap + traceroute | 2024 2C Ej III, 2025 2C Ej II | no: necesita la red del laboratorio |
| Ej 7: mail con `X-Parcial: 2026/2` | 2024 2C Ej IV | sí, con el postfix local |

**Cómo usarlo**: 90 minutos para los 7, sin mirar las resoluciones. El legajo de ejemplo es
**6402** (puertos de túnel y casilla de mail). Verificá siempre con **curl**, no con el
navegador: los `*.foo` tienen HSTS precargado. Antes de recargar un servicio, validá con
`nginx -t`, `named-checkzone` o `named-checkconf`. Al terminar, repasá la **checklist antes
de entregar** de `13-comandos-rapidos.md`.

## Practicarlo en esta VM

```bash
~/Protos/scripts/simulacro.sh montar      # levanta lo que en el parcial pone la cátedra
#   ... resolvés los enunciados ...
~/Protos/scripts/simulacro.sh verificar   # OK / FALLA por cada requisito (25 chequeos)
~/Protos/scripts/simulacro.sh limpiar     # saca el entorno Y tu solución, para repetirlo de cero
```

| Ej | Qué arma `montar` | Diferencia con el parcial |
|---|---|---|
| 1 | la zona ORIGINAL en `/etc/bind/zones/db.sucursal.foo`, declarada en `named.conf.local` (bloque `SIMULACRO`). bind la rechaza al cargar | en el parcial te dicen la ruta. Lleva `notify no` porque acá no hay secundarios |
| 2 | `http://interno.protos.foo` (otro `server {}` de nginx) y `127.0.0.1 interno.protos.foo` en `/etc/hosts` | ninguna |
| 3 | `http://recurso.protos.foo:8080/data/`: nginx en `127.0.0.2:8080` con Basic auth (`admin` / `secret123`), que responde según `Accept` y `Accept-Language` (y avisa cuál eligió con `Content-Language`). Y un proxy SOCKS en `proxy.protos.foo:1080` (`ssh -D` a localhost) | acá la VM resuelve `recurso.protos.foo`, así que `socks5://` (sin h) también anda. En el parcial **no** |
| 4 | nada: `practicar-dhcp.sh tu.conf` arma una red veth, levanta dhcpd y corre el nmap | la interfaz es `veth-srv` en vez de una red interna de VirtualBox |
| 5 | `/tmp/pdc`, que recibe una línea nueva cada 2 s | pampero = `localhost`. Al ser la misma máquina, el puerto local tiene que ser otro (ver la resolución) |
| 7 | nada: postfix y dovecot ya están | `RCPT TO` a tu usuario local: un mail a `6402@mail.sebikul.com` saldría de verdad por Internet |

Mientras está montado, `verificar-todo.sh` da **FALLA en `named-checkconf -z`** hasta que
arregles la zona. Es lo esperable.

---

## Enunciados (resolvelos antes de bajar)

### Ej 1: DNS / BIND

Sos el admin de un BIND9 autoritativo para la zona `sucursal.foo`. Después de unos cambios
dejó de resolver y BIND no carga la zona. Encontrá y corregí **todos** los errores, y hacé
que los cambios **se propaguen rápido a los secundarios**. El archivo
(`~/Protos/ejercicios/simulacro/ej1-db.sucursal.foo-ORIGINAL-con-errores.db`):

```
$TTL 604800
@ IN SOA ns2.sucursal.foo. admin@sucursal.foo. (
        2026010501      ; Serial
        604800          ; Refresh
        86400           ; Retry
        2419200         ; Expire
        604800 )        ; Negative Cache TTL
; Name Servers
@       IN NS   ns1.sucursal.foo.
; Mail
@       IN MX   10 mail
; Hosts
ns1     IN A    192.168.50.1
www     IN A    web
mail    IN A    192.168.50.20
```

### Ej 2: nginx reverse proxy sobre HTTPS

`interno.protos.foo` sirve HTTP inseguro. Exponelo por HTTPS: que
`https://seguro.protos.foo` muestre el contenido de `interno.protos.foo` en Firefox, Chrome
y curl, **sin que cambie la URL**, y que `curl https://seguro.protos.foo` funcione **sin
ninguna opción**.

### Ej 3: curl con proxy SOCKS

Con curl, obtené la representación **text/plain en español** de
`http://recurso.protos.foo:8080/data/`. La red no rutea hacia ese host, pero se llega por el
proxy `socks5h://proxy.protos.foo:1080`. El recurso pide autenticación básica, y tenés este
header de un pedido anterior: `Authorization: Basic YWRtaW46c2VjcmV0MTIz`.

### Ej 4: DHCP

Oficina `192.168.90.0/24`: (1) la impresora `08:00:27:1A:2B:3C` siempre con
`192.168.90.8`; (2) todos los clientes con los DNS de Cloudflare (`1.1.1.1` y `1.0.0.1`);
(3) se asigna de la `.20` a la `.150` y el resto queda reservado. Verificar con
`sudo nmap --script broadcast-dhcp-discover`.

### Ej 5: túnel SSH con `tail -f`

Que desde tu host `tail -f archivo.log` muestre en vivo los cambios de `/tmp/pdc` de
`pampero.itba.edu.ar`. Sin túneles, la mitad del puntaje. Si necesitás puertos, usá tu
legajo (6402).

### Ej 6: descubrimiento con rutas y escaneo

`192.168.80.250` es el gateway de la red `10.0.0.0/24`, donde hay un servidor (distinto del
gateway) con una IP que no conocés. Encontralo, decí qué servicios expone, mostrá qué
devuelve por HTTP y qué routers intervienen.

### Ej 7: mail SMTP / MIME

Mandá un correo que cumpla los estándares y: (1) tenga el header `X-Parcial: 2026/2`; (2)
Subject `¡Buenos días!`; (3) remitente con tu nombre, apellido y cuenta del ITBA; (4)
cuerpo `¡Hola mundo!`; (5) entregado a `6402@mail.sebikul.com`; (6) legible en MUAs que
**no** soportan quoted-printable. Verificá por POP3 en `mail.sebikul.com` (usuario y
contraseña: `6402@mail.sebikul.com`).

---

## Resoluciones

### Ej 1: zona sucursal.foo

**Paso 1: que BIND diga qué pasa.**

```
$ named-checkzone sucursal.foo /etc/bind/zones/db.sucursal.foo
dns_rdata_fromtext: ...:14: near 'web': bad dotted quad
zone sucursal.foo/IN: not loaded due to errors.
```

Es **el único error que impide cargar**. Si se corrige sólo esa línea, la zona carga
(`loaded serial 2026010501`), pero quedan errores de lógica que `named-checkzone` no marca.

**Paso 2: la lista completa.**

| # | Original | Problema | Corrección |
|---|---|---|---|
| E1 | `www IN A web` | un A lleva una IPv4, no un nombre ("bad dotted quad"). Además **`web` no existe** en la zona: un `www IN CNAME web` solo cargaría, pero no resolvería nada | `web IN A <IP>` + `www IN CNAME web`, o `www IN A <IP>` |
| E2 | `admin@sucursal.foo.` en el SOA | el mail va con **`.`**. BIND lo carga igual, como la etiqueta `admin\@sucursal` (así lo muestra `dig`): un mail que no existe | `admin.sucursal.foo.` |
| E3 | MNAME `ns2.sucursal.foo.` | el primer campo del SOA es el **primario**: tiene que ser uno de los NS y tener A. `ns2` no es NS ni tiene A | `ns1.sucursal.foo.` |
| E4 | serial `2026010501` | si no se sube, los secundarios no piden la zona nueva | `2026102601` (fecha de hoy + NN) |
| E5 | refresh `604800`, retry `86400`, negative `604800` | refresh de 1 semana: si se pierde el NOTIFY, el secundario tarda una semana. Negative de 1 semana: un NXDOMAIN queda cacheado una semana en los resolvers | refresh `1h`, retry `15m`, negative `5m` |
| E6 | `$TTL 604800` | todo se cachea una semana en los resolvers | `$TTL 1h` |
| ✓ | `@ IN MX 10 mail` | está bien: `mail` tiene su A. Expire (4 semanas) también, porque es mayor que refresh + retry | — |

**Paso 3: el archivo corregido** (`~/Protos/ejercicios/simulacro/ej1-db.sucursal.foo-CORREGIDA.db`,
OK en `named-checkzone`). La IP de `web` es de ejemplo: en el parcial va la del servidor web.

```
$TTL 1h
@ IN SOA ns1.sucursal.foo. admin.sucursal.foo. (
        2026102601      ; Serial
        1h              ; Refresh
        15m             ; Retry
        2419200         ; Expire
        5m )            ; Negative
@       IN NS   ns1.sucursal.foo.
@       IN MX   10 mail
ns1     IN A    192.168.50.1
mail    IN A    192.168.50.20
web     IN A    192.168.50.10
www     IN CNAME web
```

**Paso 4: aplicar y propagar.**

```bash
sudo named-checkzone sucursal.foo /etc/bind/zones/db.sucursal.foo   # OK
sudo rndc reload sucursal.foo           # carga la zona y, con el serial nuevo, avisa (NOTIFY) a los secundarios
dig +norec @localhost sucursal.foo SOA  # "flags: qr aa" y el serial nuevo
dig @localhost www.sucursal.foo         # CNAME web -> A 192.168.50.10
```

**Qué propaga a los secundarios y qué no**: lo que hace que el secundario se entere **ya**
es el **serial más alto + NOTIFY** (`rndc reload`). El refresh es el plan B si el NOTIFY se
pierde. El negative TTL y el `$TTL` **no tienen nada que ver con los secundarios**: son lo
que cachean los resolvers. Bajarlos sirve para que los próximos cambios se vean antes.

**Probado en la VM** con `simulacro.sh`: la zona original no carga ("bad dotted quad"); con
la corregida, los 9 chequeos del Ej 1 dan OK. Arreglando sólo `www`, la zona carga pero
`verificar` marca el serial, el `@`, el MNAME y los tiempos.

### Ej 2: https://seguro.protos.foo → http://interno.protos.foo

Es el 2025 2C Ej IV con otro backend: **proxy** (no redirect, porque la URL no cambia) con
TLS terminado en nuestro nginx. El archivo está en
`~/Protos/ejercicios/simulacro/ej2-nginx-seguro.protos.foo`.

```bash
# 1) nombres: interno tiene que resolver ANTES del nginx -t ("host not found in upstream")
getent hosts interno.protos.foo          # en el parcial, por el DNS del lab o /etc/hosts
echo "127.0.0.1 seguro.protos.foo" | sudo tee -a /etc/hosts

# 2) certificado autofirmado CON SAN
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
     -keyout /etc/ssl/private/seguro.key -out /etc/ssl/certs/seguro.crt \
     -subj "/CN=seguro.protos.foo" -addext "subjectAltName=DNS:seguro.protos.foo"

# 3) confiable para el SISTEMA (el que usa curl)
sudo cp /etc/ssl/certs/seguro.crt /usr/local/share/ca-certificates/seguro.crt   # la extensión .crt es obligatoria
sudo update-ca-certificates                                                      # "1 added"

# 4) nginx
sudo cp ~/Protos/ejercicios/simulacro/ej2-nginx-seguro.protos.foo /etc/nginx/sites-available/seguro
sudo ln -s /etc/nginx/sites-available/seguro /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl https://seguro.protos.foo           # "Contenido de interno.protos.foo ..." sin error de TLS
```

```nginx
server {
    listen 443 ssl;
    server_name seguro.protos.foo;
    ssl_certificate     /etc/ssl/certs/seguro.crt;
    ssl_certificate_key /etc/ssl/private/seguro.key;
    location / {
        proxy_pass http://interno.protos.foo;   # Host: interno.protos.foo ya va por defecto
    }
}
```

**Para que ande también en Firefox y Chrome** (lo pide la consigna):

- El certificado necesita **SAN**: los navegadores ignoran el CN. curl acepta los dos (lo
  probé con uno sólo con CN: devolvió 200).
- Los navegadores **no usan** el almacén de `update-ca-certificates`. Y en un `.foo` (HSTS)
  no aparece el botón de "aceptar el riesgo". En esta VM lo más simple es **mkcert**, cuya CA
  ya está instalada en el sistema y en Firefox:

  ```bash
  mkcert seguro.protos.foo                         # SIN sudo: con sudo usaría otra CA (la de root)
  sudo cp seguro.protos.foo.pem     /etc/ssl/certs/seguro.crt
  sudo cp seguro.protos.foo-key.pem /etc/ssl/private/seguro.key
  ```

**Probado en la VM**: con el certificado de openssl con SAN, los 5 chequeos del Ej 2 dan OK
(`curl` sin flags trae lo de interno, HTTP 200, SAN presente).

### Ej 3: curl por SOCKS a recurso.protos.foo

```bash
echo YWRtaW46c2VjcmV0MTIz | base64 -d          # admin:secret123

curl -x socks5h://proxy.protos.foo:1080 \
     -u admin:secret123 \
     -H 'Accept: text/plain' \
     -H 'Accept-Language: es' \
     http://recurso.protos.foo:8080/data/
```

- **`socks5h`**: con la **h**, el nombre lo resuelve **el proxy**. Tu máquina no conoce esa
  red, así que con `socks5://` curl intenta resolverlo y falla.
- **`Accept` y `Accept-Language`**: negociación de contenido. Pedí **sólo** `es`.
- **`-u admin:secret123`** genera exactamente el mismo header. También vale pasar el header
  tal cual: `-H 'Authorization: Basic YWRtaW46c2VjcmV0MTIz'`.

**Probado en la VM** (con el entorno de `simulacro.sh`): con `-i` se ve `HTTP/1.1 200`,
`Content-Type: text/plain; charset=utf-8`, `Vary: Accept, Accept-Language` y el texto en
español. Sin `Accept-Language` responde en inglés; sin `Accept`, HTML; sin credenciales, 401.

### Ej 4: DHCP 192.168.90.0/24

Igual que 2025 2C Ej I. El archivo está en `~/Protos/ejercicios/simulacro/ej4-dhcpd.conf`.

```bash
sudo ip addr add 192.168.90.1/24 dev enpXsY      # la interfaz de la red interna, con una IP de esa red
sudo nano /etc/default/isc-dhcp-server           # INTERFACESv4="enpXsY"
sudo nano /etc/dhcp/dhcpd.conf                   # lo de abajo
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf
sudo systemctl restart isc-dhcp-server
sudo nmap --script broadcast-dhcp-discover --script-args "broadcast-dhcp-discover.mac=AA:BB:CC:DD:EE:FF"   # -> .20
sudo nmap --script broadcast-dhcp-discover --script-args "broadcast-dhcp-discover.mac=08:00:27:1A:2B:3C"   # -> .8
```

```
subnet 192.168.90.0 netmask 255.255.255.0 {
    range 192.168.90.20 192.168.90.150;
    option routers 192.168.90.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.90.255;
    option domain-name-servers 1.1.1.1, 1.0.0.1;
}
host impresora {
    hardware ethernet 08:00:27:1A:2B:3C;
    fixed-address 192.168.90.8;              # FUERA del range
}
```

**Ojo con la MAC**: el bit más bajo del primer byte indica **multicast**. Si el primer byte es
impar (por ejemplo `0B` = `00001011`), es una dirección multicast, y una placa de red no
puede tenerla. Si al copiarla te queda así, la copiaste mal. `08:00:27` es el prefijo de
VirtualBox.

**Probado en la VM**: `practicar-dhcp.sh ~/Protos/ejercicios/simulacro/ej4-dhcpd.conf`
ofreció `.20` a una MAC cualquiera y `.8` a la impresora, con router `.1` y los DNS
`1.1.1.1, 1.0.0.1`. La config del PDF (con el `host` adentro del `subnet`) da lo mismo.

### Ej 5: túnel SSH + tail -f

**En el parcial (dos máquinas)** puede ser el mismo puerto en las dos puntas:

```bash
nc -l localhost 6402 > archivo.log                                             # 1) mi máquina, PRIMERO
ssh -R 6402:localhost:6402 usuario@pampero.itba.edu.ar 'tail -f /tmp/pdc | nc localhost 6402'   # 2) mi máquina
tail -f archivo.log                                                            # 3) mi máquina, otra terminal
```

`-R 6402:localhost:6402`: pampero escucha en **su** 6402, y lo que entra ahí sale por **mi**
`localhost:6402`. El `nc -l` tiene que estar escuchando antes; si no, el canal falla
("connect_to localhost port 6402: failed"). La variante con `-L` también vale (está en el
14). Sin túnel (mitad del puntaje): `ssh usuario@pampero 'tail -f /tmp/pdc' > archivo.log`.

**En la VM (una sola máquina)** el puerto local tiene que ser **otro**:

```bash
nc -l 127.0.0.1 8099 > archivo.log
ssh -R 6402:localhost:8099 localhost 'tail -f /tmp/pdc | nc localhost 6402'
tail -f archivo.log
```

Con el mismo puerto en una sola máquina, el `nc -l` ocupa `127.0.0.1:6402` y sshd sólo puede
abrir `[::1]:6402`. El `nc localhost 6402` de "pampero" puede terminar hablando directo con
tu `nc -l`, sin pasar por el túnel (con `-R 127.0.0.1:6402:...` sí falla: "remote port
forwarding failed for listen port 6402").

**Probado en la VM**: con `/tmp/pdc` escribiéndose cada 2 s, `archivo.log` recibió las
últimas 10 líneas y después una nueva cada 2 s.

### Ej 6: rutas + escaneo (red del laboratorio, no se puede probar acá)

Igual que 2025 2C Ej II:

```bash
ping -c2 192.168.80.250                              # llego al gateway (VM en Bridge a la red del lab)
sudo ip route add 10.0.0.0/24 via 192.168.80.250     # LA CLAVE: ruta a la red de atrás
sudo nmap -sn 10.0.0.0/24                            # hosts vivos: el que no es el gateway es el servidor
#   si no aparece nada (ICMP filtrado):  sudo nmap -Pn -p 22,80,443,8080 10.0.0.0/24 --open
sudo nmap -sS -sV -Pn 10.0.0.X                       # servicios
curl -v http://10.0.0.X:PUERTO/                      # HTTP
traceroute -n 10.0.0.X                               # routers: el primer salto es 192.168.80.250
```

### Ej 7: mail con X-Parcial: 2026/2

Igual que 2024 2C Ej IV: el requisito 6 obliga a mandar el cuerpo en **base64**, y el
Subject con `¡` e `í` va como **encoded-word**.

```bash
printf '%s' '¡Buenos días!' | base64     # wqFCdWVub3MgZMOtYXMh
printf '%s' '¡Hola mundo!'  | base64     # wqFIb2xhIG11bmRvIQ==   (con \r\n al final: wqFIb2xhIG11bmRvIQ0K)
```

```
$ nc -C mail.sebikul.com 25
EHLO mi-host
MAIL FROM:<usuario@itba.edu.ar>
RCPT TO:<6402@mail.sebikul.com>
DATA
Date: Mon, 26 Oct 2026 18:00:00 -0300
Message-ID: <20261026180000.6402@itba.edu.ar>
From: Nombre Apellido <usuario@itba.edu.ar>
To: <6402@mail.sebikul.com>
Subject: =?UTF-8?B?wqFCdWVub3MgZMOtYXMh?=
X-Parcial: 2026/2
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

wqFIb2xhIG11bmRvIQ0K
.
QUIT
```

Si tu nombre tiene tildes: `From: =?UTF-8?B?<base64 del nombre>?= <usuario@itba.edu.ar>`.
Verificación por POP3: `nc -C mail.sebikul.com 110`, después `USER 6402@mail.sebikul.com`,
`PASS 6402@mail.sebikul.com`, `LIST`, `RETR 1` y `QUIT`.

**Probado en la VM**: `nc -C -q 3 localhost 25 < ~/Protos/ejercicios/simulacro/ej7-mail-PRUEBA-LOCAL.txt`
(el mismo mail con `RCPT TO` local) llegó a `~/Maildir` y pasó los 7 chequeos del Ej 7. Ojo:
desde localhost, postfix agrega `Date`, `Message-Id` y `From` si faltan, así que acá no
notás si te los olvidaste.

---

## Errores en la resolución del PDF

Todo probado en la VM.

| Ej | Lo que dice el PDF | Lo correcto |
|---|---|---|
| 1 | "Cuatro errores impiden cargar la zona" | **Sólo `www IN A web`** impide cargar. Con `admin@` y `ns2` la zona carga igual: son errores de lógica. Y el punto 4 (el MX) no es un error, lo dice el mismo PDF |
| 1 | `www IN CNAME ns1` | Carga, pero apunta www al servidor DNS sin ningún motivo. Lo que falta es `web`: crearlo con su A (o poner la IP del servidor web) |
| 1 | bajar el negative TTL "para propagar rápido" | A los secundarios los actualizan el **serial y el NOTIFY**. El negative TTL es el tiempo que los resolvers cachean un NXDOMAIN |
| 2 | certificado sólo con CN y `update-ca-certificates` | Con curl anda (200). Pero la consigna pide también **Firefox y Chrome**: exigen SAN y no usan ese almacén (ver mkcert arriba) |
| 2 | `proxy_set_header Host interno.protos.foo;` | No es un error, pero sobra: es el valor por defecto (`$proxy_host`) |
| 5 | "conviene `-R` porque tu máquina puede estar detrás de NAT" | La conexión SSH la abrís vos en los dos casos, así que el NAT no importa: con `-L` también anda |
| 7 | `From: Mateo <TUUSUARIO@itba.edu.ar>` | La consigna pide nombre **y apellido**. Con tildes, como encoded-word |

Lo demás está bien: los base64 del Ej 7, el `socks5h` y el decodificado de credenciales del
Ej 3, la config del DHCP y los comandos del Ej 6.

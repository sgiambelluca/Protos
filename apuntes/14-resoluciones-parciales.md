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

## Conceptos que se repiten en las aclaraciones

Las **aclaraciones** (las citas que empiezan con "Aclaración" y las líneas `# ↳` dentro de los
comandos) responden dudas puntuales. Estos tres conceptos aparecen en varias, así que están
explicados una sola vez acá.

### Concepto A: cómo se resuelve un nombre (y socks5 contra socks5h)

Cuando un programa (curl, nc, nginx, ssh) recibe un nombre, se lo pregunta al sistema. Linux
mira primero `/etc/hosts` y, si no está, le pregunta al servidor DNS configurado (en el
laboratorio, el que te da la red). `getent hosts nombre` hace exactamente esa consulta:

```
$ getent hosts foo                   # está en /etc/hosts de la VM
127.0.0.1       foo bar
$ getent hosts parcial.protos.foo    # no está en /etc/hosts: lo contesta el DNS
192.168.0.172   parcial.protos.foo
```

Con un proxy SOCKS, **¿quién resuelve el nombre?**

- `socks5://`: lo resuelve **tu máquina**, y le pasa la IP al proxy.
- `socks5h://`: le pasa el **nombre** al proxy, y lo resuelve él (h = hostname).

Prueba real: `foo` existe sólo adentro de la VM (su `/etc/hosts` dice `127.0.0.1 foo`) y la Mac
no lo conoce. Con `ssh -D 1081 ubuntua` la Mac tiene un proxy SOCKS que sale desde la VM:

```
$ curl http://foo/                                   # Mac, sin proxy
curl: (6) Could not resolve host: foo                <- la Mac no sabe qué es "foo"
$ curl -x socks5://127.0.0.1:1081 http://foo/        # resuelve la MAC
curl: (97) Could not resolve host: foo               <- falla antes de hablar con el proxy
$ curl -x socks5h://127.0.0.1:1081 http://foo/       # resuelve el PROXY (la VM)
<h1>Bienvenido a Foo</h1>                            <- anda
```

En el parcial es igual: `ejercicio2.sebikul.com` sólo lo conoce la red del proxy, así que hace
falta la `h`.

### Concepto B: IP, MAC y gateway

Cada paquete lleva **dos direcciones de destino**:

| Dirección | Capa | Para qué | ¿Cambia en el camino? |
|---|---|---|---|
| IP de destino | red (IP) | a quién va **al final** | no: es la misma de punta a punta |
| MAC de destino | enlace (Ethernet o WiFi) | a quién se lo entregás **en este cable** (el próximo salto) | sí: se reescribe en cada salto |

La **interfaz** es la placa de red (en la VM, `enp0s8`): tiene una MAC (de fábrica) y una IP con
máscara. Con `10.0.2.15/24`, la red son las 256 direcciones `10.0.2.0`–`10.0.2.255`, y a esas
les habla directo. Para todo lo demás usa la tabla de ruteo:

```
$ ip route
default via 10.0.2.2 dev enp0s8 ...           <- lo que no sea de mi red va a 10.0.2.2 (el gateway)
10.0.2.0/24 dev enp0s8 ... src 10.0.2.15      <- mi red: la hablo directo
$ ip neigh
10.0.2.2 lladdr 52:54:00:12:35:00 REACHABLE   <- la MAC del gateway (la averigua con ARP)
```

Captura real de un ping a 1.1.1.1 (`tcpdump -e` muestra las MAC):

```
08:00:27:c2:62:e3 > 52:54:00:12:35:00, ...  10.0.2.15 > 1.1.1.1: ICMP echo request
   MAC origen (yo)    MAC destino           IP origen   IP destino
                      = el GATEWAY                      = el destino FINAL
```

La IP dice adónde va; la MAC, a quién se lo entrego ahora. El gateway lo recibe, ve que la IP
no es suya y lo reenvía al siguiente salto con otra MAC de destino. Es como un sobre: la dirección
del destinatario no cambia, pero se lo das al correo del barrio.

### Concepto C: caché y TTL en DNS

Los resolvers (el de tu ISP, 8.8.8.8, el del laboratorio) guardan cada respuesta durante el TTL
que venía en ella, y mientras dure no le vuelven a preguntar a tu servidor:

- **Lunes 10:00**: un resolver pregunta por `www` y recibe `1.1.1.1` con TTL de 1 semana.
- **Lunes 12:00**: cambiás `www` a `2.2.2.2`. Ese resolver sigue respondiendo `1.1.1.1` hasta el
  lunes siguiente, y no lo podés obligar a olvidarlo.
- **Si el viernes anterior hubieras bajado el TTL a 1 h**, el lunes nadie lo tendría guardado más
  de una hora, y el cambio se vería en 1 h.

Lo mismo pasa con los "no existe" (NXDOMAIN): duran el negative TTL del SOA. Con `dig` se ve el
TTL bajando mientras la respuesta sale de la caché (ejemplo):

```
$ dig +noall +answer google.com
google.com.   300   IN A 142.250.0.1      <- primera vez: 300 s
$ dig +noall +answer google.com           # 20 s después
google.com.   280   IN A 142.250.0.1      <- viene de la caché: le quedan 280 s
```
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
           # ↳ Aclaración: le dice a nginx "al backend mandale X-Parcial-Protos con el valor que trajo el cliente".
           #   Acá SOBRA: nginx ya reenvía solo todos los headers. Sirve para CAMBIAR o AGREGAR uno.
           #   Probado con un backend que muestra lo que le llega (curl -H "X-Parcial-Protos: 123"):
           #     sin nada                                   -> X-Parcial-Protos: 123   (pasa solo)
           #     proxy_set_header X-Parcial-Protos "hola";  -> X-Parcial-Protos: hola  (cambia el valor)
           #     proxy_set_header Metadata true;            -> Metadata: true          (agrega uno, como en 2026 Ej 2)
       }
   }
   ```

4. **Habilitar y recargar**:

   ```bash
   sudo ln -s /etc/nginx/sites-available/foo.example.org /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```

   > **Aclaración**: sí, `nginx -t` revisa la sintaxis sin aplicar nada, y el `&&` hace que el reload
   > corra **sólo** si el `-t` salió bien. Si falta un `;`, te dice el archivo y la línea, por ejemplo
   > `nginx: [emerg] unexpected "}" in /etc/nginx/sites-enabled/foo.example.org:6` (falta el `;` de la
   > línea anterior). Mientras tanto, nginx sigue funcionando con la configuración vieja.

5. **Verificar**: `curl -v http://foo.example.org/` (la respuesta trae `X-Parcial-Protos`)
   y `curl http://foo.example.org/cualquier/cosa`.
   > **Aclaración**: sí, lo pide la consigna. Por eso el `proxy_pass` va sin ruta: nginx pasa la ruta
   > tal cual. `curl http://foo.example.org/img/logo.png` → nginx pide `http://protos.sebikul.com/img/logo.png`.

**Puntos clave**:

- **`Host`**: no hay que pisarlo con `$host`. protos.sebikul.com es un virtual host y
  necesita recibir `Host: protos.sebikul.com`, que es el default de nginx. Si le llega
  `Host: foo.example.org`, devuelve otra cosa.
  > **Aclaración (virtual hosts)**: una misma IP puede tener muchos sitios, y el servidor elige cuál
  > mostrar según el header `Host`. En la VM, `curl -H 'Host: foo' http://127.0.0.1/` da "Bienvenido a
  > Foo" y `curl -H 'Host: bar' http://127.0.0.1/` da "Bienvenido a Bar": misma IP y puerto, otro sitio.
  > El cliente manda `Host: foo.example.org`, y nginx lo usa para elegir su `server {}`. Al reenviar,
  > lo cambia **solo** por el del `proxy_pass`. Probado con un backend que muestra lo que le llega:
  >
  > ```
  > proxy_pass http://backend.demo:8098;      -> al backend le llega  Host: backend.demo:8098   (bien)
  > + proxy_set_header Host $host;            -> al backend le llega  Host: demo.local          (el del cliente: no es suyo)
  > ```
  >
  > Resumen: **no escribas ningún `proxy_set_header Host`**; se completa solo con el nombre correcto.
- **`$http_x_parcial_protos`**: cada header del pedido está disponible como `$http_` + el
  nombre en minúsculas, con `-` → `_`.
  > **Aclaración**: `$http_x_parcial_protos` es el **nombre interno** con el que la config de nginx
  > lee el valor de ese header. No renombra nada: el header sigue viajando como `X-Parcial-Protos`, y
  > el cliente nunca ve esa variable. Se arma con `$http_` + el nombre en minúsculas, con `-` → `_`.
  > Sirve cuando querés usar el valor en la config (copiarlo, loguearlo, decidir algo). Probado:
  >
  > ```
  > add_header X-Eco $http_x_parcial_protos;     # devuelve en la respuesta lo que mandó el cliente
  > curl -I -H "X-Parcial-Protos: 123" ...   ->  X-Eco: 123
  > curl -I -H "X-Parcial-Protos: abc" ...   ->  X-Eco: abc      (misma config, otro pedido, otro valor)
  > ```
  >
  > Otras familias: `$http_user_agent` (header `User-Agent`), `$arg_legajo` (`?legajo=...` en la
  > URL), `$cookie_sesion` (la cookie `sesion`). En este ejercicio no hace falta usarla.
- **Por qué alcanza sin configurar nada**: nginx ya pasa los headers en los dos sentidos.
  Lo probé con un backend que devuelve los headers que recibe: un `X-Parcial-Protos` que
  manda el cliente llega al backend, y uno que pone el backend en la respuesta llega a curl.
  Las únicas excepciones por defecto son algunos headers que oculta (`Server`, `Date`,
  `X-Accel-*`) y los headers con `_` en el nombre.

### Ej II: obtener text/plain en español de http://ejercicio2.sebikul.com:8080/foo/ por un proxy SOCKS
> **Aclaración: ¿qué es un proxy SOCKS?** Un intermediario genérico: tu programa le dice "conectame
> a tal host y puerto", el proxy abre esa conexión y pasa los bytes de un lado al otro sin mirar qué
> son (HTTP, SSH, lo que sea). Sirve para llegar a algo **desde donde está el proxy**: si vos no
> llegás pero el proxy sí, se conecta por vos. `ssh -D 1080 host` arma uno.
>
> ```
> tu máquina ──"conectame a ejercicio2.sebikul.com:8080"──► proxy.sebikul.com:1080 ──► ejercicio2.sebikul.com:8080
> ```
>
> La diferencia entre `socks5` y `socks5h`, con una prueba real, está en el **Concepto A** (al principio).
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
     > **Aclaración**: ver el **Concepto A** al principio: socks5 contra socks5h, con una prueba real
     > desde la Mac a través de la VM.
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
#   ↳ sí: muestra cada interfaz con su IP y su máscara. Buscá la línea "inet": en Bridge en el lab
#     sería algo como "inet 192.168.1.57/24" (misma red que el gateway). En la VM en NAT: "inet 10.0.2.15/24".
ping -c2 192.168.1.3                            # 1) llego al gateway
#   ↳ -c = count: manda 2 pings y termina (sin -c sigue hasta Ctrl+C).
#     Salida esperada: "2 packets transmitted, 2 received, 0% packet loss"
sudo ip route add 10.0.0.0/24 via 192.168.1.3   # 2) LA CLAVE: ruta a la red de atrás del gateway
ip route get 10.0.0.1                           #    -> "via 192.168.1.3 dev ..."
#   ↳ sí, es un chequeo: no cambia nada, le pregunta al kernel qué ruta usaría. Tiene que decir
#     "via 192.168.1.3"; si dice el router de siempre, la ruta no quedó (ver Concepto B).
sudo nmap -sS -sV -Pn 10.0.0.1                  # 3) servicios. -Pn: no descartar el host si no responde ping
#   (para UDP:  sudo nmap -sU --top-ports 50 10.0.0.1)
#   ↳ sí: sin -p prueba los 1000 puertos TCP más comunes (en la VM: "Not shown: 985 closed" + 15 abiertos).
#     -sS = escaneo SYN, -sV = programa y versión de cada puerto abierto, -Pn = escanear aunque no conteste el ping.
#     Todos los puertos: -p-   UDP: -sU.   Ej. de salida:  22/tcp open ssh OpenSSH 9.6   80/tcp open http nginx 1.24
curl -v http://10.0.0.1/                        # 4) si nmap mostró http (80 u otro puerto: curl http://10.0.0.1:PUERTO/)
traceroute -n 10.0.0.1                          # 5) routers: el primer salto tiene que ser 192.168.1.3
#   si aparecen *: traceroute -I (ICMP) o sudo traceroute -T -p 80 (TCP al puerto abierto)
```

**Por qué hace falta el paso 2**: sin esa ruta, los paquetes a 10.0.0.1 salen por la
**default route** (el router del laboratorio, que no conoce esa red) y no llegan. La ruta
hace que la trama vaya a la **MAC de 192.168.1.3**, aunque la IP destino siga siendo
10.0.0.1.

> **Aclaración**: ver el **Concepto B** al principio (IP y MAC, con una captura real). En este
> caso, tu máquina sólo conoce su red (192.168.1.x) y la default (el router del laboratorio). Sin
> la ruta, lo de 10.0.0.x va al router del laboratorio, que no conoce esa red y lo tira. Con
> `ip route add 10.0.0.0/24 via 192.168.1.3`, el paquete sale con IP destino 10.0.0.1 pero
> entregado a la MAC de 192.168.1.3, que sí sabe llegar.

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

**Aclaraciones de la sesión SMTP** (van afuera del bloque para poder copiarlo tal cual):

- **`nc -C mail.sebikul.com 25`**: te conectás al servidor de correo (SMTP, puerto 25) para
  mandarle el mail. El `-C` hace que cada Enter mande `\r\n`, que es lo que exige SMTP.
- **¿Cómo sabe qué es `mail.sebikul.com`?** `nc` lo resuelve como cualquier programa (ver
  **Concepto A**): le pregunta al DNS configurado en tu máquina. Acá no se usa el MX, porque vos
  elegís a qué servidor conectarte. Hoy `mail.sebikul.com` no existe en el DNS público
  (`dig +short mail.sebikul.com` no devuelve nada), así que en el parcial lo resolvía el DNS de la
  red del laboratorio: conviene usar ese y no 8.8.8.8.
- **`EHLO mi-host`**: el saludo de SMTP. Te presentás con tu nombre de máquina y el servidor te
  dice qué soporta (`250-PIPELINING`, `250-SIZE 10240000`, `250-STARTTLS`, `250-8BITMIME`,
  `250 SMTPUTF8`). Casi nunca verifican el nombre, pero va el de tu máquina o tu dominio. Sin
  `EHLO` (o `HELO`) no te acepta el `MAIL FROM`.
- **`Subject: =?UTF-8?B?...?=`**: no está *encriptado*, está **codificado**. base64 no tiene clave:
  `echo wqFCdWVub3MgZMOtYXMh | base64 -d` da `¡Buenos días!`. Se hace porque los headers sólo
  admiten ASCII. El formato es `=?charset?B?texto?=`: `UTF-8` dice cómo leer los bytes y `B` es
  base64 (`Q` sería una variante de quoted-printable). El cliente de mail lo decodifica al mostrarlo.
- **El cuerpo `wqFIb2xhIG11bmRvIQ0K`**: mismo objetivo, otro mecanismo. No usa `=?...?=`: lo
  describen los headers MIME (`Content-Type: text/plain; charset=UTF-8` dice qué es, y
  `Content-Transfer-Encoding: base64` cómo viaja). `echo wqFIb2xhIG11bmRvIQ0K | base64 -d` da
  `¡Hola mundo!` + `\r\n`. En quoted-printable sería `=C2=A1Hola mundo!`, que es lo que prohíbe el
  requisito (f).

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

**Aclaraciones de POP3**:

- **Puerto 110 = POP3, no SMTP.** SMTP (25) es para **mandar**; POP3 (110) es para **leer** tu
  casilla. Acá te conectás para ver si el mail llegó.
- **`USER` + `PASS`**: el login (viaja sin cifrar). Lo que ves son los mails que esa casilla **recibió**.
- **`LIST`** no baja nada: lista los mails con número y tamaño. **`RETR n`** es el *get*: te
  muestra el mail `n` completo y crudo. Ahí comprobás los requisitos: el `X-Parcial`, el Subject
  codificado y el cuerpo en base64. Ejemplo de sesión:

  ```
  +OK Dovecot ready.
  USER 65522@mail.sebikul.com
  +OK
  PASS 65522@mail.sebikul.com
  +OK Logged in.
  LIST
  +OK 2 messages:
  1 512                  <- mail 1, de 512 bytes
  2 1830                 <- mail 2, de 1830 bytes
  .
  RETR 2
  +OK 1830 octets
  X-Parcial: 2024/2
  Subject: =?UTF-8?B?wqFCdWVub3MgZMOtYXMh?=
  Content-Transfer-Encoding: base64
  ...
  wqFIb2xhIG11bmRvIQ0K
  .
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

> **Aclaración**: lo que importa es **en qué interfaz contesta dhcpd**. La red del laboratorio ya
> tiene su DHCP; si el tuyo contestara también por la interfaz que está en esa red, a tus compañeros
> les podría llegar tu oferta (`192.168.100.x`, una red que ahí no existe) y se quedarían sin
> internet: un "DHCP trucho". Por eso, un adaptador de la VM en "Red interna" de VirtualBox y dhcpd
> escuchando sólo ahí (`INTERFACESv4`). La VM puede tener además otro adaptador en la red del lab:
> lo que no puede es servir DHCP por ese. Paso a paso completo, con DORA y pruebas, en
> `18-dhcp-paso-a-paso.md`.

```bash
# 1) una interfaz en red INTERNA (VirtualBox: Adaptador 2 -> "Red interna") con IP en esa red
ip -br link                                     # ver el nombre, ej. enp0s9
#   ↳ no crea nada: lista las interfaces (-br = breve) con nombre, estado y MAC, para saber cómo se llama
#     la de la red interna. La red interna se crea en VirtualBox (Configuración → Red → Adaptador 2 →
#     "Red interna"). Ej.:  lo UNKNOWN ...   enp0s8 UP 08:00:27:...   enp0s9 DOWN 08:00:27:...
sudo ip addr add 192.168.100.1/24 dev enp0s9
#   ↳ le da a TU VM (el servidor DHCP) una IP fija en esa red, a mano: el servidor no se la puede pedir a
#     sí mismo. Sirve para que dhcpd sepa qué "subnet" repartir por esa interfaz, es la IP desde la que
#     contesta ("Server Identifier: 192.168.100.1") y acá también es el gateway. El .1 es costumbre: puede
#     ser otra de la red, fuera del range. No toca la tabla de ruteo: el kernel agrega solo la ruta
#     "192.168.100.0/24 dev enp0s9".
sudo ip link set enp0s9 up
#   ↳ prende la interfaz: si está DOWN no manda ni recibe nada aunque tenga IP (en ip -br link pasa de DOWN a UP).

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
#   ↳ dhcpd busca en el .conf un "subnet" que contenga la IP de la interfaz. Probado en la VM:
#       sin IP                 -> No subnet declaration for veth-x (no IPv4 addresses).
#       con 192.168.50.1/24    -> No subnet declaration for veth-x (192.168.50.1).    (IP de otra red)
#       con 192.168.100.1/24   -> Listening on LPF/veth-x/.../192.168.100.0/24        (arranca)

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
#   ↳ nmap -sn sólo descubre qué hosts están vivos en toda la red, sin escanear puertos (prueba las 256
#     IPs con ping y paquetes al 80 y al 443). Ej.: "Nmap scan report for 10.0.0.1" (el gateway) y
#     "Nmap scan report for 10.0.0.37" (el servidor). La alternativa -Pn -p ... --open prueba esos
#     puertos en todas las IPs sin preguntar antes si están vivas (por si bloquean el ping).
sudo nmap -sS -sV -Pn 10.0.0.X                       # 3) servicios del servidor encontrado
curl -v http://10.0.0.X:PUERTO/                      # 4) acceso HTTP
traceroute -n 10.0.0.X                               # 5) routers (el primero, 192.168.50.250)
#   ↳ sí: manda paquetes con TTL 1, 2, 3...; cada router le resta 1 y el que lo deja en 0 lo descarta y te
#     avisa (ICMP "time exceeded"), así ves la IP de cada salto. -n = sin buscar nombres. Ej.:
#        1  192.168.50.250  0.5 ms     <- el gateway
#        2  10.0.0.37       0.9 ms     <- el destino
#     "* * *" es un salto que no contesta.
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

> **Aclaración: refresh, retry, expire y negative.** Los tres primeros los usan los
> **secundarios**; el negative, los **resolvers**. Con el SOA corregido (`1h 15m 2419200 5m`):
>
> | Campo | Quién lo usa | Qué quiere decir |
> |---|---|---|
> | refresh `1h` | secundario | cada 1 h le pregunta al primario su serial; si es mayor, pide la zona |
> | retry `15m` | secundario | si esa consulta falla (primario caído), reintenta cada 15 min |
> | expire `2419200` (4 semanas) | secundario | si pasa ese tiempo sin poder hablar con el primario, deja de responder la zona |
> | negative `5m` | resolvers | un "ese nombre no existe" (NXDOMAIN) se guarda 5 min |
>
> Ejemplo: el secundario chequeó a las 9:20 y el primario se cae a las 10:00. A las 10:20 toca el
> refresh y falla, así que reintenta cada 15 min (10:35, 10:50…). Mientras tanto sigue respondiendo
> con su copia; si en 4 semanas no logra hablar con el primario, deja de responder la zona. Por eso
> expire tiene que ser mayor que refresh + retry.
>
> **"Bajarlo antes"** (E7): ver el **Concepto C** al principio. Si un resolver guardó tu registro
> cuando el TTL era de 1 semana, lo tiene 1 semana aunque ahora lo cambies. Si bajás el TTL a 1 h
> unos días **antes** de un cambio planeado, cuando cambies nadie lo tiene guardado más de 1 h. En
> el parcial alcanza con bajarlo y explicarlo.

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
        5m )       ; Negative Cache TTL ; que era el negative cache TTL?
@       IN NS ns1.it.itba.edu.ar.
@       IN MX 10 mail
ns1     IN A 192.168.70.1
pampero IN A 192.168.70.10
mail    IN A 192.168.70.10
www     IN CNAME pampero
correo  IN CNAME pampero
```

> **Aclaración**: sí: `apuntes/04-dns-y-bind9.md`, secciones "Registros (RR)" y "Sintaxis del
> archivo de zona". Un archivo de zona que funciona: `config/etc/bind/zones/db.foo.pdc.lab`. Cada
> línea es `nombre  [TTL]  clase  tipo  dato`, por ejemplo `www  2w  IN  CNAME  @` (sin TTL, usa el `$TTL`).

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

> **Aclaración**: sí (ver **Concepto C**). Una precisión: no es "la configuración vieja", son los
> resolvers de otros (el de tu ISP, 8.8.8.8) que ya guardaron la respuesta vieja. Hasta que venza
> el TTL de esa respuesta no le vuelven a preguntar a tu servidor, y no los podés obligar.

### Ej IV: https://seguro.protos.foo tiene que servir lo de http://parcial.protos.foo

**Requisitos**: que no cambie la URL y que funcione `curl https://seguro.protos.foo` **sin
opciones** (o sea, sin `-k`). El certificado tiene que ser confiable.

```bash
# 1) nombres
echo "127.0.0.1 seguro.protos.foo" | sudo tee -a /etc/hosts
#   ↳ sí, primero: así seguro.protos.foo apunta a tu máquina y curl llega a tu nginx (Concepto A).
#     Va con "| sudo tee -a" porque "sudo echo ... >> /etc/hosts" da Permission denied: el >> lo hace
#     tu shell, sin root. tee corre como root y -a agrega al final.
getent hosts parcial.protos.foo        # tiene que resolver (por DNS del lab o con /etc/hosts); si no, nginx -t falla
#   ↳ getent pregunta "¿a qué IP resuelve este nombre?" igual que lo hará nginx (Concepto A). Es un chequeo:
#     nginx resuelve el host del proxy_pass al arrancar y, si no puede, nginx -t falla con
#     'host not found in upstream "parcial.protos.foo"'. (Hoy resuelve en el DNS público a 192.168.0.172,
#     una IP privada del laboratorio.)
# 2) certificado autofirmado CON SAN (los navegadores exigen SAN; curl acepta también sólo CN)
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
     -keyout /etc/ssl/private/seguro.key -out /etc/ssl/certs/seguro.crt \
     -subj "/CN=seguro.protos.foo" -addext "subjectAltName=DNS:seguro.protos.foo"
#   (alternativa si mkcert está instalado y su CA ya es confiable:  mkcert seguro.protos.foo)
#   ↳ openssl req -x509        genera un certificado AUTOFIRMADO (sin -x509 sería un pedido para una CA)
#     -newkey rsa:2048         crea también una clave nueva, RSA de 2048 bits
#     -nodes                   la clave sin contraseña (si no, nginx no puede abrirla solo al arrancar)
#     -days 365                vale un año
#     -keyout .../seguro.key   dónde guardar la clave PRIVADA
#     -out .../seguro.crt      dónde guardar el certificado (lo público)
#     -subj "/CN=..."          para qué nombre es, sin preguntarte país, empresa, etc.
#     -addext "subjectAltName=DNS:..."   el nombre en el campo SAN, que es el que miran los navegadores
#     Las "\" del final sólo parten el comando en varias líneas. Para ver qué quedó:
#       openssl x509 -in /etc/ssl/certs/seguro.crt -noout -subject -ext subjectAltName
# 3) hacerlo confiable para el SISTEMA (curl usa este trust store)
sudo cp /etc/ssl/certs/seguro.crt /usr/local/share/ca-certificates/seguro.crt    # la extensión .crt es obligatoria
sudo update-ca-certificates                                                      # "1 added"
#   ↳ curl sólo acepta un certificado firmado por alguien de la lista de confianza del sistema, y uno
#     autofirmado no está. El cp lo deja en la carpeta de certificados agregados por vos (tiene que
#     terminar en .crt) y update-ca-certificates rehace la lista con él ("1 added"). Probado en la VM:
#       antes:   curl: (60) SSL certificate problem: self-signed certificate
#       después: el contenido de parcial.protos.foo
#     Los navegadores usan su propia lista (por eso en el simulacro se usa mkcert).
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

> **Aclaración**: casi. Ese bloque **define el sitio**: escucha en el 443 con TLS (`listen 443 ssl`),
> atiende el nombre `seguro.protos.foo` (`server_name`, el virtual host de 2024 Ej I), muestra ese
> certificado y esa clave, y reenvía todo a `parcial.protos.foo` (`proxy_pass`). El proxy es este
> mismo nginx, y `parcial.protos.foo` es el backend:
>
> ```
> curl https://seguro.protos.foo  ─►  tu nginx (443, TLS con seguro.crt) ──HTTP plano──►  parcial.protos.foo:80
> ```
>
> Estar en `sites-available` no lo activa: hacen falta el symlink en `sites-enabled` y el reload,
> que son los comandos de abajo.

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

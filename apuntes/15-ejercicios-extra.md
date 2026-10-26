# 15: Ejercicios extra tipo parcial (repo Protos-ITBA, `practica/Ejercicios_varios.md`)

Son 11 ejercicios de práctica del repo
[rodrihern/Protos-ITBA](https://github.com/rodrihern/Protos-ITBA) que **no son de un
parcial**, pero tienen el mismo estilo. Cada uno tiene la consigna resumida y la resolución
paso a paso. **Se probaron en la VM el 26/10/2026**, salvo los que necesitan pampero o la red
del ITBA. Los archivos de configuración están en `~/Protos/ejercicios/extra/`.

| # | Tema | Apunte |
|---|---|---|
| 1 | HTTP: conseguir un 304 | 02 |
| 2 | ncat: dos servicios en el mismo puerto, según la IP | 08 |
| 3 | nginx: proxy reverso a un backend **HTTPS** + vhost + default | 03 |
| 4 | Mail a mano: From/To falsos, multipart/alternative en base64 + adjunto | 05 |
| 5 | nginx: responder distinto según la **IP** por la que entró la conexión | 03 |
| 6 | SSH: emular un `-L` usando sólo `-R` | 10 |
| 7 | SSH: por qué `ssh localhost -L1234:127.0.0.1:1234` no anda | 10 |
| 8 | HTTP: provocar "too many redirects" con ncat | 02 |
| 9 | curl: `socks5://` vs `socks5h://` | 02, 10 |
| 10 | bind9: zona carlitos.com.ar | 04 |
| 11 | DNS: seguir una cadena de CNAME | 04 |

## Errores que encontré en el material de práctica del repo

| Dónde | Lo que dice | Lo correcto (probado) |
|---|---|---|
| Ej 3 | poner `127.0.0.1 protos.foo` en /etc/hosts | **No**: nginx resolvería el backend a sí mismo. Además falta `proxy_ssl_server_name on;` para el backend https (sin eso da **502**) |
| Ej 5 | "no hay que tocar los otros sitios" | Al poner `listen 127.0.0.1:80`, ese bloque se queda con **todos** los pedidos a 127.0.0.1, y `http://foo/` deja de andar |
| Ej 10 | MX a mail20/30/40 sin registros A | Faltan los A ("MX ... has no address records") |
| cheat_01 / 2024 Ej I | "nginx no reenvía headers personalizados por defecto" | Sí los reenvía (probado: ver apunte 14) |
| cheat_03 | dovecot `mail_location = maildir:~/Maildir` | Es sintaxis de la **2.3**. En la 2.4 (la de esta VM) es `mail_driver = maildir` + `mail_path = ~/Maildir` (Laboratorio.md lo tiene bien) |
| cheat_04 | "payload disponible = MTU − 52" (resta Ethernet) | La MTU (1500) **no incluye** el header Ethernet: para UDP son 1500 − 20 − 8 = **1472** bytes |
| guia_respuestas E92 | `deny booting` → el server responde DHCP NAK | **No responde nada**: el log dice `DHCPDISCOVER from ... booting disallowed` (probado con `practicar-dhcp.sh`) |
| guia_respuestas E101 | `cat /etc/passwd > nc localhost 9999` | Es un **pipe**: `cat /etc/passwd \| nc localhost 9999` (con `>` crea un archivo llamado "nc") |

---

## Ej 1: obtener una respuesta HTTP 304 de example.com / example.org

1. Pedir sólo los headers y anotar el validador: `curl -sI https://example.org`. Aparece
   `Last-Modified: ...` y/o `ETag: "..."`.
2. Repetir el pedido **condicional** con ese valor:

   ```bash
   curl -I -H 'If-Modified-Since: Sat, 24 Oct 2026 11:34:40 GMT' https://example.org   # -> 304
   curl -I -H 'If-None-Match: "6a101246-210"'                   https://example.org   # -> 304 (con el ETag)
   ```

**Probado**: `HTTP/2 304`. Un 304 **no tiene cuerpo**: le dice al cliente "usá lo que tenés en
cache".

## Ej 2: en el puerto X de pampero, que "127.0.0.1" responda "hola" y "10.16.1.100" responda "chau"

Un socket que escucha se ata a **IP + puerto**. Dos procesos pueden usar el mismo puerto si
cada uno se ata a una IP distinta.

```bash
ncat -l 127.0.0.1   X -k -c "echo hola" &      # -l escuchar, -k seguir aceptando, -c ejecutar un comando por conexión
ncat -l 10.16.1.100 X -k -c "echo chau" &
ncat 127.0.0.1 X --recv-only                   # hola
ncat 10.16.1.100 X --recv-only                 # chau
```

**Probado** en la VM con 127.0.0.1 y 10.0.2.15 en el puerto 3333: devolvió `hola` y `chau`.
Si uno escuchara en `0.0.0.0:X` (todas las IPs), el segundo daría
`Address already in use`.

## Ej 3: nginx: "puerro" como proxy a https://protos.foo/ (cualquier ruta), "hola" estático y el resto "what?". Tiene que andar `curl puerro`

1. **Nombres**: `127.0.0.1 puerro hola` en `/etc/hosts`. **No** agregar protos.foo: ese
   nombre tiene que resolver a su IP real.
2. **Sitios** (archivo completo en `~/Protos/ejercicios/extra/ej3-nginx-puerro`):

   ```nginx
   server {
       listen 80;
       server_name puerro;
       location / {
           proxy_pass https://protos.foo;      # sin URI -> la ruta pasa igual (/xyz/... -> /xyz/...)
           proxy_ssl_server_name on;           # SNI hacia el backend HTTPS
       }
   }
   server {
       listen 80;
       server_name hola;
       root /var/www/hola;
       index index.html;
       location / { try_files $uri $uri/ =404; }
   }
   server {
       listen 80 default_server;
       server_name _;
       return 200 "what?\n";
   }
   ```

3. `sudo nginx -t && sudo systemctl reload nginx`, después `curl puerro/xyz/`.

**Por qué hace falta `proxy_ssl_server_name on`**: con `proxy_pass https://...`, nginx es un
**cliente TLS**. Por defecto **no manda SNI**, y los servidores con varios sitios por IP
(CDNs, virtual hosts HTTPS) cortan el handshake. Probado contra https://example.com: sin la
línea, **502** y en el error.log `SSL_do_handshake() failed ... handshake failure`. Con la
línea, **200**.

**`Host`**: el default de nginx (`$proxy_host` = protos.foo) ya es el correcto, así que el
`proxy_set_header Host protos.foo;` del repo sobra.

## Ej 4: mail a la casilla del ITBA que se vea "de aliceandbob@gmail.com" y "para: A quien le interese", con subject, una imagen adjunta y "¡Hola Mundo!" en HTML y texto plano, ambos en base64

1. **¿A qué servidor?** `dig MX itba.edu.ar +short`: el de menor preferencia. Desde casa el
   puerto 25 puede estar bloqueado, así que hay que hacerlo desde la red del ITBA o desde
   pampero.
2. **Truco del repo**: mandate el mail desde Gmail con la imagen, abrí "Mostrar original" y
   copiá la estructura MIME (boundaries, headers de la imagen ya en base64). Después cambiá
   lo que pide la consigna.
3. **Estructura**:

   ```
   MAIL FROM:<tu@itba.edu.ar>
   RCPT TO:<tu@itba.edu.ar>                      <- el SOBRE decide la entrega
   DATA
   From: Alicia <aliceandbob@gmail.com>          <- header: lo que se VE (spoofing)
   To: A quien le interese <nadie@example.org>
   Subject: Prueba
   Date: ...
   Message-ID: <...>
   MIME-Version: 1.0
   Content-Type: multipart/mixed; boundary="EXT"

   --EXT
   Content-Type: multipart/alternative; boundary="ALT"

   --ALT
   Content-Type: text/plain; charset=UTF-8
   Content-Transfer-Encoding: base64

   wqFIb2xhIE11bmRvIQ==
   --ALT
   Content-Type: text/html; charset=UTF-8
   Content-Transfer-Encoding: base64

   PHA+wqFIb2xhIE11bmRvITwvcD4=
   --ALT--
   --EXT
   Content-Type: image/png; name="foto.png"
   Content-Disposition: attachment; filename="foto.png"
   Content-Transfer-Encoding: base64

   <base64 -w 76 foto.png>
   --EXT--
   .
   ```

```bash
printf '%s' '¡Hola Mundo!'        | base64    # wqFIb2xhIE11bmRvIQ==   (la ¡ es U+00A1 = C2 A1)
printf '%s' '<p>¡Hola Mundo!</p>' | base64    # PHA+wqFIb2xhIE11bmRvITwvcD4=
base64 -w 76 foto.png                         # líneas de 76 caracteres, como pide MIME
```

**Ojo**: Gmail va a marcar la falta de autenticación (SPF/DMARC de gmail.com) y puede mostrar
"vía ..." o mandarlo a spam. Eso es justamente lo que el ejercicio quiere que veas.

## Ej 5: "hola, yo!" con `curl 127.0.0.1` y "vos no sos yo" con `curl <IPv4 de la máquina>`

La diferencia **no** está en el header Host, sino en la **IP destino** de la conexión. Se
resuelve con `listen IP:puerto`
(`~/Protos/ejercicios/extra/ej5-nginx-yo`):

```nginx
server { listen 127.0.0.1:80;  location / { return 200 "hola, yo!\n"; } }
server { listen 10.0.2.15:80;  location / { return 200 "vos no sos yo\n"; } }
```

**Cómo elige nginx** (apunte 03): primero la **dirección** (la más específica gana: `IP:80`
le gana a `*:80`), y **después**, entre los server de esa dirección, el `server_name`.

**Probado**, y con un efecto colateral que el repo no menciona: mientras estuvo activo,
`http://foo/` y `curl -H 'Host: bar' http://10.0.2.15/` también respondieron "hola, yo!" /
"vos no sos yo", porque esos bloques ahora son los únicos candidatos para esas IPs. Si en el
parcial te piden mantener otros sitios funcionando, a esos sitios también hay que ponerles
`listen 127.0.0.1:80` con su `server_name`.

## Ej 6: con un servidor SSH local, hacer un túnel "local" hacia pampero usando sólo `-R`

**Objetivo**: lograr el mismo efecto que `ssh -L 9090:destino:7777 user@pampero` (en **mi**
máquina el puerto 9090 lleva a `destino:7777` visto desde pampero), pero sin `-L`.

**Idea**: `-R` abre el puerto en **el server SSH** y el destino lo alcanza **el cliente**. Si
la conexión SSH la inicia **pampero hacia mi máquina**, el server es mi máquina:

```bash
# en pampero (cliente SSH), conectándose al sshd de MI máquina:
ssh -R 9090:localhost:7777 yo@<IP de mi máquina>
# -> en MI máquina se abre el 9090, que lleva al localhost:7777 DE PAMPERO
```

**Desde casa** (mi máquina está detrás de NAT y pampero no puede conectarse a ella) primero
hay que exponer mi sshd en pampero con otro `-R`:

```bash
ssh -R 2222:localhost:22 yo@pampero.itba.edu.ar            # desde mi máquina
ssh -p 2222 -R 9090:localhost:7777 yo@localhost            # ya en pampero (localhost:2222 = mi sshd)
nc localhost 9090                                          # en mi máquina -> lo que sirve pampero en 7777
```

## Ej 7: ¿por qué no funciona `ssh localhost -L1234:127.0.0.1:1234`?

`-L1234:127.0.0.1:1234` significa "escuchá en mi 1234, y el **server** (localhost) que se
conecte a su 127.0.0.1:1234". Pero el server es la misma máquina, así que su 127.0.0.1:1234
es **el propio puerto que abrió el túnel**. Cada conexión entra al túnel, sale y vuelve a
entrar: es un **loop**.

**Probado**: al conectar con `nc localhost 1234`, ssh fue abriendo canales en cadena hasta
agotar el límite y terminó con `channel 1014: open failed: connect failed: open failed` (ese
1014 dice cuántos canales abrió). nc no recibió nada.

## Ej 8: provocar "too many redirects" con `ncat -l`

```bash
ncat -l 1234 -k -c 'printf "HTTP/1.1 302 Found\r\nLocation: http://localhost:1234\r\nContent-Length: 0\r\n\r\n"'
curl -L http://localhost:1234          # curl: (47) Maximum (50) redirects followed
#   en el navegador: ERR_TOO_MANY_REDIRECTS / "La página no está redirigiendo correctamente"
```

**Probado.** Cada respuesta redirige a la misma URL. `-k` mantiene vivo el server entre
pedidos y `-c` le ejecuta el `printf` a cada conexión. **El `\r\n` es obligatorio**: HTTP
exige CRLF.

## Ej 9: `curl pawserver.it.itba.edu.ar -x socks5://pampero.itba.edu.ar:1080` falla desde casa pero anda desde el ITBA. ¿Por qué?

- Con **`socks5://`**, el nombre lo resuelve **mi máquina**. Desde casa, el DNS público da la
  IP **pública** de pawserver (o directamente no la conoce: *split-horizon*). Después el
  proxy, que está **adentro** de la red del ITBA, intenta conectarse a esa IP pública desde
  adentro, y eso el firewall o NAT del ITBA no lo deja ("hairpin"). Desde el ITBA, el DNS
  interno da la IP **privada**, a la que pampero llega sin problema.
- **Solución**: `socks5h://`, que le manda el **nombre** al proxy y lo resuelve **pampero**
  con el DNS interno. Es lo mismo que pedían los parciales 2024 Ej II y 2026 Ej 3.

## Ej 10: zona carlitos.com.ar

**Requisitos**: autoridad de la zona; responsable `carloselmascapo@carlitos.com.ar`; A
1.2.3.4 con TTL de 2 h; `mysite` CNAME a example.org por 1 semana; MX mail20, mail30 y mail40
con preferencias 20, 30 y 40 y TTL de 1 día. Mostrarlo con dig.

El archivo es `~/Protos/ejercicios/extra/ej10-db.carlitos.com.ar` (pasa `named-checkzone`
con OK). Lo clave:

```
@ IN SOA ns.carlitos.com.ar. carloselmascapo.carlitos.com.ar. ( ... )   ; "@" -> "."
@        IN NS ns
ns       IN A  1.2.3.4
@    2h  IN A  1.2.3.4
mysite 1w IN CNAME example.org.          ; SIN el punto final quedaría example.org.carlitos.com.ar. (probado)
@    1d  IN MX 20 mail20
@    1d  IN MX 30 mail30
@    1d  IN MX 40 mail40
mail20   IN A  1.2.3.20                  ; <- el repo no los tiene: el MX necesita que el nombre tenga A
mail30   IN A  1.2.3.30
mail40   IN A  1.2.3.40
```

```bash
dig @localhost carlitos.com.ar SOA
dig @localhost carlitos.com.ar A          # TTL 7200
dig @localhost mysite.carlitos.com.ar     # CNAME example.org. (TTL 604800) + el A de example.org
dig @localhost carlitos.com.ar MX         # 20/30/40 (TTL 86400)
```

## Ej 11: cadena de CNAME de foo.leak.com.ar

```bash
dig foo.leak.com.ar            # ANSWER: foo.leak.com.ar CNAME x ; x CNAME y ; y A ...
dig +short foo.leak.com.ar     # muestra cada eslabón y al final las IPs
dig +trace foo.leak.com.ar     # quién es autoritativo en cada paso
whois <IP final>               # de quién es la IP (CDN, nube...)
```

**¿Por qué CNAME y no A directo?** El sitio está en un proveedor (CDN, GitHub Pages, AWS, un
balanceador). El proveedor maneja **sus** IPs: las cambia, balancea y responde distinto
según dónde está el cliente (GeoDNS o anycast). Con un CNAME a su nombre canónico, el dueño
del dominio no tiene que tocar nada cuando el proveedor cambia algo. Con un A fijo, habría
que actualizarlo a mano y se perdería el balanceo.

(Desde fuera del laboratorio el nombre puede dar NXDOMAIN, porque es de la red del ITBA.)

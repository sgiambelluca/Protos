# Guía 2: direccionamiento y HTTP

Teoría (URI, métodos, códigos, headers, caching): `../../apuntes/02-uri-http.md`
nginx (sintaxis, server_name, location, proxy, errores): `../../apuntes/03-nginx.md`

## Archivos configurados

| Archivo | Ejercicio | Qué hace |
|---|---|---|
| `/etc/nginx/sites-available/foo` | E36, E40, E41 | `foo` estático ("Bienvenido a Foo") con gzip, en HTTP y HTTPS |
| `/etc/nginx/sites-available/foo-proxy` | E39 | `foo` como proxy reverso a Python `127.0.0.1:8080` (alternativo) |
| `/etc/nginx/sites-available/bar` | E36, E40 | `bar` ("Bienvenido a Bar") con gzip |
| `/etc/nginx/sites-available/what` | E36 | `default_server`: cualquier otro Host o la IP → "What?" |
| `/etc/nginx/snippets/protos-gzip.conf` | E40 | Directivas gzip, incluidas desde foo y bar |
| `/etc/nginx/ssl/foo.pem`, `foo-key.pem` | E41 | Certificado (público) y clave (privada) generados con `mkcert foo` |
| `/var/www/{foo,bar,what}/index.html` | E36 | Contenido. `grande.html` (27 KB) sirve para ver gzip |
| `/etc/systemd/system/protos-python-http.service` | E39 | `python3 -m http.server 8080` como servicio |
| `/etc/hosts` (bloque PROTOS-E37) | E37 | `127.0.0.1 foo bar` |
| `/etc/nginx/sites-available/gugul` | (clase) | Proxy a Google. Ya estaba, no se tocó |

Las copias "buenas" de todo están en `~/Protos/config/`.

## netcat (E17–E20)

```bash
# E17: chat entre dos terminales
nc -l 9999                 # terminal 1 (servidor)
nc localhost 9999          # terminal 2 (cliente)

# E18: mandar CR LF. -C convierte cada Enter en \r\n. Si no, a mano: Ctrl-V Ctrl-M, o printf
printf 'GET / HTTP/1.1\r\nHost: foo\r\n\r\n' | nc localhost 80
nc -C localhost 80

# E19: hacer de "servidor HTTP" y ver qué manda el browser
nc -l 9090                 # y en Firefox: http://localhost:9090/
#   respuesta inválida: escribir cualquier cosa y Ctrl-D
#   respuesta válida (pegar en nc, con -C para el CRLF):
#   HTTP/1.1 200 OK
#   Content-Type: text/html; charset=utf-8
#   Content-Length: 14
#
#   <h1>Hola!</h1>

# E20: HTTP/1.1 sin Host -> 400 Bad Request (Host es OBLIGATORIO en 1.1)
printf 'GET / HTTP/1.1\r\n\r\n' | nc www.google.com.ar 80 | head -5
printf 'GET / HTTP/1.1\r\nHost: www.google.com.ar\r\nConnection: close\r\n\r\n' | nc www.google.com.ar 80 | head -20
```

## curl y wget (E21, E22, E28, E32)

```bash
curl -i  http://foo/                         # -i: headers de respuesta + cuerpo
curl -I  http://foo/                         # -I: sólo HEAD
curl -v  http://foo/                         # -v: todo el diálogo (> pedido, < respuesta)
curl -H 'Host: bar' http://127.0.0.1/        # cambiar el header Host (E37)
curl --compressed -v http://foo/grande.html  # pide gzip y lo descomprime
curl -d 'a=1&b=2' http://foo/                # POST con application/x-www-form-urlencoded
curl --http1.1 / --http2  https://foo/
curl --socks5 127.0.0.1:1080 http://...      # por un proxy SOCKS5 (ver SSH -D)
curl -X TRACE -i http://www.google.com.ar/   # E28: Google responde 405 (TRACE deshabilitado, ataque XST)

# E22: reanudar descargas -> Range / Content-Range / Accept-Ranges / 206 Partial Content
wget https://proof.ovh.net/files/100Mb.dat                  # archivo grande de prueba; cortar con Ctrl-C
wget --continue <misma URL>                                  # manda "Range: bytes=N-"
curl -r 0-99 -i http://foo/grande.html                       # pedir un rango a mano -> 206

# E32: GET condicional (protos.foo está caído: probar contra nuestro nginx, que manda ETag y Last-Modified)
curl -sI http://foo/grande.html | grep -iE 'etag|last-modified'
curl -I -H 'If-Modified-Since: <fecha de Last-Modified>' http://foo/grande.html    # -> 304 Not Modified
curl -I -H 'If-None-Match: "<etag>"'                    http://foo/grande.html     # -> 304 Not Modified
curl -I -z /var/www/foo/grande.html http://foo/grande.html   # -z arma el If-Modified-Since con la fecha del archivo
```

## nginx: E36 a E41

```bash
# E36/E37: probar sin que la máquina resuelva los nombres -> mandar el Host a mano
curl -H 'Host: foo' http://127.0.0.1/          # Bienvenido a Foo
curl -H 'Host: bar' http://127.0.0.1/          # Bienvenido a Bar
curl http://10.0.2.15/                         # What?  (por IP no matchea ningún server_name)
curl -H 'Host: cualquiera' http://127.0.0.1/   # What?
# Con /etc/hosts (E37) ya anda:  curl http://foo/   y en Firefox  http://bar/

# E39: proxy reverso
~/Protos/scripts/foo-modo.sh proxy             # ahora foo muestra "Hola mundo" (lo sirve Python)
curl -v http://foo/                            # el server sigue siendo nginx. Python ve X-Forwarded-For
sudo systemctl stop protos-python-http         # nginx devuelve 502 Bad Gateway (el backend no está)
sudo systemctl start protos-python-http
~/Protos/scripts/foo-modo.sh estatico          # volver

# E40: gzip
curl -sI -H 'Accept-Encoding: gzip' http://foo/grande.html | grep -iE 'content-encoding|vary'
curl -s  -H 'Accept-Encoding: gzip' http://foo/grande.html | wc -c   # ~1100 bytes
curl -s  http://foo/grande.html | wc -c                              # ~27000 bytes
#  index.html NO se comprime: mide 132 bytes < gzip_min_length 256

# E41: HTTPS
curl -v https://foo/ 2>&1 | grep -E 'subject|issuer|SSL'   # issuer: mkcert development CA
openssl s_client -connect 127.0.0.1:443 -servername foo </dev/null | head -20
```

### "Aviso" de E36: ¿por qué Firefox no abre http://foo/?

`.foo` es un TLD real de Google y está en la **lista de precarga HSTS** de los browsers
(incluye el nombre `foo` y todos sus subdominios). Por eso Firefox y Chrome **fuerzan
https://** y nunca mandan el pedido por http. Con E41 (certificado de mkcert para `foo`)
https://foo funciona y es confiable, porque `mkcert -install` instaló la CA en Firefox.
Firefox hay que reiniciarlo después. Con `bar` no pasa esto.

`curl` no usa la lista HSTS precargada, por eso `curl http://foo/` sí anda.

### E38: F5 vs Ctrl+F5 (Wireshark en la interfaz `lo`, filtro `http`)

- **Navegación normal**: si el recurso está en cache y no venció, ni siquiera hay pedido.
- **F5 (recargar)**: revalida con `If-Modified-Since` / `If-None-Match` y recibe **304**.
- **Ctrl+F5 (forzar)**: manda `Cache-Control: no-cache` y `Pragma: no-cache`, sin
  condicionales, y recibe **200** con el cuerpo completo.

### E30: Authorization Basic

```bash
echo YWxndW51c3VhcmlvOmFsZ3VuYXBhc3N3b3Jk | base64 -d     # algunusuario:algunapassword
```

Es sólo base64, **no** está cifrado. Por eso Basic auth exige HTTPS.

### E35: campus (sólo con las DevTools)

El formulario de login va por POST con `application/x-www-form-urlencoded`. La sesión se
mantiene con la cookie que llega en `Set-Cookie`. Para ver lo mismo con curl hay que mandar
esa cookie: `curl -b 'NOMBRE=VALOR' https://campus.itba.edu.ar/...`. Si no, el servidor no
sabe quién sos y redirige al login.

# 02: URI y HTTP (Guía 2)

## URI (RFC 3986)

```
  https://usuario@www.ej.com:8443/a/b/c.html?x=1&y=2#seccion
  \___/   \_____/ \________/ \__/\_________/ \_____/ \_____/
 scheme  userinfo    host    port   path      query  fragment
          \_____________________/
                 authority
```

- **Fragment** (`#section-14.19`, E12): **no se manda al servidor**. El navegador lo usa
  para ir a una parte del documento (o lo usan las SPA para el ruteo). No aparece en el
  pedido HTTP.
- **URI vs URI reference** (E13): una *URI reference* puede ser **relativa** (`../x`,
  `/img/a.png`, `?q=1`, `#top`) y se resuelve contra una URI base. Una URI es absoluta (tiene
  scheme).
- **Resolución** (E14, §5.4.1). Con base `http://a/b/c/d;p?q`:
  `g` → `http://a/b/c/g`, `./g` → `http://a/b/c/g`, `g/` → `http://a/b/c/g/`,
  `/g` → `http://a/g`, `//g` → `http://g`, `?y` → `http://a/b/c/d;p?y`,
  `#s` → `http://a/b/c/d;p?q#s`, `..` → `http://a/b/`, `../g` → `http://a/b/g`,
  `../..` → `http://a/`, `../../g` → `http://a/g`, `""` → la base.
- **Equivalencia** (E15): el scheme y el host son case-insensitive. El puerto por defecto
  (o `:` vacío) equivale a no ponerlo. En el percent-encoding da igual `%7e` o `%7E`, y `%7E`
  es lo mismo que `~` (un carácter *unreserved*). El ejemplo viene del RFC 2616 §3.2.3, donde
  las tres terminan en `home.html` y **son equivalentes**. En la guía b. y c. terminan en
  `.htm`. Si no es un typo, a. **no** es equivalente a b./c. (el path es case-sensitive y es
  otro archivo), aunque b. y c. sí son equivalentes entre sí.
- **URL vs URN** (E16): una URL dice **dónde** está el recurso (se puede pedir). Una URN es
  un **nombre** persistente (`urn:isbn:...`). En XML, los `xmlns` son identificadores de
  namespace (funcionan como nombres aunque tengan forma http). Los `.xsd` de
  `schemaLocation` sí son URLs que se descargan.
- **Percent-encoding**: un byte se escribe `%HH`. Los *reserved* (`:/?#[]@!$&'()*+,;=`) se
  codifican cuando no cumplen su función. Los *unreserved* (`A-Z a-z 0-9 - . _ ~`) nunca hace
  falta codificarlos.

## Mensaje HTTP/1.1 (RFC 9110/9112)

```
GET /index.html HTTP/1.1\r\n          <- request-line: método SP target SP versión
Host: foo\r\n                         <- headers: "Nombre: valor" (nombre case-insensitive, E23)
User-Agent: curl/8.18\r\n
Accept: */*\r\n
\r\n                                  <- línea vacía: fin de headers
[cuerpo]

HTTP/1.1 200 OK\r\n                   <- status-line: versión SP código SP frase
Content-Type: text/html; charset=utf-8\r\n
Content-Length: 132\r\n
\r\n
<!doctype html>...
```

- **`Host` es obligatorio en HTTP/1.1.** Sin él → **400 Bad Request** (E20). Es lo que
  permite los **virtual hosts** (muchos sitios en una misma IP).
- **¿Cómo sabe el cliente dónde termina el cuerpo?** Por `Content-Length`, por
  `Transfer-Encoding: chunked`, o (sólo en respuestas) cuando se cierra la conexión.

## Métodos (E27)

| Método | Para qué | Safe | Idempotente |
|---|---|---|---|
| GET | obtener una representación | ✔ | ✔ |
| HEAD | igual que GET pero sin cuerpo | ✔ | ✔ |
| OPTIONS | qué métodos se permiten (`Allow:`) / CORS | ✔ | ✔ |
| TRACE | eco del pedido (diagnóstico, para ver proxies) | ✔ | ✔ |
| PUT | crear o reemplazar el recurso **en esa URI** | ✘ | ✔ |
| DELETE | borrar | ✘ | ✔ |
| POST | procesar datos (crear un subrecurso, acciones) | ✘ | ✘ |
| PATCH | modificar parcialmente | ✘ | ✘ (en general) |
| CONNECT | abrir un túnel TCP a través de un proxy (HTTPS por proxy) | ✘ | ✘ |

- **Safe**: no cambia el estado del servidor (lo que se espera del método, no lo que
  efectivamente pasa).
- **Idempotente**: hacerlo N veces deja el **estado** igual que hacerlo 1 vez. DELETE es
  idempotente aunque borre: el segundo DELETE devuelve 404, pero el estado sigue siendo "no
  existe". La idempotencia permite **reintentar** sin miedo.
- **Caso del "acelerador"** (E27c): el plugin hace GET a todos los links, así que `GET
  /items/123/delete` borra todo. **La culpa es del desarrollador**: usó GET (safe) para una
  acción que cambia el estado. Solución: usar POST o DELETE (un formulario) y confirmar.
- **TRACE** (E28): casi todos los servidores lo deshabilitan (**405 Method Not Allowed**)
  por el ataque XST (*Cross-Site Tracing*: robar cookies HttpOnly vía el eco). Si llega un
  `Via:` en el eco, hay un proxy en el medio.

## Códigos de estado (E29)

| | Clase | Los que hay que saber |
|---|---|---|
| 1xx | informativo | 100 Continue, 101 Switching Protocols (WebSocket) |
| 2xx | éxito | **200** OK, **201** Created (+`Location`), **204** No Content, **206** Partial Content |
| 3xx | redirección | **301** Moved Permanently, **302** Found, 303 See Other, **304** Not Modified, **307** Temporary, **308** Permanent (307/308 **no cambian el método**) |
| 4xx | error del cliente | **400** Bad Request, **401** Unauthorized (= no autenticado, va con `WWW-Authenticate`), **403** Forbidden (autenticado pero sin permiso), **404** Not Found, **405** Method Not Allowed (va con `Allow:`), **409** Conflict, **410** Gone, 412 Precondition Failed, **415** Unsupported Media Type, 422 Unprocessable Content, 428 Precondition Required, 429 Too Many Requests |
| 5xx | error del servidor | **500** Internal, **501** Not Implemented, **502** Bad Gateway (el proxy recibió algo inválido del backend, o no pudo conectarse), **503** Service Unavailable (+`Retry-After`), **504** Gateway Timeout |

Respuestas de E29:

| | Situación | Código |
|---|---|---|
| a | se mudó para siempre | **301** (o 308) + `Location` |
| b | anónimo en el backoffice | **403** (o 404 para no revelar que existe) |
| c | no autenticado | **401** + `WWW-Authenticate` |
| d | editado por otro mientras tanto | **409** Conflict, o **412** si se usó `If-Match` con el ETag |
| e | 410 | el recurso se **eliminó a propósito y para siempre** (404 = "no sé / no está") |
| f | falta un parámetro | **400** |
| g | parámetro con formato incorrecto | **400** (o 422) |
| h | formato no soportado | **415** |
| i | sistema externo caído | **503** (o 502/504 si es un gateway) |
| j | DELETE no soportado | **405** + `Allow: GET` |

## Headers importantes

| Header | Va en | Para qué |
|---|---|---|
| `Host` | pedido | virtual host (obligatorio en 1.1) |
| `User-Agent` / `Server` | pedido / respuesta | identificar al cliente / al servidor |
| `Accept`, `Accept-Language`, `Accept-Encoding` | pedido | **negociación de contenido** (proactiva) |
| `Content-Type` | ambos | **media type** del cuerpo (`text/html; charset=utf-8`) |
| `Content-Length` | ambos | largo del cuerpo en bytes |
| `Content-Encoding` | ambos | compresión aplicada (gzip, br, deflate). Es propiedad de la representación |
| `Transfer-Encoding` | ambos | codificación **del transporte, salto a salto** (chunked) |
| `Location` | respuesta | destino de un 3xx o URI de lo creado (201) |
| `Date`, `Last-Modified`, `ETag` | respuesta | fecha, validadores para cache |
| `Cache-Control`, `Expires`, `Vary` | respuesta | política de cache |
| `If-Modified-Since`, `If-None-Match` | pedido | GET condicional → **304** |
| `If-Match`, `If-Unmodified-Since` | pedido | escritura condicional (evitar pisar cambios) → **412** |
| `Range` / `Content-Range` / `Accept-Ranges` | pedido / respuesta | descargas parciales → **206** (wget --continue, E22) |
| `Set-Cookie` / `Cookie` | respuesta / pedido | estado (sesión) sobre un protocolo sin estado (E35) |
| `Authorization` / `WWW-Authenticate` | pedido / respuesta | autenticación |
| `Connection` | ambos | `keep-alive` / `close` (salto a salto) |
| `Strict-Transport-Security` | respuesta | HSTS: "usá sólo HTTPS conmigo" |

### Media types (E25)

Formato `tipo/subtipo[; parámetros]`, registrados en IANA (RFC 2046/6838). `text/html`,
`text/plain`, `text/css`, `text/javascript` (el oficial; antes `application/javascript`),
`image/jpeg`, `image/gif`, `image/png`, `application/pdf`, `application/json`, y
**`application/octet-stream`** para un .exe o "bytes desconocidos".
`Content-Disposition: attachment; filename="x.exe"` (RFC 6266) le dice al navegador que lo
descargue en vez de mostrarlo.

## Conexiones persistentes, pipelining, chunked (E24, E26)

- **HTTP/1.0**: una conexión TCP por pedido. Para reusarla había que mandar
  `Connection: keep-alive`.
- **HTTP/1.1**: las conexiones son **persistentes por defecto**. Requisito: que cada mensaje
  tenga un **largo determinable** (Content-Length o chunked) para saber dónde empieza el
  siguiente. Se cierra con `Connection: close`. Ventajas: se evita el handshake TCP (y TLS)
  en cada pedido, se evita el *slow start* y hay menos sockets en `TIME_WAIT`.
- **Pipelining**: mandar varios pedidos **sin esperar** las respuestas. Las respuestas tienen
  que volver **en el mismo orden**, así que una lenta frena a todas (*head-of-line
  blocking*). En la práctica casi no se usa. **HTTP/2** lo resuelve con **multiplexación**
  (streams en una sola conexión TCP, frames binarios, compresión de headers HPACK). HTTP/3
  va sobre QUIC (UDP).
- **`Transfer-Encoding: chunked`**: el cuerpo se manda en bloques `<largo-hex>\r\n<datos>\r\n`
  y termina con `0\r\n\r\n`. Sirve cuando **no se sabe el largo** al empezar a responder
  (contenido dinámico o streaming). Los otros valores (`gzip`, `deflate`, `compress`) casi
  no se usan como Transfer-Encoding: la compresión va en **Content-Encoding**.

## Cache, validadores y ETag (E31 a E34)

- **Estrategias para ahorrar tráfico** (E31): cache (`Cache-Control: max-age`), GET
  condicional (304 sin cuerpo), compresión (`Content-Encoding`), rangos (206), conexiones
  persistentes, `HEAD`.
- `Cache-Control: max-age=3600, must-revalidate` (E33): se usa sin preguntar durante **1
  hora**. Una vez vencido, **hay que revalidar** con el servidor y, si no se puede, **no se
  usa la copia vieja** (devuelve 504).
- Otros valores: `no-cache` (se puede guardar, pero siempre se revalida), `no-store` (no se
  guarda nunca), `private` (sólo la cache del navegador, no la de proxies/CDN), `public`,
  `s-maxage` (para las caches compartidas).
- **ETag**: identificador opaco de una **versión** de la representación (`"6adf8f87-68c7"`
  en nginx = mtime-tamaño en hex). `W/"..."` = débil (semánticamente equivalente, no idéntica
  byte a byte).
- **GET condicional** (E32):
  `If-None-Match: "etag"` → **304 Not Modified** si no cambió.
  `If-Modified-Since: <fecha>` → 304 si no se modificó después.
- **Shallow vs deep ETag** (E34): la *shallow* se calcula **después** de generar la
  respuesta (un hash del cuerpo). Ahorra ancho de banda pero no CPU, porque el servidor
  igual genera todo. La *deep* sale del modelo de datos (una versión o fecha de la base) y
  permite contestar 304 **sin generar** la página.

## Estado: cookies (E35)

HTTP es **sin estado**. El servidor manda `Set-Cookie: SESSIONID=abc; Path=/; HttpOnly;
Secure; SameSite=Lax` y el navegador devuelve `Cookie: SESSIONID=abc` en cada pedido a ese
sitio. Con curl hay que mandar la cookie a mano (`-b`) o usar un "cookie jar" (`-c` / `-b`).
Los formularios se mandan con `application/x-www-form-urlencoded` (`a=1&b=hola+mundo`) o, si
tienen archivos, con `multipart/form-data`.

## Autenticación Basic (E30)

`Authorization: Basic base64(usuario:password)`. Es **codificación, no cifrado**: cualquiera
que lo capture lo decodifica (`base64 -d`). Sólo es aceptable sobre HTTPS. El servidor la
pide con `401` + `WWW-Authenticate: Basic realm="..."`.

## Reverse proxy / gateway (E39)

Un intermediario que **para el cliente es el servidor de origen** y reenvía hacia adentro.
Sirve para terminar TLS, comprimir, hacer cache, balancear carga, servir los estáticos,
esconder o proteger backends viejos y desplegar sin cortes. Un *forward proxy* es lo
contrario: lo configura el **cliente** para salir (por ejemplo SOCKS o el proxy de una
empresa).

## Herramientas

```bash
nc -C host 80                       # HTTP a mano (-C = CRLF)
curl -v / -i / -I / -H / -d / -X / -L (sigue redirecciones) / -o archivo / -O (nombre remoto)
     --compressed / -r 0-99 / -z archivo / -b cookies / -c jar / --http1.1 --http2 / --socks5[-hostname]
wget URL ; wget -c URL (continuar) ; wget -S (mostrar headers) ; wget -r (recursivo, espejar sitios)
```

**curl vs wget** (E21): curl es para **hablar** con servidores: muchos protocolos, armar
cualquier pedido, APIs, scripts; por defecto escribe a stdout. wget es para **descargar**:
guarda en un archivo, sigue reintentando, continúa descargas cortadas y puede bajar sitios
enteros recursivamente.

---

## En parciales anteriores

Las resoluciones completas, paso a paso, están en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 3 es otro curl por `socks5h` con `Accept`, `Accept-Language` y Basic auth. Se practica en la VM contra un backend que negocia contenido (`simulacro.sh montar`).

**2024 2C, Ej II**: obtener la versión **text/plain en español** de un recurso al que sólo
se llega por un **proxy SOCKS5h**, reutilizando el `Authorization: Basic` de un pedido
capturado.

```bash
echo dXN1YXJpbzpwYXNzd29yZA== | base64 -d          # usuario:password
curl -x socks5h://proxy.sebikul.com:1080 -u usuario:password \
     -H 'Accept: text/plain' -H 'Accept-Language: es' \
     http://ejercicio2.sebikul.com:8080/foo/
```

**2026 1C, Ej 3**: un **POST con JSON** por proxy SOCKS, con headers propios y Basic auth.

```bash
curl -x socks5h://proxy.protos.foo:1080 -u admin:admin \
     -H 'X-legajo: 65522' -H 'Accept-Language: es' -H 'Content-Type: application/json' \
     -d '{"fix": "yes"}' http://ejercicio3.protos.foo:3126/debugger
```

Lo que toman de este tema:

- **Negociación de contenido**: `Accept` (el media type) y `Accept-Language`. Fijate en los
  `q=` del pedido de ejemplo: ahí se ve qué idioma prefería el cliente original.
- **`-u user:pass` = `Authorization: Basic base64(user:pass)`**. Para decodificar:
  `base64 -d`.
- **`socks5h://` vs `socks5://`**: con la **h**, el DNS lo resuelve **el proxy**. Si la
  consigna lo escribe con h, usalo con h.
- **`-d`** ya implica POST y pone `Content-Type: application/x-www-form-urlencoded`. Para
  JSON hay que cambiarlo con `-H`.

Para practicar en la VM: `ssh -fN -D 1080 localhost`, que levanta un proxy SOCKS5 local.

---

## Más práctica (material del repo Protos-ITBA)

Resueltos en `15-ejercicios-extra.md`:

- **Ej 1, conseguir un 304**: `curl -sI URL` para leer `Last-Modified`/`ETag`, y después
  `curl -I -H 'If-Modified-Since: <fecha>' URL` → `304`. Probado contra example.org.
- **Ej 8, "too many redirects"**: un ncat que siempre responde
  `302 Location: <la misma URL>` hace que `curl -L` termine con
  `(47) Maximum (50) redirects followed`.
- **Ej 9, `socks5` vs `socks5h`**: con `h` resuelve el **proxy** (DNS interno, sin problemas
  de split-horizon).

**CRLF a mano en la terminal**: `Ctrl+V` y después `Enter` escribe un `^M` (`\r`). Con otro
`Enter` sale el `\n`. Es una alternativa a `nc -C`.

---

## Del integrador (CTF Protolab, `~/Protos/recu/`)

El integrador es un CTF sobre `http://192.168.123.200`: cada pregunta se lee con un GET y se
responde con un POST de JSON. La resolución completa está en `recu/ctf-protolab-resumen.md`
(y en `recu/ctf-protolab-resumen.html`, con las respuestas ocultas para practicar).

- **Headers propios**: el server no contesta nada sin `Tiki: Taka`, así que va
  `-H "Tiki: Taka"` en cada pedido. Un header que inventa la aplicación viaja igual que
  cualquier otro.
- **POST + JSON**: `curl -X POST URL -H "Content-Type: application/json" -d '{"rta": "..."}'`.
  `-d` ya hace POST (el `-X POST` sobra), pero el `Content-Type` sí hace falta: sin él, curl
  manda `application/x-www-form-urlencoded`.
- **Negociación de contenido**: `/turulu` viene en inglés, con `Content-Language: en`. Con
  `-H "Accept-Language: es"` el server elige la variante en español y responde
  `Content-Language: es`. No se traduce nada: se **pide** otra representación. En la VM se ve
  con el backend del simulacro (`~/Protos/scripts/simulacro.sh montar`):
  `curl -i -x socks5h://proxy.protos.foo:1080 -u admin:secret123 -H 'Accept-Language: es' http://recurso.protos.foo:8080/data/`.
- **Tokens sin estado**: un server que no guarda los tokens que emitió los valida porque
  vienen **firmados** (HMAC): recalcula la firma del contenido con su clave secreta y la
  compara. Un token inventado no tiene una firma válida. El del CTF era sólo base64
  (`paco=paco;rta=string_equals`): base64 **no** cifra ni firma nada.
- **`Server: SimpleHTTP/0.6 Python/...`** = `python3 -m http.server`. Si la carpeta no tiene
  `index.html`, muestra el **listado del directorio** (así se encontraba la clave del vault).
  Probado en la VM: con dos archivos sueltos devuelve `Directory listing for /` y un link a
  cada uno.

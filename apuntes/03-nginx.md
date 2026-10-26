# 03: nginx (Guía 2 E36 a E41, Guía 3 E47 y E48)

## Componentes

- **Proceso master** (corre como root): lee la config, abre los puertos (<1024 necesita
  root) y crea y controla los workers.
- **Workers** (corren como `www-data`): atienden las conexiones con un modelo **event-driven
  no bloqueante** (epoll). Pocos procesos atienden miles de conexiones (problema C10K).
  `worker_processes auto;` = uno por CPU.
- **`reload`** (`systemctl reload nginx` = `nginx -s reload` = señal HUP): el master relee la
  config y, **si es válida**, levanta workers nuevos. Los viejos terminan las conexiones que
  tienen y mueren (*graceful*). **No corta a nadie.** Si la config es inválida, sigue con la
  anterior. Ojo: durante un instante todavía responden los workers viejos, así que un curl
  inmediato puede mostrar la versión anterior.
- **`restart`**: mata todo y arranca de nuevo. Corta conexiones, y si la config está mal
  **queda caído**.

## Archivos (Debian/Ubuntu)

```
/etc/nginx/nginx.conf             principal: user, workers, bloque http{} (incluye lo de abajo)
/etc/nginx/conf.d/*.conf          incluido dentro de http{}
/etc/nginx/sites-available/       un archivo por sitio (no se cargan solos)
/etc/nginx/sites-enabled/         SYMLINKS a sites-available: lo que se carga
/etc/nginx/snippets/              fragmentos para "include"
/etc/nginx/mime.types             extensión -> Content-Type
/var/log/nginx/access.log         un pedido por línea
/var/log/nginx/error.log          errores (502, permisos, upstream caído...)
/var/www/                         contenidos
```

```bash
sudo ln -s /etc/nginx/sites-available/foo /etc/nginx/sites-enabled/foo   # habilitar
sudo rm /etc/nginx/sites-enabled/foo                                     # deshabilitar
sudo nginx -t            # SIEMPRE antes de recargar: chequea la sintaxis
sudo nginx -T            # muestra la config COMPLETA, con todos los include resueltos
sudo systemctl reload nginx
```

## Sintaxis

```nginx
directiva valor;                      # TODA directiva simple termina en ;
bloque { ... }                        # contextos: main > http > server > location
include snippets/x.conf;              # rutas relativas a /etc/nginx
# comentario
```

### server: virtual host

```nginx
server {
    listen 80;                       # IPv4. "listen [::]:80;" = IPv6
    listen 80 default_server;        # el que atiende si ningún server_name coincide
    listen 443 ssl;                  # TLS en este puerto
    server_name foo www.foo *.foo;   # nombres (comodines y ~regex permitidos). "_" = ninguno
    root  /var/www/foo;              # archivo = root + URI
    index index.html;                # qué archivo servir cuando se pide un directorio
}
```

**Cómo elige el server** (E36):

1. Primero por **IP:puerto** (`listen`).
2. Entre los server que escuchan ahí, compara el header **`Host`** con `server_name`: nombre
   exacto, después comodín al principio (`*.foo`), después comodín al final, después regex.
3. Si nada coincide, usa el **`default_server`** de ese puerto. Si no hay ninguno marcado,
   usa **el primero** que aparece en la config.

Por eso entrar por IP muestra "What?": el Host es `10.0.2.15` y no coincide con nada.

### location

```nginx
location = /exacto { }      # 1° coincidencia exacta (gana y corta la búsqueda)
location ^~ /static/ { }    # 2° prefijo "preferente": si es el prefijo más largo, no mira las regex
location ~  \.php$ { }      # 3° regex, sensible a mayúsculas (la PRIMERA en orden de aparición)
location ~* \.(jpg|png)$ {} #    regex insensible a mayúsculas
location /  { }             # 4° prefijo común: se usa el MÁS LARGO que coincide
```

**Error común**: usar `location = /` cuando se quería `location /`. Con `=` sólo coincide la
URI `/` exacta, así que `/otra.html` cae en otra location o da 404.

### root vs alias, try_files

```nginx
location /img/ { root  /data; }     # /img/a.png -> /data/img/a.png   (root + URI completa)
location /img/ { alias /data/; }    # /img/a.png -> /data/a.png       (reemplaza el prefijo)
try_files $uri $uri/ =404;          # probar el archivo, después el directorio, si no 404
```

### Proxy reverso (E39, E47)

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;                         # backend
    proxy_set_header Host $host;                              # por defecto manda Host = $proxy_host (el del upstream)
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

- **La barra final de `proxy_pass` importa**:
  - `location /app/ { proxy_pass http://b:8080; }`: **sin URI**, pasa la URI tal cual
    (`/app/x` → `http://b:8080/app/x`).
  - `location /app/ { proxy_pass http://b:8080/; }`: **con URI** (`/`), reemplaza el prefijo
    de la location (`/app/x` → `http://b:8080/x`).
- **Header `Host` hacia el backend**: por defecto va el nombre del upstream (`$proxy_host`).
  Cuando el backend es **otro sitio con nombre** (protos.foo, google.com), hay que dejarlo
  así. Cuando el backend es **tuyo** y le importa el nombre original, se pone `Host $host`.
- **Upstream con nombre y DNS**: `proxy_pass http://protos.foo/;` se resuelve **una vez, al
  arrancar**. Si en ese momento no hay DNS, `nginx -t` falla con `host not found in
  upstream` y **nginx no levanta ningún sitio**. Solución: `resolver 127.0.0.53;` +
  `set $u protos.foo;` + `proxy_pass http://$u;`, que resuelve en cada pedido (así está
  `foo.pdc.lab`).
- **502 Bad Gateway** = nginx no pudo hablar con el backend (está caído, puerto equivocado,
  connection refused). Mirar `error.log`. **504** = el backend no contestó a tiempo.
- **Proxy a HTTPS** (`proxy_pass https://www.google.com;`, como "gugul"): nginx hace de
  cliente TLS. Con `proxy_ssl_server_name on;` manda SNI.

### Redirecciones (E48)

```nginx
return 301 https://$host$request_uri;      # típico: forzar HTTPS
return 302 http://protos.foo$request_uri;  # temporal
rewrite ^/viejo/(.*)$ /nuevo/$1 permanent; # con regex (permanent=301, redirect=302)
```

### gzip (E40)

```nginx
gzip on;  gzip_vary on;  gzip_proxied any;  gzip_comp_level 5;
gzip_min_length 256;
gzip_types text/plain text/css application/json application/javascript application/xml image/svg+xml;
```

- **Cómo funciona**: sólo comprime si el cliente manda `Accept-Encoding: gzip`. Responde con
  `Content-Encoding: gzip` y, con `gzip_vary`, `Vary: Accept-Encoding`. Con gzip **no hay
  Content-Length**: nginx manda **chunked** porque comprime al vuelo.
- **Ventajas**: el texto pesa entre un 70 % y un 95 % menos (`grande.html` pasa de 27 KB a 1,1
  KB). Carga más rápido sobre todo en enlaces lentos, y el backend se ahorra la compresión
  (la hace nginx).
- **Costo**: CPU en el servidor y en el cliente. No tiene sentido para cosas ya comprimidas
  (jpg, png, mp4, zip) ni para respuestas muy chicas.
- **Errores comunes**: `text/html` siempre se comprime y no hay que ponerlo en
  `gzip_types` (si se pone, nginx avisa "duplicate MIME type"). Y si el archivo es más chico
  que `gzip_min_length`, no se comprime: no es que gzip no ande.

### SSL/TLS (E41)

```nginx
server {
    listen 443 ssl;
    server_name foo;
    ssl_certificate     /etc/nginx/ssl/foo.pem;      # certificado (+ cadena): PÚBLICO
    ssl_certificate_key /etc/nginx/ssl/foo-key.pem;  # clave privada: permisos 600, nunca se comparte
    # opcional: ssl_protocols TLSv1.2 TLSv1.3;   http2 on;
}
```

Ver `11-tls-y-certificados.md`. No dejar los certificados en `/tmp` como dice la guía: se
borran al reiniciar.

## Variables útiles

`$host` (Host del pedido, o server_name), `$request_uri` (URI original con query),
`$uri` (URI normalizada, sin query), `$args`, `$remote_addr`, `$scheme`, `$server_name`,
`$proxy_host`, `$proxy_add_x_forwarded_for`.

## Errores comunes y qué significan

| Síntoma / mensaje | Causa |
|---|---|
| `nginx: [emerg] unexpected "}"` o `... in /etc/nginx/sites-enabled/x:12` | falta un `;` en la línea anterior |
| `a duplicate default server for 0.0.0.0:80` | dos `default_server` en el mismo puerto (el `default` de Debian y el tuyo) |
| `conflicting server name "foo" on 0.0.0.0:80, ignored` | dos server con el mismo server_name: sólo se usa el primero |
| `host not found in upstream "x"` | el proxy_pass tiene un nombre que no resuelve al arrancar |
| `bind() to 0.0.0.0:80 failed (98: Address already in use)` | ya hay otro proceso en el puerto (apache, otro nginx) → `sudo ss -tlnp` |
| 403 Forbidden | no hay index y no está `autoindex on`, o www-data no tiene permiso de lectura o de entrar al directorio |
| 404 en todo menos `/` | se usó `location = /` |
| 502 Bad Gateway | el backend está caído o el puerto es otro (mirar `error.log`) |
| el sitio nuevo "no aparece" | falta el symlink en sites-enabled, no se recargó, o el navegador tiene cache o HSTS |
| http://foo en el navegador va a https | HSTS precargado del TLD `.foo` |
| cambié la config y curl muestra lo viejo | el reload es graceful: esperá un segundo |

---

## En parciales anteriores (sale SIEMPRE)

Las resoluciones completas, paso a paso, están en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 2 es otra vez `https://seguro.protos.foo` como proxy, ahora a `interno.protos.foo`. `simulacro.sh` levanta el backend y verifica tu solución.

| Parcial | Pedido | Lo central |
|---|---|---|
| 2024 2C Ej I | `http://foo.example.org/` sirve `http://protos.sebikul.com/` "sin cambiar la URL" y conservando `X-Parcial-Protos` | `proxy_pass` (no redirect). **No pisar el `Host`**. nginx ya pasa los headers en los dos sentidos |
| 2025 2C Ej IV | `https://seguro.protos.foo` sirve `http://parcial.protos.foo`, y `curl` tiene que andar sin `-k` | `listen 443 ssl` + certificado + **trust store** (`update-ca-certificates`) + `proxy_pass` |
| 2026 1C Ej 2 | `http://metadata.local` → `http://metadata.protos.foo` agregando `Metadata: true` y `Accept: application/json` | `proxy_set_header` para **agregar o reemplazar** headers hacia el backend |

Plantilla que resuelve los tres:

```nginx
server {
    listen 80;                                   # o: listen 443 ssl; + ssl_certificate / ssl_certificate_key
    server_name NOMBRE.QUE.ESCRIBE.EL.USUARIO;   # y ese nombre en /etc/hosts -> 127.0.0.1
    location / {
        proxy_pass http://BACKEND.DEL.ENUNCIADO;     # sin "/" final: cualquier ruta pasa igual
        # proxy_set_header Header valor;             # sólo si piden AGREGAR o CAMBIAR algo
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/X /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl -v http://NOMBRE/          # tal cual pide la consigna, sin opciones extra
```

Cosas que se probaron en la VM (26/10/2026):

- **Pasan sin configurar nada** los headers que manda el cliente (por ejemplo
  `X-Parcial-Protos: x`) y los headers de la respuesta del backend. Excepciones: nginx
  pone su propio `Server` y `Date`, y descarta los headers con `_` en el nombre.
- **`proxy_set_header Accept application/json;` REEMPLAZA** el `Accept` del cliente.
- **Si el upstream no resuelve al arrancar, `nginx -t` falla** ("host not found in
  upstream"). En el parcial, chequeá antes con `getent hosts BACKEND`. Si no resuelve, poné
  la IP que te den en `/etc/hosts`.

Archivos listos para adaptar: `~/Protos/ejercicios/parciales/*nginx*`.

---

## Más práctica (material del repo Protos-ITBA)

Resueltos en `15-ejercicios-extra.md`:

- **Backend HTTPS: `proxy_ssl_server_name on;`** (Ej 3). Con `proxy_pass https://...`, nginx
  hace TLS hacia el backend **sin SNI** por defecto, y los servidores con varios sitios
  cortan el handshake. Probado: sin la línea, **502** (`SSL_do_handshake() failed ...
  handshake failure`). Con la línea, **200**.
- **No resolver el upstream a 127.0.0.1** en `/etc/hosts`: nginx se haría proxy a sí mismo.
  Sólo los nombres **del lado del cliente** (puerro, hola, foo...) apuntan a 127.0.0.1.
- **`listen IP:puerto`** (Ej 5) distingue por la **IP destino** de la conexión, no por el
  Host. Gana la dirección más específica (`127.0.0.1:80` le gana a `*:80`), y recién después
  se mira el `server_name`. Efecto colateral probado: con `listen 127.0.0.1:80` activo,
  `http://foo/` deja de llegar a su sitio.
- **`return 200 "texto\n";`** sirve para una respuesta fija sin crear archivos (el "what?" o
  el "hola, yo!"). Con `default_type text/plain;` sale con el Content-Type correcto.

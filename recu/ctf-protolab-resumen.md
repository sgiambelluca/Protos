# PROTOLAB CTF — resumen para practicar

Challenge de 5 preguntas sobre `http://192.168.123.200` (expuesto por el router de
servicenet) que termina conectándose al servidor SSH **The Vault**.

- Entrada al lab: `ssh -o IPQoS=none -p 2222 user_5@192.168.0.238` (contenedor del lab).
- Mecánica de respuestas: por cada pregunta, `POST <recurso>/response` con header
  `Tiki: Taka`, `Content-Type: application/json` y body `{"rta": "<respuesta>"}`.

```bash
curl -i -X POST http://192.168.123.200/<recurso>/response \
  -H "Tiki: Taka" -H "Content-Type: application/json" \
  -d '{"rta": "<respuesta>"}'
```

---

## P0 — Handshake inicial (`/start`)

`GET /start` con header `Tiki: Taka` da la bienvenida y explica la mecánica del
`/response`. Confirmación con `POST /start/response` y `{"rta":"entendido"}`.

**Concepto:** headers custom de request y el patrón POST + JSON (`Content-Type:
application/json`). `curl -d` ya implica POST; `-X POST` es redundante.

---

## P1 — Routing: gateway de pampero hacia 1.1.1.1 (`/juialepan`)

**Pregunta:** ¿cuál es el gateway de `pampero` para llegar a `1.1.1.1`?

La respuesta depende de la tabla de ruteo **de pampero**, no de la máquina propia.
Entrando a pampero:

```bash
ssh -o IPQoS=none usuario@pampero.itba.edu.ar
ip route get 1.1.1.1
# 1.1.1.1 via 10.16.1.254 dev enp1s0 src 10.16.1.100
```

**Respuesta:** `10.16.1.254` (el `via` = next-hop).

**Conceptos:**
- `ip route get <ip>` resuelve qué ruta usaría el kernel para ese destino: devuelve
  `via` (gateway/next-hop), `dev` (interfaz) y `src` (IP origen elegida).
- Si no hay ruta más específica, matchea la default `0.0.0.0/0` y su `via` es la
  respuesta.

---

## P2 — DNS: SERIAL del SOA (`/ketylanuchi`)

**Pregunta:** el router que expone el HTTP también expone un DNS. ¿SERIAL de
`www.google.com` según ese DNS?

```bash
dig @192.168.123.200 www.google.com SOA
# www.google.com.  CNAME  google.com.
# google.com.  IN SOA  ns.google.com. admin.google.com. 74757169 69 420 666 69
```

**Respuesta:** `74757169`.

**Conceptos:**
- El registro **SOA** vive en el **ápex** (raíz) de la zona, no en cada nombre. Como
  `www.google.com` es un **CNAME** a `google.com`, el SOA aparece bajo `google.com.`.
- Los 5 números del SOA, en orden: **SERIAL**, REFRESH, RETRY, EXPIRE, MINIMUM.
  - SERIAL = versión de la zona; el admin lo incrementa en cada cambio. Los esclavos
    lo comparan con el suyo y, si el del master es mayor, transfieren la zona.
- Flag `aa` = *authoritative answer* (es dueño de la zona, no cacheado).
  `recursion requested but not available` = DNS autoritativo puro.

---

## P3 — HTTP content negotiation (`/urururuluru`, recurso `/turulu`)

**Pregunta:** ¿contenido EN ESPAÑOL del recurso `/turulu`?

El `GET /turulu` devuelve `Content-Language: en` y la pista `X-Sugerencia` →
header **`Accept-Language`**. No hay que traducir: hay que *pedir* la variante.

```bash
curl -i http://192.168.123.200/turulu -H "Accept-Language: es"
# Content-Language: es
# Hoy aprendimos a negociar contenido sobre HTTP
```

**Respuesta:** `Hoy aprendimos a negociar contenido sobre HTTP`.

**Concepto:** **negociación de contenido** (RFC 9110 §12). El cliente manda
`Accept-Language` (o `Accept`, `Accept-Encoding`...) y el servidor elige la
representación; responde `Content-Language` indicando cuál mandó.

---

## P4 — Mail: token por casilla temporal (`/papopepoparapapapapiparapopepo`)

**Pregunta:** pedir un mail secreto a `POST /maketoken?email=...`. El token del mail
es la respuesta. El endpoint hace envío SMTP **real** ("no a cualquier dirección" =
debe ser un buzón que exista de verdad).

Casilla temporal vía API de **mail.tm** (desde una máquina con internet):

```bash
# dominio disponible
DOM=$(curl -s https://api.mail.tm/domains | python3 -c 'import sys,json;print(json.load(sys.stdin)["hydra:member"][0]["domain"])')
ADDR="algo@$DOM"; PASS="Passw0rd!"
# crear cuenta
curl -s -X POST https://api.mail.tm/accounts -H 'Content-Type: application/json' \
  -d "{\"address\":\"$ADDR\",\"password\":\"$PASS\"}"
# token JWT de mail.tm
TOK=$(curl -s -X POST https://api.mail.tm/token -H 'Content-Type: application/json' \
  -d "{\"address\":\"$ADDR\",\"password\":\"$PASS\"}" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')

# disparar el mail (desde el contenedor del lab, que llega a .200)
curl -X POST "http://192.168.123.200/maketoken?email=$ADDR" -H "Tiki: Taka"

# leer el buzón
curl -s https://api.mail.tm/messages -H "Authorization: Bearer $TOK"
curl -s https://api.mail.tm/messages/<ID> -H "Authorization: Bearer $TOK"
```

**Respuesta (el token):** `cGFjbz1wYWNvO3J0YT1zdHJpbmdfZXF1YWxz`

Que es **base64** de `paco=paco;rta=string_equals`:

```bash
echo 'cGFjbz1wYWNvO3J0YT1zdHJpbmdfZXF1YWxz' | base64 -d
```

**Conceptos:**
- El cuerpo HTML del mail traía pistas ocultas en **texto blanco sobre fondo blanco**
  (se ven seleccionando el texto o mirando el source):
  - La clave SSH del vault está en un **servidor HTTP** del vault, en un **puerto
    entre 49000 y 50000**.
- Si el mail no llega, el endpoint ofrecía `/maketoken/damearchivoplis?email=...`.

---

## P5 — Validación de token sin estado (`/dalequevamooo`)

**Pregunta:** si el servidor no tiene estado (no recuerda qué tokens emitió), ¿cómo
sabe que el token no fue inventado? La respuesta está en el token mismo.

El token decodificado era `paco=paco;rta=string_equals` → el campo `rta`.

**Respuesta:** `string_equals`.

**Concepto:** un servidor **stateless** valida un token sin guardarlo porque el token
viene **firmado** (HMAC / firma): recalcula la firma sobre el payload con su clave
secreta y la compara (comparación de strings, idealmente *constant-time*). Un token
forjado no tendría firma válida. (El challenge además dejó la respuesta literal
dentro del token como chiste.)

> Bonus: `string_equals` resultó ser también la **passphrase de la clave SSH** del vault.

---

## Objetivo final — conectarse a The Vault

Tras P5, el vault pasó a estar en la **misma IP del SSH del lab** (`192.168.0.238`) en
otros puertos.

1. Buscar el servidor HTTP (pista: puerto 49000–50000):

   ```bash
   nmap -Pn -n --open -p49000-50000 192.168.0.238
   # 49681/tcp open
   ```

2. Bajar la clave y el usuario del listado de directorio:

   ```bash
   curl http://192.168.0.238:49681/                               # listado
   curl http://192.168.0.238:49681/IMPORTANTE_NOMBRE_DE_USUARIO.txt  # usuario: bububu
   curl -s http://192.168.0.238:49681/supersecretkey -o ~/vaultkey
   chmod 600 ~/vaultkey
   ```

3. Conectarse (SSH del vault en el puerto 12222; passphrase = `string_equals`):

   ```bash
   ssh -o IPQoS=none -i ~/vaultkey -p 12222 bububu@192.168.0.238
   ```

Aparece un TUI con **"GANASTE!"** en letras de bloque. Se cierra con `q`, `Esc` o `Ctrl-C`.

**Conceptos / detalles:**
- `python -m http.server` (el `Server: SimpleHTTP/... Python/...` de la respuesta)
  arma un listado de directorio navegable → nunca dejes claves ahí.
- La **passphrase** cifra la clave privada SSH en reposo (`aes256-ctr` + `bcrypt` en el
  header del archivo); SSH la pide al cargar la clave, es distinta del password de login.
- El programa del vault es un TUI en Rust que paniqueaba con
  `cannot sample empty range` cuando la terminal tenía tamaño 0×0 (al pasarle un PTY
  sin `winsize`). Con una terminal real (o un PTY con `TIOCSWINSZ` seteado) renderiza bien.

---

## Trampas de entorno (no son parte del challenge pero aparecieron)

- **SSH que "timeout" pero `nc` conecta:** el cliente OpenSSH 10 marca los paquetes con
  **DSCP** (`IPQoS`) y algún equipo de red los descarta. Fix: `-o IPQoS=none`, o en
  `~/.ssh/config`:

  ```
  Host *
    IPQoS none
  ```

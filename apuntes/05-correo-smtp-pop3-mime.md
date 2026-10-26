# 05: correo electrónico: SMTP, POP3, MIME, base64 (Guía 4)

## Componentes

```
 MUA ──SMTP(587/25)──► MSA/MTA ──SMTP(25)──► MTA destino ──► MDA ──► buzón (Maildir) ◄──POP3(110)/IMAP(143)── MUA
(mutt,                 (postfix)  busca el MX     (postfix)    (local/       ~/Maildir         (dovecot)
 Thunderbird)                     del dominio                  dovecot-lda)
```

| Sigla | Qué es | En la VM |
|---|---|---|
| **MUA** (Mail User Agent) | programa del usuario: redacta y lee | mutt, Thunderbird, Gmail web |
| **MSA** (Submission Agent) | recibe el mail del MUA (puerto **587**, con autenticación) | postfix |
| **MTA** (Transfer Agent) | transporta entre servidores por **SMTP**, consulta el **MX** del destino | postfix |
| **MDA** (Delivery Agent) | deja el mail en el buzón | `local` de postfix → `~/Maildir/` |
| **MRA / servidor POP/IMAP** | deja que el MUA lea el buzón | dovecot |

Puertos: **25** SMTP entre servidores, **587** submission (STARTTLS + AUTH), **465**
SMTPS (TLS implícito), **110** POP3, **995** POP3S, **143** IMAP, **993** IMAPS.

## SMTP (RFC 5321)

```
S: 220 UbuntuA.itbadc.itba.edu.ar My-ESMTP Postfix (goated)   <- banner (smtpd_banner)
C: EHLO ubuntua                       <- EHLO = ESMTP (responde la lista de extensiones). HELO = SMTP viejo
S: 250-UbuntuA... / 250-PIPELINING / 250-SIZE / 250-STARTTLS / 250-8BITMIME / 250 SMTPUTF8
C: MAIL FROM:<sgiambelluca@pdc.lab>   <- SOBRE (envelope): remitente
S: 250 2.1.0 Ok
C: RCPT TO:<sgiambelluca@foo.pdc.lab> <- SOBRE: destinatario (uno por RCPT, se puede repetir)
S: 250 2.1.5 Ok
C: DATA
S: 354 End data with <CR><LF>.<CR><LF>
C: From: Alguien <alguien@example.org>     <- MENSAJE (RFC 5322): headers
C: To: pepe@example.org
C: Subject: hola
C:                                     <- línea vacía
C: hola mundo                          <- cuerpo
C: .                                   <- fin (una línea que empieza con "." se manda como ".." = dot-stuffing)
S: 250 2.0.0 Ok: queued as 0D7A1A0067
C: QUIT
S: 221 2.0.0 Bye
```

- **Códigos**: 2xx = ok, **3xx = seguí mandando** (354), **4xx = error temporal** (el que
  manda reintenta: greylisting, cola llena), **5xx = error permanente** (rebota: usuario
  inexistente, relay denegado).
- **Otros comandos**: `RSET` (abortar la transacción), `VRFY`/`EXPN` (casi siempre
  deshabilitados), `NOOP`, `STARTTLS`, `AUTH`.
- **Las líneas terminan en CR LF**: con netcat hay que usar `nc -C`.

### Sobre (envelope) vs headers (E57)

| | Sobre (SMTP) | Headers (dentro del DATA) |
|---|---|---|
| Remitente | `MAIL FROM` → se guarda como **`Return-Path:`**, y **a esa dirección van los rebotes** | `From:`: lo que **muestra** el MUA. Se puede poner cualquier cosa (spoofing) |
| Destinatario | `RCPT TO` → **a quién se entrega** realmente (`Delivered-To:`) | `To:`, `Cc:`: decorativos. No deciden la entrega. `Bcc` no aparece |

- Por eso se puede mandar un mail con `To: pepe@example.org` y que **te llegue a vos**:
  manda el RCPT TO.
- Si no se pone `To:` / `From:`, algunos servidores los completan o el MUA muestra
  "undisclosed-recipients".
- Cada servidor que lo transporta **agrega un header `Received:` arriba de todo**: leído de
  abajo hacia arriba es el recorrido del mail. También se agregan `Message-ID` y `Date` si
  faltan. Eso responde "¿el correo fue modificado?".
- **Rebotes (bounces)**: si un mail no se puede entregar, el MTA le manda al `MAIL FROM` un
  aviso (DSN, `multipart/report`) **con `MAIL FROM:<>` vacío**, para evitar loops de
  rebotes.

### Relay (E56)

- **Relay** = aceptar un mail para un dominio que **no es tuyo** y reenviarlo. Un **open
  relay** (que acepta relay de cualquiera) es un paraíso para el spam y termina en todas las
  listas negras.
- Política correcta: aceptar para **mis dominios** (`mydestination`) de cualquiera, y hacer
  relay sólo para **mi red** (`mynetworks`) o para usuarios **autenticados** (SASL en el
  587). En postfix: `smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated
  defer_unauth_destination`. Error típico: `554 5.7.1 Relay access denied`.
- Los ISP y las redes (como la del ITBA) **bloquean el puerto 25 saliente**, para que una
  máquina infectada no mande spam directo. Hay que pasar por el servidor de la institución
  (587 con autenticación).

## postfix

```bash
postconf -n                         # sólo lo que difiere del default (lo que configuraste)
postconf mydestination              # ver un parámetro
sudo postconf -e 'param = valor'    # cambiarlo en main.cf
sudo postfix check                  # chequear config y permisos
sudo systemctl reload postfix
mailq   (= postqueue -p)            # cola de salida
sudo postqueue -f                   # reintentar la cola ya
sudo postsuper -d ALL               # borrar la cola (-d ID para uno)
sudo tail -f /var/log/mail.log      # status=sent / deferred / bounced
```

| Parámetro (`/etc/postfix/main.cf`) | Significado |
|---|---|
| `myhostname` | FQDN del servidor (banner, Received) |
| `mydomain` / `myorigin` | dominio que se agrega a los remitentes locales (`/etc/mailname` = pdc.lab) |
| `mydestination` | dominios **finales** de esta máquina: se entregan localmente |
| `mynetworks` | IPs de confianza que pueden hacer relay |
| `relayhost` | servidor al que mandarle todo (smarthost). Vacío = entrega directa por MX |
| `home_mailbox = Maildir/` | entregar en `~/Maildir/` (**la barra final es la que dice "Maildir"**: sin barra es un archivo mbox) |
| `inet_interfaces` | dónde escucha (all / loopback-only) |
| `smtpd_banner` | texto del 220 |
| `/etc/aliases` + `newaliases` | alias locales (postmaster → root) |

### mbox vs Maildir

- **mbox**: **un archivo** con todos los mails concatenados, separados por líneas `From `.
  Necesita locking y, si se corrompe, se pierde todo.
- **Maildir**: **un archivo por mail**, en `tmp/` (mientras se escribe), `new/` (no leído)
  y `cur/` (leído, con flags en el nombre `:2,S`). No necesita locks y es seguro con NFS.

## POP3 (RFC 1939) y dovecot

```
+OK Dovecot (Ubuntu) ready.
USER sgiambelluca      +OK
PASS ******            +OK Logged in.        (en texto plano: en serio sólo con TLS/995)
STAT                   +OK 6 4521            (cantidad y bytes)
LIST                   +OK ... "1 820" ... "."
RETR 1                 +OK 820 octets  <mail completo>  .
TOP 1 0                headers del mail 1 (y 0 líneas de cuerpo)
UIDL                   id único de cada mail (para no bajarlo dos veces)
DELE 1                 marcado (se borra recién al hacer QUIT, en el estado UPDATE)
RSET                   desmarca los DELE
QUIT
```

- Estados: AUTHORIZATION → TRANSACTION → UPDATE.
- **POP3 vs IMAP**: POP3 **baja** los mails y en general los borra del servidor (un solo
  dispositivo, sin carpetas en el servidor). IMAP **trabaja sobre el servidor**: carpetas,
  flags, varios dispositivos sincronizados, búsqueda en el servidor.

### dovecot 2.4 (la de esta VM): ojo con la sintaxis

```
protocols { pop3 = yes }       # o en 2.3: protocols = pop3
mail_driver = maildir          # 2.4
mail_path   = ~/Maildir        # 2.4
# mail_location = maildir:~/Maildir     <- sintaxis 2.3 (la del doc del ex alumno): en 2.4 falla
```

```bash
sudo doveconf -n                          # config efectiva
sudo doveadm mailbox status -u USER messages INBOX
journalctl -u dovecot -f                  # errores de login, de permisos del Maildir...
```

## MIME (RFC 2045 a 2049)

SMTP original = **ASCII de 7 bits, líneas de hasta 1000 caracteres**. Para mandar acentos,
binarios y adjuntos, MIME agrega headers:

```
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="Sqe8mFq+a+xrWLVA"
                                                    <- (preámbulo, ignorado)
--Sqe8mFq+a+xrWLVA                                  <- "--" + boundary: empieza una parte
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: quoted-printable          <- (o 8bit si el server anuncia 8BITMIME)

h=C3=B3l=C3=A1 m=C3=BAnd=C3=B3 =C3=B1
--Sqe8mFq+a+xrWLVA
Content-Type: image/jpeg
Content-Disposition: attachment; filename="marca-itba.jpg"
Content-Transfer-Encoding: base64

/9j/4AAQSkZJRgABAgAAZABkAAD/...
--Sqe8mFq+a+xrWLVA--                                <- "--" + boundary + "--": fin del multipart
```

| Header | Para qué |
|---|---|
| `Content-Type` | media type + parámetros (`charset`, `boundary`, `name`) |
| `Content-Transfer-Encoding` | cómo se codificó para viajar: `7bit`, `8bit`, `binary`, **`quoted-printable`**, **`base64`** |
| `Content-Disposition` | `inline` (mostrar en el cuerpo) o `attachment; filename="..."` (adjunto) |
| `Content-ID` | `<id@dominio>` para referenciar una parte desde el HTML: `<img src="cid:id@dominio">` |

| Tipo | Uso |
|---|---|
| `multipart/mixed` | partes independientes: cuerpo + adjuntos |
| `multipart/alternative` | **la misma** información en varios formatos (text/plain y text/html). Va del más simple al más rico y el MUA muestra el último que entiende. El text/plain va por compatibilidad, accesibilidad y los filtros de spam |
| `multipart/related` | partes que se usan juntas: HTML + imágenes embebidas (`cid:`) |
| `multipart/digest` | colección de mensajes (cada parte es `message/rfc822` por defecto) |
| `multipart/report` | avisos de entrega fallida (DSN): texto + `message/delivery-status` + el original |
| `message/rfc822` | un mail completo adentro de otro (**reenviar como adjunto**) |

La estructura típica de un mail de Gmail con HTML y adjuntos (E70):

```
multipart/mixed
├── multipart/related                 (si hay imágenes embebidas)
│   ├── multipart/alternative
│   │   ├── text/plain
│   │   └── text/html
│   └── image/png (Content-ID)
├── text/plain   (adjunto .txt, Content-Disposition: attachment)
├── image/jpeg   (adjunto)
└── image/png    (adjunto)
```

Las partes que contienen otras son las **multipart/\*** y **message/rfc822**.

## Base64 (RFC 4648)

Toma 3 bytes (24 bits), los parte en 4 grupos de 6 bits y cada grupo se convierte en un
carácter: `A-Z`=0–25, `a-z`=26–51, `0-9`=52–61, `+`=62, `/`=63. Con `=` se rellena hasta
múltiplo de 4.

**E63 a mano, `HO LA`**:

```
H        O        ' '      L        A
01001000 01001111 00100000 01001100 01000001
010010 000100 111100 100000 | 010011 000100 0001(00)
  18     4      60     32   |   19     4      4      -> S E 8 g | T E E =
=> SE8gTEE=
```

**E64, `Y2hhdQ==`**: Y=24, 2=54, h=33, h=33, d=29, Q=16 →
`011000 110110 100001 100001 011101 010000` → `01100011 01101000 01100001 01110101` =
**`chau`**. Los `==` indican que el último grupo tenía 1 solo byte.

- **Tamaño**: `4·⌈n/3⌉` (+33 %). En MIME, además, se corta cada **76 caracteres** con CRLF
  (≈ +35 % en total). 9 MB en base64 ≈ 12 MB, así que no entra en un límite de 10 MB (E65).
- **Base64url** (§5): `-` y `_` en lugar de `+` y `/`, y en general **sin `=`**. Es para URLs
  y nombres de archivo (E67). `+` en un formulario es un espacio y `/` separa el path.
- **Base32** (A-Z, 2-7, +60 %) es case-insensitive y no tiene caracteres que se confunden:
  mejor para dictar o escribir a mano (E66). **Base16** = hex (+100 %).

## Quoted-printable

Para texto **casi ASCII**: los bytes > 126, el `=` y los de control se escriben `=HH`. Las
líneas tienen 76 caracteres como máximo, y un `=` al final de la línea es un *soft line
break* (la línea sigue). Los espacios al final de una línea se codifican (`=20`).
Ejemplo de E69, con charset iso-8859-1: `h=F3l=E1` → `hólá`, `=2D-=20` → `-- `.
Comparado con base64: QP queda legible y crece poco si el texto es casi todo ASCII; base64
es mejor para binarios.

## Antispam (E61, E62)

| Técnica | Cómo funciona | A favor | En contra |
|---|---|---|---|
| **SPF** (RFC 7208) | TXT en el DNS del dominio del **MAIL FROM** con las IPs autorizadas (`v=spf1 ip4:... include:_spf.google.com -all`). El receptor compara con la IP que se conecta | simple, sólo un registro DNS | **se rompe con el reenvío** (forwarding); no valida el `From:` visible; tiene un límite de 10 lookups |
| **DKIM** (DomainKeys) | el servidor **firma** headers y cuerpo; la clave pública está en DNS (`selector._domainkey.dominio TXT`) | garantiza integridad y origen; sobrevive al reenvío | gestión de claves; se rompe si una lista de correo modifica el mensaje |
| **DMARC** | política (`_dmarc.dominio TXT`) que pide que SPF o DKIM **coincidan con el `From:`** + reportes | cierra el spoofing del From visible | requiere SPF y DKIM bien configurados |
| **Greylisting** | rechaza **temporalmente** (4xx) la primera vez que aparece un (IP, remitente, destinatario). Un MTA real reintenta; muchos bots no | muy efectivo y barato | **demora** el primer mail (minutos) y algunos servidores mal hechos no reintentan |
| **Filtros bayesianos** | probabilidad de spam según las palabras, entrenado con spam y ham | se adapta a cada usuario | necesita entrenamiento; falsos positivos; se evade con "v1agra" |

`dig TXT itba.edu.ar +short | grep spf` y después seguir cada `include:` para juntar todas
las IPs (`ip4:`/`ip6:`) autorizadas.

---

## En parciales anteriores

La resolución completa, paso a paso, está en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 7 es el mismo mail con `X-Parcial: 2026/2`. `simulacro.sh verificar` revisa el que te llegó a `~/Maildir` (base64, encoded-word, From).

**2024 2C, Ej IV**: mandar a mano un mail "que cumpla los estándares", con un header
`X-Parcial: 2024/2`, el Subject `¡Buenos días!`, el remitente con nombre + cuenta ITBA, el
cuerpo `¡Hola mundo!`, entregado a `{legajo}@mail.sebikul.com` y **legible por MUAs sin
soporte de quoted-printable**. Después había que verificarlo por POP3.

```
MAIL FROM:<legajo@itba.edu.ar>
RCPT TO:<65522@mail.sebikul.com>                <- el SOBRE decide la entrega
DATA
Date: Mon, 26 Oct 2026 15:00:00 -0300
Message-ID: <20261026150000.65522@itba.edu.ar>
From: Nombre Apellido <legajo@itba.edu.ar>
To: <65522@mail.sebikul.com>
Subject: =?UTF-8?B?wqFCdWVub3MgZMOtYXMh?=       <- encoded-word RFC 2047 (los headers son ASCII)
X-Parcial: 2024/2
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64               <- NO quoted-printable (requisito f)

wqFIb2xhIG11bmRvIQ0K
.
```

Lo que evalúan:

- **Encoded-words**: `=?charset?B?base64?=` o `=?charset?Q?texto_con_=XX?=`. Hacen falta
  en Subject y From si hay caracteres no ASCII.
- **Elegir el Content-Transfer-Encoding** según lo que pide la consigna (base64 vs QP vs
  8bit).
- **Headers recomendados**: `Date`, `Message-ID`, `MIME-Version`, y `Content-Type` con
  `charset`.
- **Sobre vs headers**: `RCPT TO` es el que entrega. `To:` es decorativo.
- **POP3**: `USER`, `PASS`, `LIST`, `RETR n`, `QUIT`, con `nc -C`.

Para calcular el base64: `printf '%s' '¡Buenos días!' | base64` (el `-n` / `%s` evita el `\n`
del final). Para probarlo local:
`nc -C -q 3 localhost 25 < ~/Protos/ejercicios/parciales/2024-2c-ej4-mail-PRUEBA-LOCAL.txt`.

---

## Más práctica (material del repo Protos-ITBA)

- **Truco para armar mails complicados** (multipart, adjuntos, ñ): mandátelo primero desde
  Gmail, abrí **"Mostrar original"** y copiá la estructura MIME (boundaries, headers de cada
  parte, el adjunto ya en base64). Después cambiá lo que pida la consigna (From/To visibles,
  la codificación, headers extra) y mandalo con `nc -C`.
- **Ej 4 de práctica** (en `15-ejercicios-extra.md`): From `aliceandbob@gmail.com` y To "A
  quien le interese" **en los headers**, pero el `RCPT TO` a tu casilla.
  `multipart/mixed` contiene un `multipart/alternative` (text/plain + text/html, **ambos en
  base64**) más un `image/png` adjunto.
- **Estados POP3**: AUTHORIZATION (sólo USER/PASS) → TRANSACTION (LIST, RETR, DELE, RSET,
  UIDL...) → UPDATE (al hacer QUIT se aplican los DELE). Si cortás con Ctrl+C **no se borra
  nada**.
- **Puertos con TLS**: 25 (entre servidores, STARTTLS opcional), **587** (submission,
  STARTTLS + AUTH), **465** (SMTPS, TLS desde el inicio), 993 (IMAPS), 995 (POP3S).
  **STARTTLS** "sube" a TLS una conexión que empezó en texto plano, en el mismo puerto.
- En `cheat_03` del repo la configuración de dovecot está en sintaxis **2.3**
  (`mail_location`). En esta VM (2.4) se usa `mail_driver` + `mail_path`.

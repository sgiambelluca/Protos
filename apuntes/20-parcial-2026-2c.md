# 20: Parcial práctico 2026 2C (el que rendiste) — para practicarlo en la VM

Los 4 ejercicios del parcial que tomaste, armados como **escenarios repetibles** en esta misma
VM (todo por loopback, como el día del parcial). La idea: los levantás, los resolvés a ciegas,
y un corrector te dice OK/FALLA por requisito. Después mirás la resolución.

Son **guiados**: cada respuesta te deja la **pista del próximo paso**, con un poco de
storytelling, así no andás adivinando el mecanismo. Un `curl` directo te avisa que algo está
detrás de un proxy en tal puerto; el sitio interno te da las credenciales; el mail te pide el
reporte; el server de descarga te dice qué bajar. Vos ejecutás cada paso y seguís las migas.

El enunciado real y los pasos que anotaste están en `~/Downloads/Examen.pdf`. Acá cada ejercicio
tiene: **enunciado** (para hacer a ciegas), **resolución** y **las trampas**.

## Cómo se usa

```bash
S=~/Protos/scripts/parcial-2026-2c.sh

$S montar    ej1      # levanta los servidores del Ej1 (o ej2/ej3/ej4, o 'todo')
$S verificar ej1      # corrige: OK / FALLA por requisito
$S solucion  ej1      # muestra la resolución (en el Ej4 además te deja la zona aplicada)
$S limpiar   ej1      # saca TODO lo del Ej1 (servidores + tu solución)
```

- Corre **todo en esta sola VM**: los servidores escuchan en `127.0.0.1`/puertos locales y vos
  resolvés con `curl`, `dig`, `nc`, `ssh` desde la misma máquina. No hace falta la Mac ni red del
  laboratorio (por eso entra en tu alcance).
- **No toca** tus zonas `cachito.com` / `pepito.com` / `foo.pdc.lab` ni tu `/var/www`. Lo suyo vive
  en `/srv/parcial-2026-2c`, usa usuarios propios (`pepito`, `debsec`) y marcadores en los configs.
- Lo único que se instaló para esto fue **Squid** (para el proxy del Ej1). El resto ya lo tenías.

> Mientras tengas montado el Ej4, `verificar-todo.sh` puede dar FALLA en `named-checkconf -z`
> hasta que termines la zona: es esperable (igual que con el simulacro).

---

## Ej1 — Hackerspace detrás de un proxy (Squid :3126)

**Enunciado.** Pertenecés a DebSec. Conectate al hackerspace mediante el proxy
`http://ej1.protos.foo:3126` para ver las novedades del grupo. El tablón de novedades es sólo
para miembros.

**La gracia.** El hackerspace (`hackerspace.protos.foo:8090`) **sólo lo conoce el proxy**: su
nombre no está en tu resolver, así que `curl` directo **no resuelve**. El que resuelve el nombre
es el proxy. Es exactamente la diferencia entre `socks5h://` (resuelve el proxy) y `socks5://`
(resolvés vos) — ver concepto A en [14-resoluciones-parciales.md](14-resoluciones-parciales.md).

**Resolución.**
```bash
# directo NO resuelve (ese nombre sólo lo sabe el proxy):
curl http://hackerspace.protos.foo:8090/            # -> Could not resolve host

# por el proxy SÍ (el proxy resuelve y trae la página):
curl -x http://ej1.protos.foo:3126 http://hackerspace.protos.foo:8090/
#   ahí ves las credenciales de miembro: debsec / hackerspace, y el link /novedades/

# el tablón pide Basic auth -> se la pasás con -u:
curl -x http://ej1.protos.foo:3126 -u debsec:hackerspace \
     http://hackerspace.protos.foo:8090/novedades/
#   el último anuncio es la FLAG{...}
```

**Para acordarte.**
- `-x http://proxy:puerto` = proxy **HTTP**. El pedido sale en *forma absoluta*
  (`GET http://host/... HTTP/1.1`) en vez de la *forma de origen* (`GET /...`).
- `-x socks5h://proxy:puerto` = proxy **SOCKS** resolviendo el nombre del lado del proxy (la `h`).
  `socks5://` (sin `h`) resuelve de tu lado — y acá fallaría, igual que el directo.
- Basic auth: `-u user:pass` manda `Authorization: Basic base64(user:pass)`. Sin credenciales el
  server responde **401** con `WWW-Authenticate: Basic`.

Relacionado: [02-uri-http.md](02-uri-http.md) (métodos, auth), [03-nginx.md](03-nginx.md).

---

## Ej2 — nginx por Host + proxy interno + SSH con passphrase

**Enunciado.** El host `192.168.0.238` tiene nginx con:
- `server_name google.com` en `:80`, `root /var/www` (ahí está, en `/sec/mykey`, la clave privada
  de `pepito`);
- `server_name secrethost` en `:81` que hace `proxy_pass` a `127.0.0.1:8000` (host interno).

Además, SSH sólo acepta a `pepito` con clave privada, pero la clave tiene **passphrase**.
Extraé la clave, conseguí la passphrase y entrá por SSH.

**Resolución.**
```bash
# 1) bajar la clave: el vhost se elige por el header Host (no por DNS)
curl http://127.0.0.1/sec/mykey -H "Host: google.com" -o mykey
head -1 mykey        # -----BEGIN OPENSSH PRIVATE KEY-----

# 2) permisos estrictos, si no ssh/ssh-keygen la rechazan
chmod 600 mykey

# 3) la passphrase vive en el host interno, que sólo se alcanza por el proxy del :81
curl http://127.0.0.1:81/ -H "Host: secrethost"
#   -> "La passphrase ... es: clave-del-parcial"

# 4) entrar por SSH como pepito (cuando pida passphrase, poné la del paso 3)
ssh -i mykey pepito@127.0.0.1
```

**Las trampas.**
- El `chmod 600` del paso 2 **no es opcional**: con permisos abiertos, hasta `ssh-keygen -y` tira
  "UNPROTECTED PRIVATE KEY FILE" y la ignora.
- El `:81` reenvía a `127.0.0.1:8000`, que *no es accesible directo desde afuera*: por eso la
  passphrase "está escondida" y hay que pasar por el proxy reverso.
- El vhost se elige por **Host**, no por la IP ni por DNS: `-H "Host: google.com"` alcanza aunque
  `google.com` no esté en tu `/etc/hosts`.

Relacionado: [03-nginx.md](03-nginx.md) (server_name, proxy_pass), [10-ssh.md](10-ssh.md)
(claves de usuario, passphrase).

---

## Ej3 — Mandar y verificar un mail a mano (SMTP + POP3)

**Enunciado.** (a) Tu compañero intentó mandar un mail por `nc` y cometió errores de protocolo:
marcalos. (b) Verificá por POP3 si el mensaje llegó.

**a) Errores típicos de una sesión SMTP por `nc`** (los del parcial):

| En la sesión | El error | Lo correcto |
|---|---|---|
| `nc 192.168.0.168` | falta el puerto y falta `-C` (CRLF) | `nc -C 192.168.0.168 25` |
| `HELLO localhost` | no es comando SMTP → `500` | `EHLO localhost` (o `HELO`) |
| `MAIL TO:` | no existe; el remitente es `MAIL FROM` y el destinatario `RCPT TO` | `RCPT TO:<...>` |
| `<you>` | no es una casilla real | una dirección real, p. ej. `<legajo@pdc.lab>` |
| falta la línea en blanco antes del cuerpo | headers y cuerpo se mezclan | línea vacía entre headers y cuerpo |
| no termina con `.` sola | el server nunca acepta el mensaje (`250 queued`) | línea con sólo `.` |

El mensaje **queda aceptado recién** cuando, después del `.`, el server responde
`250 ... queued as <ID>`. Si la sesión se corta antes, se descarta.

**b) Práctica en la VM.** Hay una casilla: usuario POP3 `debsec`, clave `debsec`, dominio `pdc.lab`.

```bash
# leer por POP3 (:110)
nc -C 127.0.0.1 110
USER debsec
PASS debsec
STAT            # cuántos mensajes
LIST            # número + tamaño
RETR 1          # muestra el mail (el cuerpo viene en base64)
QUIT
# decodificar el cuerpo:   echo '<base64>' | base64 -d

# mandar uno a mano por SMTP (:25) — con nc hace falta -C (CRLF)
nc -C 127.0.0.1 25
EHLO pdc.lab
MAIL FROM:<debsec@pdc.lab>
RCPT TO:<debsec@pdc.lab>
DATA
From: DebSec <debsec@pdc.lab>
To: <debsec@pdc.lab>
Subject: DebSec report
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

b2ssIHRvZG8gZW4gb3JkZW4=
.
QUIT
```

**Para acordarte.**
- `nc -C` = termina líneas con **CRLF**, que es lo que piden SMTP/POP3. Sin `-C` manda sólo LF y
  el `.` final puede no cerrar el mensaje.
- Los mails sin leer están en `~/Maildir/new`; cuando un cliente POP3 hace login, pasan a
  `~/Maildir/cur`. (Por eso el corrector busca en los dos.)
- `EHLO` (ESMTP) vs `HELO` (SMTP viejo): los dos saludan; `HELLO` no existe.

Relacionado: [05-correo-smtp-pop3-mime.md](05-correo-smtp-pop3-mime.md).

---

## Ej4 — Reconstruir una zona DNS desde un PCAP (bind9)

**Enunciado.** Cachito borró la config de la zona DNS y no hay backups. Quedó una captura
(`backup.pcap`) con queries y replies del namemaster. Reconstruí la zona `cachito.parcial` con
bind9 y agregá un TXT que diga `cachito tiene prohibido editar este archivo`.

Esto es lo mismo que [19-dns-desde-pcap.md](19-dns-desde-pcap.md), con los datos de este parcial.
El corrector `practicar-dns-pcap.sh` sirve para la captura genérica; acá el pcap es el del parcial.

**Resolución.**
```bash
# 1) bajar la captura (en el parcial se bajaba por HTTP del :8000; acá va en :8008)
curl -O http://127.0.0.1:8008/backup.pcap
wireshark backup.pcap      # la GUI no tiene el perfil AppArmor que molesta a tshark
#   (para leer por consola, por el AppArmor:  tshark -r - < backup.pcap -Y dns )

# 2) de cada reply AUTORITATIVA (flag aa) saco un registro, con su TTL:
#      SOA, NS ns1, A de @, A de ns1, A de mail, MX 10 mail, CNAME www -> @, TXT
#    El SOA también aparece en una respuesta NEGATIVA (NXDOMAIN), en la sección Authority.
```

Zona reconstruida (`/etc/bind/zones/db.cachito.parcial`):
```dns
$TTL 3600
$ORIGIN cachito.parcial.
@   IN  SOA ns1.cachito.parcial. admin.cachito.parcial. (
            2018010101 ; serial original (2018010100) + 1 por agregar el TXT
            3600 1800 1209600 300 )
@           IN  NS    ns1.cachito.parcial.
ns1         IN  A     192.168.0.238
@           IN  A     192.168.0.238
www         IN  CNAME @
@           IN  MX 10 mail.cachito.parcial.
mail        IN  A     192.168.0.238
@       864000 IN TXT "cachito meme: no toques la zona"
@              IN TXT "cachito tiene prohibido editar este archivo"
```

Declararla y levantarla:
```bash
sudo nano /etc/bind/named.conf.local
#   zone "cachito.parcial" { type master; file "/etc/bind/zones/db.cachito.parcial"; };
sudo named-checkconf
sudo named-checkzone cachito.parcial /etc/bind/zones/db.cachito.parcial
sudo rndc reload            # (si la zona ya estaba declarada y sólo cambió el archivo)
# dig @127.0.0.1 cachito.parcial ANY +noall +answer   # tienen que venir con flag 'aa'
```

**Las trampas (las que más cuestan).**
- **El TTL del TXT "meme" es 864000** (10 días), distinto del resto (3600). Hay que copiar el TTL
  **tal cual sale de la captura**, no asumir el `$TTL`.
- **Los dos TXT de `@` son el MISMO RRset** (`cachito.parcial/TXT`) y un RRset tiene **un solo
  TTL**: BIND unifica ambos al TTL del primero (864000) y avisa `TTL set to prior TTL (864000)`.
  No es un error — es correcto en DNS. Por eso no tiene sentido ponerle 3600 al TXT nuevo: se
  ignora.
- **`www` es un CNAME a `@`**, no un A.
- **El SOA sale de una respuesta negativa** (NXDOMAIN): el serial, los timers y el minimum TTL
  están ahí. El **serial sube en 1** porque agregaste un registro.
- `rndc reconfig` carga zonas **nuevas**; si cambiás el archivo de una zona ya declarada, usá
  `rndc reload` (o `rndc reload <zona>`).

Relacionado: [04-dns-y-bind9.md](04-dns-y-bind9.md), [19-dns-desde-pcap.md](19-dns-desde-pcap.md),
[06-wireshark-tcpdump.md](06-wireshark-tcpdump.md).

---

## Qué practica cada ejercicio (y con qué apunte repasar)

| Ej | Tema | Apunte |
|---|---|---|
| 1 | proxy (HTTP/SOCKS), forma absoluta, Basic auth, resolución del lado del proxy | 02, 03 |
| 2 | nginx vhost por Host, proxy reverso, SSH con clave + passphrase, `chmod 600` | 03, 10 |
| 3 | SMTP y POP3 a mano con `nc -C`, MIME base64, el `.` final | 05 |
| 4 | reconstruir zona desde captura, SOA del NXDOMAIN, TTL por RRset, CNAME, serial +1 | 04, 19 |

Es el patrón de siempre (ver [14](14-resoluciones-parciales.md)): un **"llegar a algo"** (proxy),
un **nginx proxy reverso**, un **protocolo de aplicación a mano** (mail) y uno de **DNS**.

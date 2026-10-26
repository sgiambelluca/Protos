# Guía 4: correo electrónico

Teoría (SMTP, sobre vs headers, POP3, MIME, base64, quoted-printable, SPF/DKIM):
`../../apuntes/05-correo-smtp-pop3-mime.md`

## Lo que ya estaba hecho en clase (no se tocó, salvo lo que se indica)

| Archivo | Qué hay |
|---|---|
| `/etc/postfix/main.cf` | `home_mailbox = Maildir/`, `mydestination` con pdc.lab, `myorigin = /etc/mailname` (pdc.lab), banner propio. **Se agregó `foo.pdc.lab` a mydestination** para que coincida con el MX de la zona DNS |
| `/etc/dovecot/...` | sólo POP3 (`protocols { pop3 = yes }`), `mail_driver = maildir`, `mail_path = ~/Maildir` |
| `~/Maildir/{new,cur,tmp}` | los mails de clase, más uno de prueba del 26/10 |

**Ojo con la versión de Dovecot.** Esta VM tiene la 2.4. La guía del ex alumno usa la
sintaxis vieja (2.3): `mail_location = maildir:~/Maildir`. En 2.4 eso es **inválido** y se
escribe `mail_driver = maildir` + `mail_path = ~/Maildir`. Para ver la config efectiva:
`sudo doveconf -n`.

## Agregado ahora

| Archivo | Ejercicio | Qué hace |
|---|---|---|
| `~/.muttrc` (copia en `~/Protos/config/home/muttrc`) | E59, E60, E70 | mutt manda por SMTP a postfix y lee `~/Maildir`. Con la tecla `G` trae por POP3 |
| `smtp-local.txt` | E57, E58 | sesión SMTP completa para mandar con netcat |
| `e65-imagen.b64` / `e65-imagen.jpg` | E65 | la imagen base64 del enunciado, y ya decodificada |

## Comandos

```bash
# ---- E55: a qué servidor hay que conectarse para entregar a @itba.edu.ar
dig MX itba.edu.ar +short           # el de menor número (aspmx.l.google.com)

# ---- E57/E58: SMTP a mano
nc -C localhost 25                   # -C: cada Enter manda \r\n (SMTP lo exige)
#   HELO ubuntua
#   MAIL FROM:<sgiambelluca@pdc.lab>          <- SOBRE: remitente (rebotes van acá -> Return-Path)
#   RCPT TO:<sgiambelluca@foo.pdc.lab>        <- SOBRE: destinatario real
#   DATA
#   From: Alguien <alguien@example.org>       <- HEADERS: lo que muestra el MUA (se puede falsificar)
#   To: pepe@example.org                      <- no influye en a quién se entrega
#   Subject: PDC Ejercicio 1
#                                              <- línea vacía: separa headers del cuerpo
#   hola mundo
#   .                                          <- un punto solo en la línea = fin del DATA
#   QUIT
nc -C -q 3 localhost 25 < ~/Protos/ejercicios/g04-correo/smtp-local.txt     # lo mismo, de un archivo

# ver dónde quedó (Maildir: un archivo por mail; new = no leído, cur = leído)
ls -t ~/Maildir/new | head -1
cat ~/Maildir/new/"$(ls -t ~/Maildir/new | head -1)"
#   Return-Path / Delivered-To salen del SOBRE. From / To son los headers que escribiste vos.

# ---- cola y logs (sugerencia del enunciado)
mailq                                # = postqueue -p : mails pendientes en la cola
sudo postqueue -f                    # reintentar ya todo lo de la cola
sudo postsuper -d ALL                # borrar toda la cola
sudo tail -f /var/log/mail.log       # o: journalctl -u postfix -f
#   rebote a una dirección que no existe: "status=bounced (unknown user...)"
#   el aviso de rebote (bounce) se manda con MAIL FROM:<> (remitente vacío, para evitar loops)

# ---- E58: POP3 a mano (puerto 110)
nc -C localhost 110
#   USER sgiambelluca
#   PASS <tu contraseña>
#   STAT          -> +OK <cantidad> <bytes>
#   LIST          -> número y tamaño de cada mail
#   RETR 1        -> trae el mail 1 completo (termina con una línea ".")
#   TOP 1 0       -> sólo los headers del mail 1
#   DELE 1        -> lo marca para borrar (recién se borra al hacer QUIT)
#   RSET          -> desmarca los DELE
#   QUIT
sudo doveadm mailbox status -u sgiambelluca messages INBOX     # sin contraseña, como root

# ---- E59/E60: MUA (mutt)
echo "hólá múndó ñ" | mutt -s "E59" -a ~/Protos/ejercicios/g04-correo/e65-imagen.jpg -- sgiambelluca@localhost
#   Wireshark en la interfaz "lo", filtro "smtp || pop": mutt usa EHLO (no HELO), manda MIME-Version,
#   Content-Type multipart/mixed con boundary, el texto text/plain; charset=utf-8 con
#   Content-Transfer-Encoding: 8bit (porque postfix anuncia 8BITMIME en la respuesta al EHLO;
#   si no lo anunciara usaría quoted-printable) y la imagen image/jpeg en base64.
#   (probado el 26/10: queda en ~/Maildir/new con Subject "E59 prueba")
mutt                                 # leer. Sobre un mail: "e" o "|less" para ver la fuente completa
#   G -> fetch-mail por POP3 (pide la contraseña)

# ---- E62: SPF de itba.edu.ar
dig TXT itba.edu.ar +short | grep spf
dig TXT _spf.google.com +short       # seguir cada include: hasta llegar a los ip4:/ip6:
```

## Codificaciones (E63 a E69), resueltas

| Ej. | Resultado |
|---|---|
| E63 `HO LA` → base64 | `SE8gTEE=` (cuenta hecha a mano en el apunte 05) |
| E64 `Y2hhdQ==` | `chau` |
| E65 qué es | Una **JPEG**: empieza con `FF D8 FF E0 ... JFIF` y termina con `FF D9`. Es de 120x47 px |
| E65 tamaños | Original **2424 bytes**, codificado **3232 caracteres** (= 4 · ⌈2424/3⌉). En el doc del ex alumno los números están mal |
| E65 fórmula | `tamaño_b64 = 4 · ⌈n / 3⌉`, más los CRLF si se corta en líneas de 76 (MIME) → ~ +35 % |
| E65 mail de 9 MB con límite de 10 MB | **No entra**: 9 MB · 4/3 ≈ 12 MB, más los headers |
| E67 base64 en URL | `+` y `/` chocan con la sintaxis de URL (`/` separa el path, `+` es espacio en formularios) y `=` también. Hay que usar **base64url** (`-` y `_`, RFC 4648 §5) **sin padding**: `QqRO5D8dY6n2VxPLp21CMDzMNac` (27 caracteres) |
| E69 quoted-printable | `hólá cómó` / `té vá` / `-- ` (guión, guión, espacio = separador de firma) / `Buenos Aires, Argentina` |

```bash
base64 -d e65-imagen.b64 > /tmp/x.jpg && file /tmp/x.jpg     # JPEG image data, JFIF ... 120x47
wc -c e65-imagen.b64 e65-imagen.jpg
echo -n 'HO LA' | base64                                     # SE8gTEE=   (-n: SIN el \n del final)
echo 'Y2hhdQ==' | base64 -d                                  # chau
echo 'QqRO5D8dY6n2VxPLp21CMDzMNac=' | base64 -d | xxd        # los 20 bytes del id de E67
```

## E57 contra la cuenta del ITBA

Eso se hizo en clase. Desde casa el puerto 25 saliente puede estar bloqueado por el ISP y
Gmail rechaza o marca como spam lo que llega de una IP residencial sin SPF/DKIM. Se puede
seguir en `/var/log/mail.log` (`status=deferred` / `bounced`).

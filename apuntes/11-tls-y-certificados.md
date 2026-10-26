# 11: TLS, certificados y mkcert (Guía 2 E41)

## Qué da TLS

**Confidencialidad** (cifrado simétrico con claves negociadas), **integridad** (AEAD/MAC)
y **autenticación del servidor** (certificado). Opcionalmente, también del cliente (mTLS).
HTTPS es HTTP adentro de TLS, en el puerto 443.

**Handshake TLS 1.3** (simplificado):

1. ClientHello: versiones, cifrados, **SNI** (el nombre del sitio, **en texto plano**) y la
   parte del cliente del intercambio de claves.
2. ServerHello + certificado + firma + Finished.
3. El cliente valida el certificado y desde ahí todo va cifrado (1 RTT).

## Certificados X.509 y PKI

- Un **certificado** es la **clave pública** del server, el **nombre** (Subject y, sobre
  todo, **SAN**: Subject Alternative Names, que es donde el cliente busca el hostname), el
  período de validez y el **Issuer**, todo **firmado por una CA**.
- **CA** (Autoridad de Certificación): el navegador o el SO traen una lista de **CAs raíz
  confiables** (*trust store*). La cadena es raíz → intermedia → certificado del sitio. El
  server tiene que mandar **la hoja + las intermedias**.
- **Clave privada**: queda **sólo en el servidor** (permisos 600). Con ella el server
  demuestra que es el dueño del certificado. Si se filtra, cualquiera puede hacerse pasar
  por el sitio.
- **Autofirmado** = no lo firmó una CA confiable, así que el navegador muestra una
  advertencia.
- **PKI local con mkcert**: crea **tu propia CA** e **instala la raíz** en el trust store del
  sistema y de Firefox/Chrome. Después firma certificados para los nombres que quieras
  (`foo`, `localhost`). Esos certificados son confiables **sólo en las máquinas donde
  instalaste esa CA**.

```bash
mkcert -install            # crea la CA (~/.local/share/mkcert/rootCA.pem + rootCA-key.pem) y la instala
mkcert -CAROOT             # dónde está la CA
mkcert foo                 # foo.pem (certificado, PÚBLICO) + foo-key.pem (clave PRIVADA)
mkcert foo bar localhost 127.0.0.1    # varios nombres (SAN) en un mismo certificado
```

- nginx: `ssl_certificate` = **foo.pem** (público), `ssl_certificate_key` =
  **foo-key.pem** (privado). Si se invierten, falla con `PEM_read_bio_X509...`. Un error
  muy común.
- **Firefox de Ubuntu es snap**: tiene su propio almacén de certificados en
  `~/snap/firefox/common/.mozilla/firefox/<perfil>/cert9.db`. Hay que reiniciar Firefox
  después de `mkcert -install`. Si no lo toma: `certutil -A -d sql:<perfil> -t "C,," -n
  mkcert -i "$(mkcert -CAROOT)/rootCA.pem"` (lo hace `instalar-configs.sh`).
- `curl` usa el trust store **del sistema** (`/etc/ssl/certs`), donde mkcert también
  instaló la CA. Por eso `curl https://foo/` anda sin `-k`.

```bash
openssl s_client -connect 127.0.0.1:443 -servername foo </dev/null   # cadena, protocolo, cifrado
openssl x509 -in /etc/nginx/ssl/foo.pem -noout -subject -issuer -dates -ext subjectAltName
curl -v https://foo/        # "SSL certificate verify ok", issuer: mkcert development CA
curl -k https://...         # -k: NO verificar (sólo para pruebas)
```

## HSTS

`Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` le dice al
navegador que, durante ese tiempo, **sólo use HTTPS** con ese sitio. La **lista de precarga
HSTS** viene adentro de Chrome y Firefox. Ahí están TLDs enteros de Google, como `.foo`,
`.dev`, `.app` y `.page`. Por eso `http://foo/` en el navegador se convierte solo en
`https://foo/` (el "aviso" de E36). Lo mismo pasa con protos.foo.

## Errores comunes

| Mensaje | Causa |
|---|---|
| `SEC_ERROR_UNKNOWN_ISSUER` / `self-signed certificate` | la CA no está en el trust store (falta `mkcert -install` o reiniciar el navegador) |
| `SSL_ERROR_BAD_CERT_DOMAIN` / `no alternative certificate subject name matches` | el nombre de la URL no está en el SAN del certificado |
| `certificate has expired` | venció (los de mkcert duran unos 2 años y 3 meses) |
| nginx: `cannot load certificate key` | la ruta está mal, faltan permisos o se invirtieron .pem y -key.pem |
| los certificados "desaparecieron" | estaban en `/tmp` (como en la guía) y se reinició la máquina |

---

## En parciales anteriores

La resolución completa, paso a paso, está en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 2 pide que ande también en Firefox y Chrome. El certificado necesita SAN y tiene que estar en el almacén del navegador (mkcert), no sólo en el del sistema.

**2025 2C, Ej IV**: exponer por HTTPS (`https://seguro.protos.foo`) un servidor HTTP
inseguro (`parcial.protos.foo`), y que **`curl https://seguro.protos.foo` funcione sin
opciones** (sin `-k`). Hay que generar un certificado **y hacerlo confiable**:

```bash
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
     -keyout /etc/ssl/private/seguro.key -out /etc/ssl/certs/seguro.crt \
     -subj "/CN=seguro.protos.foo" -addext "subjectAltName=DNS:seguro.protos.foo"
sudo cp /etc/ssl/certs/seguro.crt /usr/local/share/ca-certificates/seguro.crt   # .crt obligatorio
sudo update-ca-certificates                                                      # "1 added"
#   o, con mkcert ya instalado:  mkcert seguro.protos.foo
```

| Flag de openssl | Qué hace |
|---|---|
| `-x509` | certificado autofirmado directo (sin CSR) |
| `-newkey rsa:2048` | genera la clave |
| `-nodes` | clave **sin passphrase** (si no, nginx no puede leerla sola) |
| `-subj "/CN=..."` | nombre |
| `-addext subjectAltName=DNS:...` | **SAN**: lo exigen los navegadores |

Probado en la VM: sin `update-ca-certificates`, curl sale con **exit 60** ("unable to get
local issuer certificate" / self-signed). Después del update anda, tanto con sólo CN (curl
acepta CN) como con SAN. Firefox/Chrome **sí** exigen SAN.

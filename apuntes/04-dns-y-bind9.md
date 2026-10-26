# 04: DNS y bind9 (Guía 3)

## Conceptos

- **Espacio de nombres**: es un árbol. Cada nodo tiene una **etiqueta** (*label*) de 0 a 63
  bytes, y el nombre completo tiene 255 bytes como máximo. Un **FQDN** termina en `.` (la
  raíz): `www.itba.edu.ar.`
- **Dominio** = un subárbol. **Zona** = la parte del árbol que administra **un mismo
  servidor autoritativo**. Termina donde hay una **delegación** (registros NS hacia otros
  servidores). Ejemplo: `itba.edu.ar` delega `it.itba.edu.ar`, que es otra zona con su
  propio SOA.
- **Apex** = el nodo de arriba de la zona (`@`), donde están el SOA y los NS.
- **Servidor autoritativo**: tiene los datos de la zona (primario/master o
  secundario/slave). Responde con el flag **`aa`**.
- **Resolver recursivo** (named con recursion, 8.8.8.8, el del ISP): busca la respuesta
  completa por el cliente y la **cachea** según el TTL.
- **Stub resolver**: el de la libc o systemd-resolved (127.0.0.53). Sólo le pregunta a un
  recursivo.
- **Consulta recursiva** (cliente → resolver, flag RD): "dame la respuesta final".
  **Iterativa** (resolver → autoritativos): cada uno responde lo que sabe o un **referral**
  (los NS del siguiente nivel). Se empieza en los **root servers** (13 nombres,
  a–m.root-servers.net, con anycast) que están en `root.hints`.
- **Glue records**: si el NS de una zona está **dentro** de la misma zona
  (`ns1.foo.pdc.lab` para `foo.pdc.lab`), la zona padre también tiene que publicar su IP. Si
  no, nadie podría encontrarlo.
- **Transporte**: UDP 53, y **TCP 53** para respuestas grandes (flag TC=truncated) y para
  transferencias de zona (AXFR/IXFR). EDNS0 permite UDP de más de 512 bytes.
- **Primario → secundario**: el secundario consulta el **serial** del SOA cada `refresh`.
  Si aumentó, pide la zona (AXFR completa o IXFR incremental). El primario puede avisarle con
  NOTIFY. **Si no se sube el serial, los secundarios no se enteran del cambio.**

## Registros (RR)

Formato: `nombre  [TTL]  clase  tipo  datos` (la clase casi siempre es `IN` = Internet).

| Tipo | Datos | Para qué |
|---|---|---|
| **SOA** | mname rname serial refresh retry expire minimum | Inicio de autoridad. Exactamente 1 por zona, en el apex |
| **NS** | nombre de un servidor | Servidores autoritativos de la zona (o de una delegación) |
| **A** / **AAAA** | IPv4 / IPv6 | Nombre → dirección |
| **CNAME** | otro nombre (el canónico) | Alias. **No puede convivir con ningún otro registro del mismo nombre** ⇒ no puede ir en el apex |
| **MX** | preferencia + host | Servidores de mail entrante. **Menor número = más prioridad** |
| **PTR** | nombre | IP → nombre (en zonas inversas `in-addr.arpa` / `ip6.arpa`) |
| **TXT** | strings de hasta 255 bytes | Texto libre: SPF, DKIM, verificaciones |
| **SRV** | prioridad peso puerto host | Ubicar servicios (`_sip._tcp.dominio`) |
| CAA, DNSKEY, DS, RRSIG | — | Qué CA puede emitir certificados; DNSSEC |

- **RRset**: todos los registros con el mismo nombre, clase y tipo. Tienen que tener el
  **mismo TTL**.
- **MX y NS tienen que apuntar a un nombre con A/AAAA**, nunca a un CNAME, y tampoco a una
  IP.
- **TTL**: cuántos segundos se puede cachear (0 a 2^31−1). Se escribe `30`, `5m`, `1h`,
  `1d`, `1w`.
- **Cache negativo** (RFC 2308): cuánto se cachea un NXDOMAIN. Es el **último campo del
  SOA** (o el TTL del SOA, el menor de los dos).

### Campos del SOA

```
@ IN SOA ns1.foo.pdc.lab. sgiambelluca.itba.edu.ar. (
        2026102602 ; serial  - versión de la zona (AAAAMMDDNN). SIEMPRE incrementar al editar
        1h         ; refresh - cada cuánto el secundario consulta el serial
        15m        ; retry   - si falló el refresh, cada cuánto reintenta
        1w         ; expire  - sin hablar con el primario por este tiempo, el secundario deja de responder la zona
        30m )      ; minimum - TTL del cache NEGATIVO (NXDOMAIN)
```

- `mname` = el servidor primario. `rname` = el **mail del responsable con `.` en lugar de
  `@`** (si el usuario tiene un punto se escapa: `nombre\.apellido.dominio.`).

## Sintaxis del archivo de zona

```
$TTL 1d                    ; TTL por defecto
$ORIGIN foo.pdc.lab.       ; lo que se agrega a los nombres SIN punto final
@        IN NS    ns1                    ; @ = el origen (foo.pdc.lab.)
ns1      IN A     10.0.2.15              ; -> ns1.foo.pdc.lab.
www  30s IN A     10.0.2.15              ; TTL propio
         IN AAAA  2001:db8::15           ; nombre vacío = el mismo de la línea anterior
mail     IN MX 10 mail                   ; (el MX va en @ normalmente)
w3       IN CNAME www
ext      IN CNAME www.google.com.        ; nombre de AFUERA de la zona: punto final obligatorio
; comentario con punto y coma
```

**EL error número 1: el punto final.**

| Escrito en la zona | Queda como |
|---|---|
| `mail.foo.pdc.lab.` | `mail.foo.pdc.lab.` ✔ |
| `mail.foo.pdc.lab` (sin punto) | `mail.foo.pdc.lab.foo.pdc.lab.` ✘ |
| `www.google.com` en un CNAME (sin punto) | `www.google.com.foo.pdc.lab.` ✘ |

### Zona inversa

La red `10.0.2.0/24` se escribe con los octetos al revés y `.in-addr.arpa`:
`2.0.10.in-addr.arpa`. Cada registro es el último octeto:

```
15  IN PTR  ubuntua.foo.pdc.lab.     ; 10.0.2.15 -> ubuntua (destino con punto final, SIEMPRE)
```

La consulta se hace con `dig -x 10.0.2.15` (pregunta por `15.2.0.10.in-addr.arpa PTR`).

## bind9 (named) en Ubuntu

```
/etc/bind/named.conf               incluye a los 3 de abajo (no se toca)
/etc/bind/named.conf.options       options { directory, recursion, forwarders, listen-on, allow-query... }
/etc/bind/named.conf.local         TUS zonas
/etc/bind/named.conf.default-zones / root-hints   zona "." (hints), localhost, 127.in-addr.arpa
/etc/bind/zones/db.*               archivos de zona (cualquier carpeta que pueda leer el usuario bind)
/var/cache/bind/                   directorio de trabajo (zonas secundarias, etc.)
```

```c
// named.conf.local: comentarios con // o /* */ ; cada sentencia termina en ;
zone "foo.pdc.lab" {
    type master;                         // = primary. Secundario: type slave; masters { IP; };
    file "/etc/bind/zones/db.foo.pdc.lab";
    allow-transfer { localhost; };       // quién puede hacer AXFR
};
zone "2.0.10.in-addr.arpa" { type master; file "/etc/bind/zones/db.10.0.2"; };
```

```bash
sudo named-checkconf            # sintaxis de named.conf*
sudo named-checkconf -z         # + carga cada zona (detecta paths mal escritos, CNAME inválidos, etc.)
sudo named-checkzone foo.pdc.lab /etc/bind/zones/db.foo.pdc.lab
sudo systemctl reload named     # o: sudo rndc reload  /  sudo rndc reload foo.pdc.lab
sudo rndc flush                 # vacía el cache (para repetir experimentos)
sudo rndc dumpdb -cache         # vuelca el cache en /var/cache/bind/named_dump.db
journalctl -u named -f          # "zone foo.pdc.lab/IN: loaded serial ..."  o el error
```

### Forwarders (E54)

```c
options {
    forwarders { 8.8.8.8; 1.1.1.1; };
    forward only;     // only: sólo pregunta a los forwarders. first (default): si fallan, resuelve él
};
```

- **Sin forwarders**: named hace la resolución **iterativa** él mismo (root → TLD →
  autoritativo). Se ven muchas consultas a distintas IPs.
- **Con forwarders**: le manda una consulta **recursiva** al forwarder y se ven sólo
  consultas a 8.8.8.8 / 1.1.1.1. Se aprovecha la cache del forwarder, centraliza la
  resolución y sirve cuando el firewall sólo deja salir DNS hacia ciertos servidores.
- Con `dnssec-validation auto` también salen consultas DS/DNSKEY para validar.

## La máquina como cliente (E53)

- **Orden de resolución**: `/etc/nsswitch.conf` → `hosts: files ... dns`. Primero mira
  `/etc/hosts` y después DNS.
- **`/etc/resolv.conf`** dice `nameserver 127.0.0.53`: es **systemd-resolved**, un stub
  local. No es el DNS real ni se edita a mano. El DNS real se ve con `resolvectl status`.
- Para que use nuestro named: `/etc/systemd/resolved.conf.d/protos-bind.conf` con
  `DNS=127.0.0.1` y `Domains=~.`, y después `sudo systemctl restart systemd-resolved`.
- `dig` **no** usa nsswitch ni `/etc/hosts`: pregunta directo al servidor de resolv.conf (o
  al de `@`). `getent hosts nombre` / `ping` / `curl` sí pasan por `/etc/hosts`.

## dig

```bash
dig nombre [tipo] [@servidor] [opciones]
dig www.itba.edu.ar                 # A por defecto
dig itba.edu.ar MX +short           # sólo los datos
dig @127.0.0.1 foo.pdc.lab SOA      # a un servidor en particular
dig -x 10.0.2.15                    # inversa
dig +trace pampero.it.itba.edu.ar   # resolución iterativa desde la raíz, mostrando cada referral
dig +norecurse @a.root-servers.net ar. NS     # una consulta iterativa a mano
dig +noall +answer ...              # sólo la sección ANSWER
dig foo.pdc.lab AXFR @127.0.0.1     # transferencia de zona (TCP)
host -t MX itba.edu.ar  ;  host 10.0.2.15
nslookup -type=NS itba.edu.ar 8.8.8.8
whois itba.edu.ar                   # datos de REGISTRO (titular, fechas, NS delegados). No es DNS: es el protocolo whois, TCP 43
```

**Cómo leer la salida de dig**:

- `status:` puede ser **NOERROR** (existe), **NXDOMAIN** (el nombre no existe), **SERVFAIL**
  (el servidor falló: zona rota o DNSSEC inválido) o **REFUSED** (no te deja consultar o
  recursar).
- `flags:` son **qr** (es una respuesta), **aa** (autoritativa), **rd** (pediste
  recursión), **ra** (el servidor ofrece recursión), **tc** (truncada) y **ad** (validada
  con DNSSEC).
- Secciones: **QUESTION**, **ANSWER**, **AUTHORITY** (NS o SOA; con NXDOMAIN o
  NOERROR/NODATA viene el SOA), **ADDITIONAL** (glue, OPT de EDNS).
- El número después del nombre es el **TTL que queda**: en un recursivo va bajando con cada
  consulta.

## Errores comunes

| Síntoma | Causa |
|---|---|
| `loading from master file ... failed: file not found` | el path del `file` está mal (pasó en clase: `/etc/bind/bind/zones`) |
| `CNAME and other data` | CNAME junto con otro registro del mismo nombre, o en el apex |
| aparece `x.foo.pdc.lab.foo.pdc.lab` | falta el punto final |
| cambié la zona y no cambia nada | no se recargó, **no se subió el serial** (para los secundarios), o hay **cache** (TTL): `rndc flush` |
| `dig` responde pero sin `aa` | no lo respondió tu zona: vino por recursión desde Internet (la zona no cargó) |
| `REFUSED` | `allow-query` / `allow-recursion` no incluyen al cliente |
| `SERVFAIL` en tu zona | la zona no cargó: mirar `journalctl -u named` |
| un nombre "hermano" no resuelve | `foo-alt.pdc.lab` no pertenece a la zona `foo.pdc.lab` (sólo los que terminan en .foo.pdc.lab) |
| `permission denied` al leer la zona | el usuario `bind` no puede leer el archivo (permisos 644, carpeta con x) |
| E49 "borrar /etc/named.caching-server.conf" | esos archivos son de Fedora/RHEL. En Ubuntu no existen |

---

## En parciales anteriores

Las resoluciones completas, paso a paso, están en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 1 es otra zona rota (`sucursal.foo`). Sólo un error impide cargarla; el resto (`@` en el mail, MNAME que no es NS, serial y tiempos) carga igual y hay que encontrarlo a mano. `simulacro.sh` la monta en bind y la corrige.

### 2025 2C, Ej III: "la zona it.itba.edu.ar no resuelve nada": encontrar los errores

Original (en `~/Protos/ejercicios/parciales/2025-2c-ej3-zona-ORIGINAL-con-errores.db`):

```
$TTL 604800
@ IN SOA ns1.it.itba.edu.ar. admin@it.itba.edu.ar. ( 2025060500 604800 86400 2419200 604800 )
@       IN NS ns1.it.itba.edu.ar.
@       IN MX 10 mail
ns1.it.itba.edu.ar      IN A 192.168.70.1        <- sin punto final
pampero                 IN A 192.168.70.10
www     IN A pampero                              <- A con un nombre
correo  IN CNAME pampero
```

| Error | Qué dice named-checkzone | Arreglo |
|---|---|---|
| `www IN A pampero` | `bad dotted quad` (la zona no carga) | `www IN CNAME pampero` |
| `ns1.it.itba.edu.ar` sin punto final | `NS 'ns1.it.itba.edu.ar' has no address records` (**la zona no carga**: por eso no resolvía nada) | `ns1 IN A ...` |
| MX a `mail`, que no existe | `MX 'mail...' has no address records` (es un aviso: carga igual) | agregar `mail IN A ...` (el MX nunca puede apuntar a un CNAME) |
| `admin@...` en el SOA | **nada** (BIND lo acepta) | `admin.it.itba.edu.ar.` |
| serial sin cambiar | — | subirlo: los secundarios comparan el serial |
| refresh y negative TTL de 1 semana, `$TTL` de 1 semana | — | bajarlos (1h / 5m) para que los cambios se vean rápido |

**Método para el parcial**: corré `named-checkzone ZONA ARCHIVO` en un bucle, corrigiendo
de a un error, y después revisá **la lógica** a mano (los mails con punto, los MX y NS que
apuntan a nombres con A, el serial y los tiempos del SOA).

### 2026 1C, Ej 1: armar la zona foo.example.org con valores dados

Pedía TTLs distintos por registro, MX con prioridades, un CNAME, SPF y un mail de
responsable con un punto en el usuario.

```
$TTL 1m
@ IN SOA ns.foo.example.org. example\.admin.foo.com.ar. ( 2026052801 7d 1d 10d 1m )
@        IN NS ns
ns       IN A  1.2.3.4                     ; glue
@    7d  IN MX 10 mx1.protos.foo.          ; otra zona -> punto final
@    7d  IN MX 5  mx2.protos.foo.          ; 5 < 10 -> mx2 tiene más prioridad
@    1h  IN A  123.123.123.123
www  7d  IN CNAME @
@        IN TXT "v=spf1 ip4:1.2.3.4 -all"
```

`example\.admin` = `example.admin@foo.com.ar`: el **punto del usuario se escapa** con `\.`.
Archivo en `~/Protos/ejercicios/parciales/2026-1c-ej1-foo.example.org.db`.

---

## Más práctica y diagnóstico (material del repo Protos-ITBA)

**Leer el resultado de `dig` contra tu server para saber qué falló**:

| Respuesta | Qué significa |
|---|---|
| `SERVFAIL`, sin `aa`, `AUTHORITY: 0` | **la zona no cargó** (error de sintaxis, path mal escrito, falta el NS): mirar `journalctl -u named` |
| `NXDOMAIN` **con** `aa` | la zona cargó bien, pero **ese nombre no existe** (¿falta el punto final? ¿está mal escrito?) |
| `NOERROR` con `aa` y ANSWER 0 | el nombre existe, pero **no tiene ese tipo** de registro (NODATA) |
| respuesta **sin** `aa` para tu dominio | no la respondió tu zona: vino por recursión (pasó en clase con pepito.com) |

**Reglas del SOA y de la zona**:

- **`expire > refresh + retry`**: si no, un secundario daría la zona por muerta antes de
  terminar de reintentar.
- El primer campo del SOA (MNAME) debería ser **uno de los NS** de la zona.
- Tiene que haber **al menos un NS**, y **todo nombre usado en NS o MX tiene que tener un A o
  AAAA** (Ej 10 de práctica: el repo se olvidó los A de mail20, mail30 y mail40).

**Split-horizon**: el mismo nombre resuelve distinto según quién pregunta. Desde adentro del
ITBA, `pampero.it.itba.edu.ar` da la IP privada (DNS interno). Desde afuera da la pública, o
nada. Por eso un DNS externo (8.8.8.8) estando en el ITBA puede llevarte a una IP a la que el
firewall no te deja entrar.

**Cadenas de CNAME** (Ej 11): se usan para delegar el sitio a un proveedor (CDN, nube) que
maneja sus propias IPs, con balanceo y GeoDNS. Para seguirlas: `dig +short nombre`, que
muestra cada eslabón.

Resueltos: Ej 10 (zona carlitos.com.ar) y Ej 11 en `15-ejercicios-extra.md`.

---

## Del integrador (CTF Protolab, `~/Protos/recu/`)

Pregunta 2: "el router que expone el HTTP también expone un DNS. ¿Cuál es el SERIAL de
www.google.com según ese DNS?"

```
$ dig @192.168.123.200 www.google.com SOA      # "según ESE DNS" = @IP (su google.com es de mentira)
www.google.com.  CNAME  google.com.
google.com.      IN SOA ns.google.com. admin.google.com. 74757169 69 420 666 69
#                                                        serial   refresh retry expire minimum
```

- **El SOA está en el apex** de la zona, no en cada nombre. Como `www` es un CNAME a
  `google.com`, la respuesta trae el CNAME y el SOA del apex. Probado con nuestra zona:
  `dig +norec @127.0.0.1 alt.foo.pdc.lab SOA` (`alt` es `CNAME @`) da `ANSWER: 2`, el CNAME y
  el SOA de `foo.pdc.lab`.
- Si el nombre **no** es CNAME ni apex (`dig +norec @127.0.0.1 ubuntua.foo.pdc.lab SOA`):
  `ANSWER: 0` y el SOA aparece en la sección **AUTHORITY** (respuesta "NODATA": el nombre
  existe pero no tiene SOA). El serial se lee igual, de ahí.
- `;; WARNING: recursion requested but not available`: ese server no hace recursión para vos
  (es sólo autoritativo, o `allow-recursion` no te incluye). Sólo contesta lo de sus zonas.

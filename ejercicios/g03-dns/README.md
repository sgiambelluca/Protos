# Guía 3: DNS

Teoría (registros, SOA, delegación, recursión, errores): `../../apuntes/04-dns-y-bind9.md`

## Archivos configurados

| Archivo | Ejercicio | Qué tiene |
|---|---|---|
| `/etc/bind/named.conf.options` | E50, E54 | recursión para localhost/localnets, forwarders **comentados** |
| `/etc/bind/named.conf.local` | E50 | zonas pepito.com y cachito.com (clase, path corregido), foo.pdc.lab y 2.0.10.in-addr.arpa |
| `/etc/bind/zones/db.foo.pdc.lab` | E50 | zona directa: SOA, NS, MX, A, AAAA, CNAME, TXT, con distintos TTL |
| `/etc/bind/zones/db.10.0.2` | E50 | zona inversa: registros PTR de 10.0.2.x |
| `/etc/bind/zones/db.pepito.com.local` | (clase) | sin cambios |
| `/etc/bind/zones/db.cachito.com.local` | (clase) | corregido el `CNAME` en el apex |
| `/etc/systemd/resolved.conf.d/protos-bind.conf` | E53 | el sistema usa 127.0.0.1 (nuestro named) como DNS |
| `/etc/nginx/sites-available/foo.pdc.lab` | E47 | proxy reverso foo.pdc.lab → protos.foo |
| `/etc/nginx/sites-available/alt.foo.pdc.lab` | E48 | redirección 302 → protos.foo |

### Qué hay en la zona foo.pdc.lab

| Nombre | Tipo | Valor | TTL |
|---|---|---|---|
| foo.pdc.lab (@) | SOA / NS / A / MX / TXT | ns1 / 10.0.2.15 / 10 mail, 20 mail2 / SPF | 1d (TXT 1h) |
| ns1, ubuntua, mail | A | 10.0.2.15 (esta VM) | 1d |
| mail2 | A | 10.0.2.16 | **5m** |
| gateway | A | 10.0.2.2 (router NAT VirtualBox) | **1h** |
| dns-nat | A | 10.0.2.3 | 1h |
| www | A | 10.0.2.15 | **30s** |
| ubuntua | AAAA | 2001:db8::15 | 1d |
| dns, vm, correo, correo2, router, resolver, w3, alt | CNAME | un alias por host | 1d |

## Comandos: clientes DNS (E42 a E46)

```bash
# E42: autoridad de cada nombre
dig NS google.com
dig NS itba.edu.ar
dig NS pampero.it.itba.edu.ar      # ANSWER 0 + SOA en AUTHORITY: no es una zona, es un host dentro de it.itba.edu.ar
dig SOA it.itba.edu.ar             # el SOA dice quién es el primario de la zona
#   ver los paquetes:  sudo tcpdump -ni any port 53     (o Wireshark, filtro: dns)

# E43: servidores de mail entrante
dig MX google.com +short
dig MX itba.edu.ar +short          # menor preferencia = mayor prioridad
dig MX it.itba.edu.ar +short

# E44/E45: todos los servidores desde la raíz
dig +trace pampero.it.itba.edu.ar
#   . (root) -> ar. -> edu.ar. -> itba.edu.ar. -> it.itba.edu.ar. -> respuesta
# A mano (lo mismo que hace +trace): preguntar a cada uno SIN recursión
dig NS . +short                                   # root servers
dig @a.root-servers.net ar. NS +norecurse         # referral a los de .ar
dig @<un NS de ar.> itba.edu.ar NS +norecurse     # ...y así bajando

# E46
whois itba.edu.ar
whois -H google.com        # -H: sin los textos legales
```

## Comandos: DNS + HTTP (E47 y E48)

```bash
getent hosts foo.pdc.lab              # 10.0.2.15: lo resuelve NUESTRO bind (no está en /etc/hosts)
curl -v http://foo.pdc.lab/           # nginx hace de proxy a protos.foo (la URL no cambia)
curl -i http://alt.foo.pdc.lab/       # 302 + Location: http://protos.foo/ (la URL cambia)
```

- **Por qué no alcanza con /etc/hosts**: si se pone `35.211.115.38 foo.pdc.lab` en
  /etc/hosts, el browser se conecta a la IP correcta, pero manda `Host: foo.pdc.lab`. El
  servidor de protos.foo no tiene un virtual host con ese nombre. Además sólo funciona en
  esa máquina, así que no es una solución estable.
- **Hoy protos.foo está caído** (connection refused) y por eso E47 devuelve **502 Bad
  Gateway**. Lo de nginx está bien: en `/var/log/nginx/error.log` se ve `connect() failed
  (111: Connection refused) while connecting to upstream`. Para verlo andar, cambiá en
  `/etc/nginx/sites-available/foo.pdc.lab` la línea `set $upstream_protos protos.foo;` por
  `example.com`, recargá y probá con curl. Ya se probó así y funciona: aparece "Example
  Domain" bajo `http://foo.pdc.lab/`.

## Comandos: nuestro servidor (E50 a E54)

```bash
# chequear ANTES de recargar (lo que más rompe es un error de sintaxis o un path mal escrito)
sudo named-checkconf                     # sintaxis de named.conf*
sudo named-checkconf -z                  # además carga todas las zonas
sudo named-checkzone foo.pdc.lab /etc/bind/zones/db.foo.pdc.lab
sudo named-checkzone 2.0.10.in-addr.arpa /etc/bind/zones/db.10.0.2

# E51: reiniciar y mirar el log
sudo journalctl -u named -f              # en otra terminal (también sirve: tail -f /var/log/syslog)
sudo systemctl restart named             # "zone foo.pdc.lab/IN: loaded serial 2026102602"
sudo rndc reload foo.pdc.lab             # recarga una sola zona, sin reiniciar
sudo rndc status

# E52: probar con las 3 herramientas
dig @127.0.0.1 foo.pdc.lab SOA
dig @127.0.0.1 foo.pdc.lab MX +short
dig @127.0.0.1 www.foo.pdc.lab           # en ANSWER se ve el TTL 30
dig @127.0.0.1 w3.foo.pdc.lab            # CNAME -> www -> A
dig @127.0.0.1 -x 10.0.2.15              # inversa: PTR
dig @127.0.0.1 foo.pdc.lab AXFR          # transferencia de zona completa (permitida sólo desde localhost)
host -a foo.pdc.lab 127.0.0.1
host 10.0.2.15 127.0.0.1
nslookup -type=MX foo.pdc.lab 127.0.0.1

# E53: ¿el host usa nuestro DNS?
cat /etc/resolv.conf          # nameserver 127.0.0.53 = systemd-resolved (stub local), NO es el DNS real
resolvectl status             # Global: DNS Servers: 127.0.0.1  <- nuestro named
resolvectl query foo.pdc.lab
dig foo.pdc.lab               # sin @: va a 127.0.0.53 -> resolved -> named

# E54: forwarders
sudo rndc flush                              # vaciar el cache para que se note
sudo tcpdump -ni any port 53 and not host 127.0.0.1 and not host 127.0.0.53
dig @127.0.0.1 wikipedia.org                 # SIN forwarders: consultas a root, .org, wikipedia (iterativo)
#   descomentar forwarders en /etc/bind/named.conf.options
sudo named-checkconf && sudo systemctl reload named && sudo rndc flush
dig @127.0.0.1 wikipedia.org                 # CON forwarders: la consulta va a 8.8.8.8 / 1.1.1.1 y vuelve la respuesta final
#   (se probó el 26/10: además salen consultas DS/DNSKEY a los forwarders, porque named valida DNSSEC)
#   después volver a comentarlas y recargar
```

## Errores que había en las zonas de clase

1. **Path con `bind` dos veces**: `file "/etc/bind/bind/zones/db.pepito.com.local";`. named
   arrancaba igual, pero en el log decía `loading from master file ... failed: file not
   found` y las zonas no se cargaban. Lo engañoso: **pepito.com existe de verdad en
   Internet**, así que `dig MX pepito.com @127.0.0.1` igual respondía. Pero por recursión
   devolvía el MX real (`0 mail.pepito.com.`) en vez del de tu zona (`1 smtp`, `10 smtp2`).
   Para darse cuenta: en la respuesta de una zona propia tiene que aparecer el flag
   **`aa`** (authoritative answer). Hay que mirar siempre el log o `named-checkconf -z`.
2. **CNAME en el apex** (`@ IN CNAME ipv6` en cachito.com): `CNAME and other data`, y
   named rechaza la zona entera.
3. **Error mío al armar E48**: había puesto el nombre `foo-alt.pdc.lab`, pero ese nombre
   **no pertenece a la zona foo.pdc.lab** (es hermano, cuelga de pdc.lab). Al escribir
   `foo-alt` en la zona se creaba `foo-alt.foo.pdc.lab`. Se cambió a `alt.foo.pdc.lab`.

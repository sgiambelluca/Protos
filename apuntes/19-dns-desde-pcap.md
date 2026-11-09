# 19: Reconstruir una zona DNS desde una captura (Parcial 2026 2C, Ej 4)

**Enunciado** (reconstruido): *se borró la zona `protos.parcial`. Hay una snapshot del tráfico
DNS del servidor (`~/pcapej4`). Reconstruí la zona a partir de la captura, cargala en bind y
agregale un TXT pidiendo que le sumen más seguridad, con un mensaje divertido.*

**Qué pasó en el parcial**: en `/etc/bind/zones/ej4` quedó la zona `cachito.com` de la clase,
copiada **sin cambios** (`named-checkzone protos.parcial` la rechaza entera: "out-of-zone
data"). Usar una zona de clase como molde está perfecto. Lo que faltó es saber **de dónde
salen los datos**, y eso es todo este apunte. (El `.ej4.swp` de al lado es el lock de nano:
quedó porque nano no se cerró bien. No molesta.)

---

## La idea en una frase

La captura son **5 `dig` contra el bind que después se borró**, con sus respuestas. **Cada
registro que aparece en una respuesta es una línea del archivo de zona.** No hay que deducir
nada raro: hay que copiar con cuidado.

| En Wireshark (cada registro) | En el archivo de zona |
|---|---|
| `Name: meme.protos.parcial` | el nombre (columna 1): `meme` |
| `Time to live: 864000` | el TTL (columna 2, si es distinto del `$TTL`) |
| `Class: IN` | `IN` |
| `Type: TXT` | el tipo |
| `TXT: https://xkcd.com/927/` (o `Address`, `Name Server`, `Preference` + `Mail Exchange`...) | el dato |

## Las 3 secciones de una respuesta DNS (acá está todo el truco)

Al expandir `Domain Name System (response)` en Wireshark aparecen hasta 3 secciones con registros:

| Sección (Wireshark / dig) | Qué trae | Qué sacás de ahí en este ejercicio |
|---|---|---|
| **Answers** / `ANSWER` | lo que se preguntó | NS, MX, los dos TXT |
| **Authoritative nameservers** / `AUTHORITY` | en una respuesta **NXDOMAIN** (el nombre no existe), el **SOA de la zona** | **el SOA entero**. Por eso en la captura hay un `dig fake.protos.parcial`: nadie pidió el SOA, pero viene "de regalo" en el error |
| **Additional records** / `ADDITIONAL` | bind agrega **solo** las A/AAAA de los nombres que aparecen en la respuesta (los NS, los MX), para ahorrarte otra consulta | las A de `ns1`, `ns2`, `mail` y `backup` |

Y un registro **que NO es de la zona**: `<Root>: type OPT`. Es EDNS (el tamaño UDP, la cookie
de dig). Aparece en todos los paquetes: **ignoralo**.

---

## Paso 1: abrir la captura

```bash
wireshark ~/pcapej4 &        # la interfaz gráfica la abre sin problema
```

1. Filtro: **`dns.flags.response == 1`** → quedan las 5 respuestas (frames 2, 4, 6, 8 y 10).
   Las consultas (frames impares) no tienen datos: sólo dicen qué se preguntó.
2. En cada respuesta: panel del medio → `Domain Name System (response)` → desplegá
   **Answers**, **Authoritative nameservers** y **Additional records**.
3. **Desplegá cada registro** (el triangulito): la línea resumen
   (`protos.parcial: type NS, class IN, ns ns1.protos.parcial`) **no muestra el TTL**. El
   TTL está adentro, en `Time to live`. Ahí está la trampa de este ejercicio.
4. Mirá también en `Flags` el bit **`Authoritative: Server is an authority for domain`**:
   confirma que quien contestó era el dueño de la zona (no un caché), o sea que los datos
   son los originales.

**Lo mismo por consola** (ojo: en esta VM `tshark -r ~/pcapej4` da *"You don't have
permission"*. No es un tema de permisos de archivo: el perfil de **AppArmor** de tshark no lo
deja leer nada de tu home. Pasáselo por stdin con `<`, o copiá el archivo a `/tmp`):

```bash
tshark -r - < ~/pcapej4                                        # la lista, como en Wireshark
tshark -r - -Y 'dns.flags.response == 1' -O dns < ~/pcapej4     # el detalle de DNS de cada respuesta
```

Para ver sólo los registros, sin el ruido de flags y cookies:

```bash
tshark -r - -Y 'dns.flags.response == 1' -O dns < ~/pcapej4 | awk '
  /^Frame/ {print "\n" $1, $2}
  /^    (Answers|Authoritative nameservers|Additional records)$/ {s=1; print; next}
  /^    [^ ]/ {s=0}
  s && /: type / && !/type OPT/ {print}
  s && /Time to live|TXT:|mailbox:|Serial|Refresh|Retry|Expire|Minimum/ {print}'
```

## Paso 2: anotar qué dice cada respuesta

| Frame | Consulta | Sección | Registro | TTL |
|---|---|---|---|---|
| 2 | `dig protos.parcial NS` | Answers | `protos.parcial NS ns1.protos.parcial` | 86400 |
| | | Answers | `protos.parcial NS ns2.protos.parcial` | 86400 |
| | | Additional | `ns1.protos.parcial A 192.0.2.10` | 86400 |
| | | Additional | `ns2.protos.parcial A 192.0.2.11` | 86400 |
| 4 | `dig protos.parcial MX` | Answers | `protos.parcial MX 20 backup.protos.parcial` | 86400 |
| | | Answers | `protos.parcial MX 10 mail.protos.parcial` | 86400 |
| | | Additional | `mail.protos.parcial A 192.0.2.20` | 86400 |
| | | Additional | `backup.protos.parcial A 192.0.2.21` | 86400 |
| 6 | `dig protos.parcial TXT` | Answers | `protos.parcial TXT "v=spf1 ip4:225.0.0.3 ~all"` | 86400 |
| 8 | `dig meme.protos.parcial TXT` | Answers | `meme.protos.parcial TXT "https://xkcd.com/927/"` | **864000** |
| 10 | `dig fake.protos.parcial A` → **NXDOMAIN** | Authoritative | `protos.parcial SOA ns1.protos.parcial admin.itba.edu.ar 2026102701 3600 1800 1209600 3600` | 3600 |

Casi todo vino con TTL **86400** (1 día) → ese es el `$TTL`. Los que no, van con su TTL en la línea.

## Paso 3: escribir la zona

Está en `~/Protos/ejercicios/parciales/2026-2c-ej4-protos.parcial.db`, con un comentario en
cada línea que dice de qué frame sale:

```dns
$TTL 86400
$ORIGIN protos.parcial.

@       IN  SOA ns1.protos.parcial. admin.itba.edu.ar. (
            2026102702  ; serial: el de la captura (2026102701) + 1, porque agregamos el TXT
            3600        ; refresh
            1800        ; retry
            1209600     ; expire
            3600 )      ; minimum

@       IN  NS  ns1.protos.parcial.
@       IN  NS  ns2.protos.parcial.
ns1     IN  A   192.0.2.10
ns2     IN  A   192.0.2.11

@       IN  MX  10 mail.protos.parcial.
@       IN  MX  20 backup.protos.parcial.
mail    IN  A   192.0.2.20
backup  IN  A   192.0.2.21

@       IN  TXT "v=spf1 ip4:225.0.0.3 ~all"
meme    864000  IN  TXT "https://xkcd.com/927/"

seguridad   IN  TXT "Che, sumen DNSSEC y pasen el SPF a -all. No es otro estandar nuevo como el de xkcd 927, es el que ya existe"
```

### Las trampas, una por una

1. **El SOA no se pidió nunca.** Sale del NXDOMAIN del frame 10 (sección *Authoritative
   nameservers*). Si no sabés esto, parece que falta información.
2. **`meme` tiene TTL 864000 (10 días), no 86400.** Un cero más. Si no lo ponés en la línea,
   toma el `$TTL` y tu bind contesta distinto que la captura. Sin desplegar el registro en
   Wireshark no lo ves.
3. **El SOA vino con TTL 3600, pero eso no es su TTL.** En una respuesta negativa, bind manda
   el SOA con TTL = **mín(TTL del SOA, minimum)** = mín(86400, 3600) = 3600. No hay que
   poner `$TTL 3600` ni un TTL especial en el SOA: con `$TTL 86400` y minimum 3600 sale igual.
4. **El mail del responsable.** Wireshark muestra `admin.itba.edu.ar` y entre corchetes
   `[admin@itba.edu.ar]`. En la zona va **con punto en vez de @ y con punto final**:
   `admin.itba.edu.ar.`. Sin el punto final queda `admin.itba.edu.ar.protos.parcial.`.
5. **Puntos finales en general.** `ns1.protos.parcial.` (absoluto, con punto) o `ns1` (relativo,
   sin punto). **Nunca `ns1.protos.parcial` sin punto**: bind le pega el origen y queda
   `ns1.protos.parcial.protos.parcial` (y como ese nombre no tiene A, la zona no carga).
6. **El orden de los MX no importa.** En la captura vino primero el de 20; bind los devuelve
   en cualquier orden. Lo que importa es la **preferencia** (menor = primero).
7. **`OPT <Root>` no es un registro.** No lo copies.
8. **Sólo se puede reconstruir lo que alguien consultó.** Si la zona tenía un `www`, la
   captura no lo muestra y no hay forma de saberlo. No inventes registros.

## Paso 4: declararla y cargarla

```bash
sudo nano /etc/bind/zones/db.protos.parcial              # lo del paso 3
sudo nano /etc/bind/named.conf.local                     # agregar al final:
```

```
zone "protos.parcial" {
	type master;
	file "/etc/bind/zones/db.protos.parcial";
};
```

```bash
named-checkzone protos.parcial /etc/bind/zones/db.protos.parcial   # tiene que decir OK
sudo named-checkconf -z                                            # todo el named.conf
sudo systemctl reload named
dig @127.0.0.1 protos.parcial SOA +short                           # ¿sirve el serial NUEVO?
```

**Ojo con el último paso.** Si recargás y la zona nueva tiene errores, bind **sigue sirviendo
la versión anterior** que tenía en memoria (o nada, si es la primera vez). Los `dig` te pueden
dar "bien" con la zona vieja. Por eso: `named-checkzone` **antes** de recargar, y después
`dig ... SOA +short` para ver que el serial sea el que escribiste. Si no carga:
`journalctl -u named -n 30`.

## Paso 5: comprobar que contesta igual que la captura

Repetí las mismas 5 consultas y compará con Wireshark, registro por registro y TTL incluido:

```bash
dig @127.0.0.1 protos.parcial NS
dig @127.0.0.1 protos.parcial MX
dig @127.0.0.1 protos.parcial TXT
dig @127.0.0.1 meme.protos.parcial TXT          # el TTL tiene que ser 864000
dig @127.0.0.1 fake.protos.parcial A            # NXDOMAIN, y el SOA en AUTHORITY con TTL 3600
```

En `dig` las secciones se llaman `ANSWER SECTION`, `AUTHORITY SECTION` y `ADDITIONAL SECTION`:
son las mismas tres que en Wireshark.

O que lo compare un script (en la VM):

```bash
~/Protos/scripts/practicar-dns-pcap.sh verificar          # OK / FALLA por cada registro de la captura
```

Toma cada consulta de la captura, se la vuelve a hacer a tu bind y compara nombre, tipo, dato,
TTL y sección. También avisa si bind está sirviendo una versión vieja, si no subiste el serial
y si falta el TXT nuevo. `limpiar` saca tu zona (la guarda en `~/intentos-dns/`) para
hacerlo de cero, y `solucion` carga la de este apunte.

## Paso 6: el TXT "que le sumen seguridad"

```dns
seguridad   IN  TXT "Che, sumen DNSSEC y pasen el SPF a -all. No es otro estandar nuevo como el de xkcd 927, es el que ya existe"
```

- **Dónde**: si el enunciado no dice el nombre, en uno propio (`seguridad`). Si dice "en el
  dominio", va en `@`: puede convivir con el TXT del SPF (un nombre puede tener varios TXT).
- **Comillas** siempre. Cada string tiene hasta 255 caracteres. Si es más largo, partilo:
  `"primera parte" "segunda parte"`.
- **Acentos**: bind los acepta, pero `dig` los muestra como `\195\161`. No es un error, pero
  sin acentos se lee mejor.
- **Subí el serial** (2026102701 → 2026102702): cambiaste la zona. Si no lo subís, un
  secundario nunca se entera del cambio.
- Recargá y probá: `dig @127.0.0.1 seguridad.protos.parcial TXT +short`.

**Por qué "más seguridad" tiene sentido con esta zona** (sirve para el chiste): el SPF termina
en `~all` (*softfail*: "si no es de esta IP, sospechá pero aceptalo"; `-all` es rechazarlo),
la única IP autorizada, `225.0.0.3`, es **multicast** (224.0.0.0/4) y nunca puede mandar un
mail, y no hay DNSSEC. Y el meme, xkcd 927, es el de "hay 14 estándares que compiten → hagamos
uno que los unifique → hay 15 estándares que compiten".

---

## Practicar a ciegas: la captura de repaso

Esta ya la viste resuelta, así que hay otra con una zona distinta y **4 trampas nuevas**:
`~/Protos/ejercicios/dns-pcap/repaso.pcapng` (12 paquetes, 6 consultas).

**Enunciado**: *se borró la zona `repaso.parcial`. Reconstruila desde la captura, cargala en
bind y agregale un TXT en `nota.repaso.parcial` con un mensaje sobre seguridad.*

```bash
wireshark ~/Protos/ejercicios/dns-pcap/repaso.pcapng &
#   ... armás /etc/bind/zones/db.repaso.parcial y su zone {} en named.conf.local ...
~/Protos/scripts/practicar-dns-pcap.sh verificar ~/Protos/ejercicios/dns-pcap/repaso.pcapng
~/Protos/scripts/practicar-dns-pcap.sh limpiar   ~/Protos/ejercicios/dns-pcap/repaso.pcapng   # para repetirlo
```

La solución está en `ejercicios/dns-pcap/repaso.parcial-SOLUCION.db`. No la abras antes.
`named-checkzone` puede tirar *"getaddrinfo(...) failed"* para un nombre de afuera de la
zona: es un aviso, no un error (dice `OK` igual).

<details>
<summary>Las 4 trampas (leer después de intentarlo)</summary>

1. **Un NS y un MX apuntan afuera de la zona** (`ns.otro.example.`, `mx2.otro.example.`): van
   con punto final, y en *Additional* no viene nada para ellos (bind no tiene sus A).
2. **`www` es un CNAME.** `dig www A` trae en *Answers* el CNAME `www → web` **y** las A de
   `web`. El CNAME va en `www`; las A van en `web`, no en `www`.
3. **Las A de `web` vinieron con TTL 300**, pero su AAAA con 3600 (el default). El TTL va en
   cada línea, no "por nombre".
4. **El SOA vino con TTL 300 y el resto con 3600.** No es que el `$TTL` sea 300: es
   mín(3600, minimum 300). Con `$TTL 3600` y minimum 300 sale igual que la captura.

Además, `mx1` vino con **A y AAAA** en *Additional*: las dos van a la zona.

</details>

## Checklist para este tipo de ejercicio

- [ ] Filtro `dns.flags.response == 1` y recorrí **todas** las respuestas.
- [ ] En cada una, las **3 secciones** (Answers, Authoritative, Additional) y cada registro **desplegado** (TTL).
- [ ] SOA: del NXDOMAIN (o de un `dig SOA`, si hay). Mail con punto, no `@`.
- [ ] `$TTL` = el TTL que más se repite; los demás, en su línea.
- [ ] Nombres absolutos **con punto final**; relativos sin.
- [ ] Ignoré `OPT`. No inventé registros que nadie consultó.
- [ ] Lo nuevo (el TXT) + **serial + 1**.
- [ ] `named-checkzone` → `named-checkconf -z` → `reload` → `dig SOA +short` (¿serial nuevo?).
- [ ] Repetí cada consulta de la captura con `dig @127.0.0.1` y comparé.

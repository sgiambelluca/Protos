#!/usr/bin/env bash
# ============================================================
# practicar-dns-pcap.sh  -  "se borró la zona, reconstruila desde la captura"
#                           (Parcial 2026 2C, Ej 4; explicado en apuntes/19-dns-desde-pcap.md)
#
# Uso:  ~/Protos/scripts/practicar-dns-pcap.sh verificar [captura]
#       ~/Protos/scripts/practicar-dns-pcap.sh solucion  [captura]
#       ~/Protos/scripts/practicar-dns-pcap.sh limpiar   [captura]
#
#   verificar  toma CADA consulta DNS que hay en la captura, se la vuelve a hacer a TU bind
#              (127.0.0.1) con dig y compara registro por registro: nombre, tipo, dato y TTL,
#              y en qué sección vino (ANSWER / AUTHORITY / ADDITIONAL). Después mira que hayas
#              subido el serial y agregado un TXT que no estaba en la captura.
#   solucion   carga la resolución del apunte 19 (sólo existe para ~/pcapej4 y para
#              ejercicios/dns-pcap/repaso.pcapng).
#   limpiar    saca la zona de /etc/bind/named.conf.local y MUEVE su archivo a ~/intentos-dns/
#              (no borra nada tuyo), para hacerlo de cero otra vez.
#
# La captura por defecto es ~/pcapej4 (la del parcial). La zona sale sola de la captura.
# Ojo: tshark no puede abrir archivos de tu home (AppArmor), por eso acá se le pasa por stdin.
# ============================================================
set -uo pipefail

PCAP="${2:-$HOME/pcapej4}"
CONF=/etc/bind/named.conf.local
PROTOS="$HOME/Protos"

paso() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

[ -r "$PCAP" ] || { echo "No encuentro la captura $PCAP"; exit 1; }

# La zona: el dueño del SOA que haya en la captura, o el nombre más corto consultado.
zona_de_la_captura() {
    local z
    z=$(tshark -r - -Y 'dns.resp.type == 6' -T fields -e dns.resp.name < "$PCAP" 2>/dev/null | head -1 | cut -d, -f1)
    [ -n "$z" ] || z=$(tshark -r - -Y 'dns.flags.response == 0' -T fields -e dns.qry.name < "$PCAP" 2>/dev/null \
                       | awk '{print length, $0}' | sort -n | head -1 | cut -d' ' -f2)
    echo "${z%.}"
}

# ------------------------------------------------------------
# El corrector propiamente dicho (Python: parsear la salida de tshark y de dig en bash es un
# infierno). Lee la captura con tshark -T json y le pregunta lo mismo al bind con dig.
read -r -d '' CORRECTOR <<'PY'
import ipaddress, json, subprocess, sys

pcap, server, zona = sys.argv[1], sys.argv[2], sys.argv[3]
TIPOS = {1: 'A', 2: 'NS', 5: 'CNAME', 6: 'SOA', 12: 'PTR', 15: 'MX', 16: 'TXT', 28: 'AAAA', 33: 'SRV'}
SECC = {'Answers': 'ANSWER', 'Authoritative nameservers': 'AUTHORITY', 'Additional records': 'ADDITIONAL'}
RCODE = {0: 'NOERROR', 1: 'FORMERR', 2: 'SERVFAIL', 3: 'NXDOMAIN', 4: 'NOTIMP', 5: 'REFUSED'}
V, R, N, B = '\033[32m', '\033[31m', '\033[0m', '\033[1m'
ok = mal = 0

def chk(bien, texto):
    global ok, mal
    if bien: ok += 1; print(f'  {V}OK   {N} {texto}')
    else:    mal += 1; print(f'  {R}FALLA{N} {texto}')

# tshark -T json repite claves (dos MX iguales de nombre, varios "dns.txt"): pares, no dict.
def g(p, k, d=None):
    for a, b in p:
        if a == k: return b
    return d
def gs(p, k): return [b for a, b in p if a == k]
def nom(n): n = n.lower().rstrip('.'); return n or '.'
def ip6(x): return ipaddress.ip_address(x).compressed

def rdata_pcap(t, rr, resumen):
    if t == 'A':     return g(rr, 'dns.a')
    if t == 'AAAA':  return ip6(g(rr, 'dns.aaaa'))
    if t == 'NS':    return nom(g(rr, 'dns.ns'))
    if t == 'CNAME': return nom(g(rr, 'dns.cname'))
    if t == 'PTR':   return nom(g(rr, 'dns.ptr.domain_name'))
    if t == 'MX':    return f"{g(rr, 'dns.mx.preference')} {nom(g(rr, 'dns.mx.mail_exchange'))}"
    if t == 'TXT':   return ' '.join(f'"{s}"' for s in gs(rr, 'dns.txt'))
    if t == 'SRV':   return ' '.join([g(rr, 'dns.srv.priority'), g(rr, 'dns.srv.weight'),
                                      g(rr, 'dns.srv.port'), nom(g(rr, 'dns.srv.target'))])
    if t == 'SOA':   return ' '.join([nom(g(rr, 'dns.soa.mname')), nom(g(rr, 'dns.soa.rname'))] +
                                     [g(rr, k) for k in ('dns.soa.serial_number', 'dns.soa.refresh_interval',
                                      'dns.soa.retry_interval', 'dns.soa.expire_limit', 'dns.soa.minimum_ttl')])
    return resumen

def rdata_dig(t, resto):
    resto = resto.strip()
    if t in ('NS', 'CNAME', 'PTR'): return nom(resto)
    if t == 'AAAA': return ip6(resto)
    if t == 'MX':   p, h = resto.split(); return f'{p} {nom(h)}'
    if t == 'SRV':  x = resto.split(); return ' '.join(x[:3] + [nom(x[3])])
    if t == 'SOA':  x = resto.split(); return ' '.join([nom(x[0]), nom(x[1])] + x[2:])
    return resto

def clave(secc, nombre, t, rdata, ttl):
    """(sección, nombre, tipo, dato sin serial) -> (ttl, serial). El serial se mira aparte."""
    serial = None
    if t == 'SOA':
        x = rdata.split(); serial = int(x[2]); rdata = ' '.join(x[:2] + ['<serial>'] + x[3:])
    return (secc, nombre, t, rdata), (int(ttl), serial)

def lindo(k, v):
    secc, n, t, rd = k
    if v[1] is not None: rd = rd.replace('<serial>', str(v[1]))
    return f'{secc:<10} {n} {v[0]} IN {t} {rd}'

def dig(*args):
    return subprocess.run(['dig', '@' + server, '+time=2', '+tries=1', *args],
                          capture_output=True, text=True).stdout

def preguntar(qname, qtype):
    out = dig(qname, qtype, '+noall', '+comments', '+answer', '+authority', '+additional')
    status, aa, secc, rrs = None, False, None, {}
    for l in out.splitlines():
        if '->>HEADER<<-' in l:
            status = l.split('status:')[1].split(',')[0].strip()
        elif l.startswith(';; flags:'):
            aa = 'aa' in l.split(':', 1)[1].split(';')[0].split()
        elif l.startswith(';; ') and l.rstrip().endswith('SECTION:'):
            secc = l[3:].split()[0]
        elif l.strip() and not l.startswith(';'):
            p = l.split(None, 4)
            if len(p) == 5 and p[3] != 'OPT':
                k, v = clave(secc, nom(p[0]), p[3], rdata_dig(p[3], p[4]), p[1])
                rrs[k] = v
    return status, aa, rrs

# ---- 1. lo que dice la captura --------------------------------------------------
with open(pcap, 'rb') as f:   # Python sí puede abrir tu home; tshark lo lee por stdin
    salida = subprocess.run(['tshark', '-r', '-', '-T', 'json', '-Y', 'dns.flags.response == 1'],
                            stdin=f, capture_output=True, check=True).stdout
respuestas = []
for paquete in json.loads(salida, object_pairs_hook=lambda p: p):
    capas = g(g(paquete, '_source'), 'layers')
    dns, frame = g(capas, 'dns'), g(g(capas, 'frame'), 'frame.number')
    flags = int(g(dns, 'dns.flags'), 16)
    pregunta = g(dns, 'Queries')[0][1]
    qname = nom(g(pregunta, 'dns.qry.name'))
    qtype = TIPOS.get(int(g(pregunta, 'dns.qry.type')), g(pregunta, 'dns.qry.type'))
    rrs = {}
    for nombre_secc, secc in SECC.items():
        for resumen, rr in g(dns, nombre_secc, []):
            tnum = int(g(rr, 'dns.resp.type'))
            if tnum == 41: continue                       # OPT (EDNS): no es un registro de la zona
            t = TIPOS.get(tnum, str(tnum))
            k, v = clave(secc, nom(g(rr, 'dns.resp.name')), t, rdata_pcap(t, rr, resumen), g(rr, 'dns.resp.ttl'))
            rrs[k] = v
    respuestas.append((frame, qname, qtype, RCODE.get(flags & 0xF, str(flags & 0xF)), bool(flags & 0x0400), rrs))

serial_captura = max((v[1] for *_, rrs in respuestas for k, v in rrs.items() if k[2] == 'SOA'), default=None)

# ---- 2. ¿tu zona carga? ¿bind sirve ESA versión? ---------------------------------
print(f'\n{B}Tu configuración{N}')
def mostrar(r):
    for l in (r.stdout + r.stderr).splitlines():
        if 'loaded serial' not in l and l.strip() != 'OK': print(f'          {l}')
r = subprocess.run(['sudo', 'named-checkconf', '-z'], capture_output=True, text=True)
chk(r.returncode == 0, 'sudo named-checkconf -z  (named.conf y todas las zonas)')
if r.returncode: mostrar(r)

archivo = sys.argv[4] if len(sys.argv) > 4 else ''
serial_archivo = None
if not archivo:
    chk(False, f'no hay un bloque  zone "{zona}" {{ ... file "..."; }};  en /etc/bind/named.conf.local')
else:
    r = subprocess.run(['named-checkzone', zona, archivo], capture_output=True, text=True)
    chk(r.returncode == 0, f'named-checkzone {zona} {archivo}')
    if r.returncode: mostrar(r)
    else: serial_archivo = int(r.stdout.split('loaded serial')[1].split()[0])

status, _, soa = preguntar(zona, 'SOA')
serial_bind = next((v[1] for k, v in soa.items() if k[2] == 'SOA' and k[0] == 'ANSWER'), None)
if archivo and serial_bind != serial_archivo:
    chk(False, f'bind está sirviendo el serial {serial_bind}, pero tu archivo '
               + (f'tiene {serial_archivo}' if serial_archivo else 'no carga') +
               '.\n          bind tiene en memoria OTRA versión: o no recargaste (sudo systemctl reload named),'
               '\n          o recargaste y falló (si la zona nueva tiene errores, bind sigue sirviendo la vieja).'
               '\n          Ojo: los OK de abajo son de esa versión, no de tu archivo.')

# ---- 3. preguntarle lo mismo a tu bind ------------------------------------------
print(f'\n{B}Cada consulta de la captura, repetida contra tu bind ({server}){N}')
for frame, qname, qtype, rcode, aa, esperado in respuestas:
    print(f'\n  frame {frame}:  dig {qname} {qtype}   (la captura dice {rcode}, '
          f'{sum(1 for k in esperado if k[0]=="ANSWER")} en ANSWER)')
    status, aa_tuyo, tuyo = preguntar(qname, qtype)
    if status is None:
        chk(False, 'tu bind no contestó en 2 s. O no está corriendo (systemctl status named), o no tiene '
                   'cargada la zona y salió a buscarla a Internet'); continue
    chk(status == rcode, f'status {status}' + ('' if status == rcode else f'  (la captura dice {rcode})'))
    if aa and not aa_tuyo:
        chk(False, 'la respuesta NO es autoritativa (sin flag aa): bind no tiene cargada la zona. '
                   '¿La declaraste en named.conf.local y recargaste? Mirá journalctl -u named')
    for k, v in esperado.items():
        if k in tuyo:
            ttl_ok = tuyo[k][0] == v[0]
            chk(ttl_ok, lindo(k, v) + ('' if ttl_ok else f'   <- TTL: la captura dice {v[0]}, tu bind {tuyo[k][0]}'))
        else:
            chk(False, f'falta  {lindo(k, v)}')
    for k, v in tuyo.items():
        if k not in esperado:
            chk(False, f'sobra  {lindo(k, v)}   (en la captura no vino)')

# ---- 4. lo nuevo: serial y el TXT que pide el enunciado -------------------------
print(f'\n{B}Lo que pide el enunciado además de reconstruir{N}')
serial_tuyo = serial_archivo or serial_bind
if serial_tuyo is None:
    chk(False, f'no pude leer el serial de {zona}')
elif serial_captura is not None:
    chk(serial_tuyo > serial_captura,
        f'serial {serial_tuyo} ' + ('> ' if serial_tuyo > serial_captura else 'NO es mayor que ') +
        f'el de la captura ({serial_captura})' + ('' if serial_tuyo > serial_captura else
        ': si cambiás la zona, el serial sube (si no, los secundarios no se enteran)'))

# La zona entera: named-checkzone -D sobre tu archivo (bind 9.20 no deja hacer AXFR por defecto)
axfr = subprocess.run(['named-checkzone', '-D', '-o', '-', zona, archivo],
                      capture_output=True, text=True).stdout if serial_archivo else ''
if not axfr.strip():
    print(f'  info  tu archivo de zona no carga: salteo el chequeo del TXT nuevo')
else:
    en_captura = {(k[1], k[2], k[3]) for *_, rrs in respuestas for k in rrs}
    nuevos = []
    for l in axfr.splitlines():
        p = l.split(None, 4)
        if len(p) == 5 and not l.startswith(';') and p[3] != 'SOA':
            k, v = clave('ZONA', nom(p[0]), p[3], rdata_dig(p[3], p[4]), p[1])
            if (k[1], k[2], k[3]) not in en_captura and (k, v) not in nuevos:
                nuevos.append((k, v))
    for k, v in nuevos:
        print(f'  info  nuevo (no está en la captura): {lindo(k, v)[11:]}')
    chk(any(k[2] == 'TXT' for k, _ in nuevos), 'agregaste un TXT que no estaba en la captura')

print(f'\n{B}{ok} OK, {mal} FALLA{N}')
sys.exit(1 if mal else 0)
PY

verificar() {
    local zona; zona=$(zona_de_la_captura)
    paso "Captura: $PCAP   ->   zona: $zona"
    python3 -I -c "$CORRECTOR" "$PCAP" 127.0.0.1 "$zona" "$(archivo_de_la_zona "$zona")"
}

archivo_de_la_zona() {   # el "file" del bloque zone "$1" de named.conf.local
    awk -v z="\"$1\"" '/^[[:space:]]*zone[[:space:]]/ && index($0, z) {en=1}
        en && /^[[:space:]]*file[[:space:]]/ {gsub(/[";]/,"",$2); print $2; exit}
        en && /^[[:space:]]*};/ {en=0}' "$CONF"
}

solucion() {
    local zona db; zona=$(zona_de_la_captura)
    case "$zona" in
        protos.parcial) db="$PROTOS/ejercicios/parciales/2026-2c-ej4-protos.parcial.db" ;;
        repaso.parcial) db="$PROTOS/ejercicios/dns-pcap/repaso.parcial-SOLUCION.db" ;;
        *) echo "No tengo resolución para la zona $zona"; exit 1 ;;
    esac
    if grep -q "zone[[:space:]]*\"$zona\"" "$CONF"; then
        echo "Ya hay una zona \"$zona\" en $CONF (¿tu intento?). Primero:  $0 limpiar $PCAP"; exit 1
    fi
    paso "Cargando la resolución de $zona"
    if [ -e "/etc/bind/zones/db.$zona" ]; then     # un archivo tuyo sin declarar: no lo piso
        mkdir -p "$HOME/intentos-dns"
        sudo mv "/etc/bind/zones/db.$zona" "$HOME/intentos-dns/db.$zona.$(date +%Y%m%d-%H%M%S)"
        echo "Había un /etc/bind/zones/db.$zona: lo moví a ~/intentos-dns/"
    fi
    sudo install -m 644 -o root -g bind "$db" "/etc/bind/zones/db.$zona"
    printf 'zone "%s" {\n\ttype master;\n\tfile "/etc/bind/zones/db.%s";\n};\n' "$zona" "$zona" \
        | sudo tee -a "$CONF" >/dev/null
    if sudo named-checkconf -z >/dev/null 2>&1; then
        sudo systemctl reload named && sleep 1
        echo "Listo. Ahora:  $0 verificar $PCAP"
    else
        sudo named-checkconf -z 2>&1 | grep -vi 'loaded serial'
    fi
}

limpiar() {
    local zona f ts; zona=$(zona_de_la_captura); ts=$(date +%Y%m%d-%H%M%S)
    if ! grep -q "zone[[:space:]]*\"$zona\"" "$CONF"; then echo "No hay zona \"$zona\" en $CONF: nada que limpiar"; return; fi
    f=$(archivo_de_la_zona "$zona")
    mkdir -p "$HOME/intentos-dns"
    cp "$CONF" "$HOME/intentos-dns/named.conf.local.$ts"
    sudo sed -i "/^[[:space:]]*zone[[:space:]]*\"${zona//./\\.}\"/,/^[[:space:]]*};/d" "$CONF"
    if [ -n "$f" ] && [ -f "$f" ]; then
        sudo mv "$f" "$HOME/intentos-dns/$(basename "$f").$ts"
        sudo chown "$(id -u):$(id -g)" "$HOME/intentos-dns/$(basename "$f").$ts"
        sudo rm -f "$f.jnl"
    fi
    sudo named-checkconf -z >/dev/null && sudo systemctl reload named
    echo "Saqué la zona $zona. Lo tuyo quedó en ~/intentos-dns/ (named.conf.local.$ts y el archivo de zona)."
}

case "${1:-}" in
    verificar) verificar ;;
    solucion)  solucion ;;
    limpiar)   limpiar ;;
    *) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

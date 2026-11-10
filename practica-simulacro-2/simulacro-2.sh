#!/usr/bin/env bash
# ============================================================
# simulacro-2.sh  -  segundo simulacro de parcial practico (inventado, estilo parciales viejos)
#
# Uso:  ~/Protos/practica-simulacro-2/simulacro-2.sh  montar|verificar|limpiar|pista|solucion  [ej1..ej4|todo]
#
#   montar [ejN]     levanta los servidores del ejercicio (o de los 4 con 'todo')
#   verificar [ejN]  corrige: OK / FALLA por requisito
#   pista  [ejN]     una pista corta si estas trabado (NO te da el comando)
#   solucion [ejN]   la resolucion completa (ultimo recurso)
#   limpiar  [ejN]   saca TODO lo que monto este script (servidores + tu solucion)
#
# Estilo: las respuestas de los servidores te van guiando, pero NO te dan el comando
# hecho; hay que pensarlo/armarlo. Muchas pistas viven en los HEADERS de la respuesta,
# asi que vas a necesitar 'curl -v' (o -i). Los proxies son SOCKS (no HTTP).
#
#   Ej1  tunel SOCKS a la intranet de Bloom + negociacion de contenido + Basic auth
#   Ej2  reverse proxy: un header que mandas vuelve como header en la respuesta
#   Ej3  DNS: corregir una zona rota (bind9)
#   Ej4  mail a mano: Subject en encoded-words + header X-Parcial + cuerpo base64 + POP3
#
# Corre todo por loopback en esta sola VM. No toca tus zonas ni tu /var/www: usa
# /srv/simulacro-2, usuarios propios (topo) y marcadores en los configs.
# ============================================================
set -uo pipefail

SRV=/srv/simulacro-2

# --- Ej1 ---
E1_SOCKS_PORT=1080
E1_PORT=8081
E1_HOST=intranet.bloom.foo
E1_NGINX=/etc/nginx/sites-available/simulacro-2-ej1
E1_HTPASS=/etc/nginx/simulacro-2-ej1.htpasswd
E1_USER=agente
E1_PASS=topo
E1_SOCKS_CMD='ssh -fN -o BatchMode=yes -o ExitOnForwardFailure=yes -D 1080 localhost'

# --- Ej2 ---
E2_PORT=8082
E2_HOST=portal.bloom.foo
E2_NGINX=/etc/nginx/sites-available/simulacro-2-ej2
E2_BACK=$SRV/ej2/backend.py
E2_PID=/tmp/simulacro-2-ej2.pid
E2_TOKEN=2026/2

# --- Ej3 ---
E3_ZONE=bloom.lab
E3_ZONEFILE=/etc/bind/zones/db.bloom.lab
NCL=/etc/bind/named.conf.local

# --- Ej4 ---
E4_USER=topo
E4_PASS=topo
E4_DOMAIN=pdc.lab
E4_TOKEN=2026/2

# ------------------------------------------------------------ helpers
c_az='\033[1;34m'; c_bold='\033[1m'; c_ok='\033[32m'; c_mal='\033[31m'; c_0='\033[0m'
paso() { printf "\n${c_az}==> %s${c_0}\n" "$*"; }
tit()  { printf "\n${c_bold}%s${c_0}\n" "$*"; }
info() { printf "  info  %s\n" "$*"; }
ok=0; mal=0
chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then printf "  ${c_ok}OK   ${c_0} %s\n" "$d"; ok=$((ok+1)); else printf "  ${c_mal}FALLA${c_0} %s\n" "$d"; mal=$((mal+1)); fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then printf "  ${c_mal}FALLA${c_0} %s\n" "$d"; mal=$((mal+1)); else printf "  ${c_ok}OK   ${c_0} %s\n" "$d"; ok=$((ok+1)); fi; }
resumen() { printf "\n  %s: ${c_ok}%d OK${c_0}, ${c_mal}%d FALLA${c_0}\n" "$1" "$ok" "$mal"; ok=0; mal=0; }
reload_nginx() { sudo nginx -t >/dev/null 2>&1 && sudo systemctl reload nginx; }
hosts_add() {  # hosts_add <marcador> <linea>
  grep -q "^# --- $1" /etc/hosts || printf '# --- %s (lo saca simulacro-2.sh) ---\n%s\n# --- FIN %s ---\n' "$1" "$2" "$1" | sudo tee -a /etc/hosts >/dev/null
}
hosts_del() { sudo sed -i "/^# --- $1 /,/^# --- FIN $1 /d" /etc/hosts; }

# ============================================================ EJ1
montar_ej1() {
  limpiar_ej1 >/dev/null 2>&1
  paso "Ej1: tunel SOCKS + intranet con negociacion de contenido + Basic auth"

  sudo install -d "$SRV/ej1/es" "$SRV/ej1/en"
  sudo tee "$SRV/ej1/en/index.html" >/dev/null <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8"><title>Bloom intranet</title>
<h1>Bloom // internal panel</h1>
<p>Access granted, agent. But this edition is redacted.</p>
<p>The operation plan is only published in the <b>Spanish edition</b> of this panel.</p>
<p>(This panel serves a different body per language — check the response headers, there is a
clue there about what varies.)</p>
HTML
  sudo tee "$SRV/ej1/es/index.html" >/dev/null <<'HTML'
<!doctype html><html lang="es"><meta charset="utf-8"><title>Bloom intranet</title>
<h1>Bloom // panel interno</h1>
<p>Edicion en espaniol. Plan de la operacion contra DebSec:</p>
<ul>
  <li>Mover el tracker ct 2.0 a un host nuevo el viernes.</li>
  <li><b>FLAG{socks-negociacion-ok}</b></li>
</ul>
HTML
  sudo chown -R www-data:www-data "$SRV/ej1"

  local hash; hash=$(openssl passwd -apr1 "$E1_PASS")
  echo "$E1_USER:$hash" | sudo tee "$E1_HTPASS" >/dev/null
  sudo chmod 640 "$E1_HTPASS"; sudo chown root:www-data "$E1_HTPASS"

  sudo tee "$E1_NGINX" >/dev/null <<EOF
# el panel sirve distinto cuerpo segun el idioma pedido (Accept-Language)
map \$http_accept_language \$ed_bloom {
    default en;
    "~*\bes\b" es;
}
server {
    listen 127.0.0.1:$E1_PORT;
    server_name $E1_HOST;
    auth_basic "bloom intranet";
    auth_basic_user_file $E1_HTPASS;
    add_header Vary "Accept-Language" always;
    root $SRV/ej1;
    location / { try_files /\$ed_bloom/index.html =404; }
}
EOF
  sudo ln -sf "$E1_NGINX" /etc/nginx/sites-enabled/simulacro-2-ej1
  reload_nginx
  hosts_add SIM2-EJ1 "127.0.0.1   $E1_HOST"

  # dejamos el tunel SOCKS abierto (como si fuera el acceso a la intranet)
  eval "$E1_SOCKS_CMD" 2>/dev/null
  sleep 1

  tit "Montado. Consigna:"
  cat <<EOF
  Te infiltraste en Bloom y dejaste un tunel abierto hacia su intranet. Fijate que puerto
  quedo escuchando (pista: 'ss -tlnp' | grep ssh). El panel interno es "$E1_HOST", y tus
  credenciales de agente son  $E1_USER / $E1_PASS .
  Entra y traeme el plan de la operacion. Ojo: el panel no te lo va a dar tan facil, leé
  TODO lo que te responde el servidor, no solo el cuerpo.
  (si te trabas:  simulacro-2.sh pista ej1)
EOF
}

verificar_ej1() {
  tit "Ej1 - SOCKS + negociacion de contenido + Basic auth"
  local P="socks5h://localhost:$E1_SOCKS_PORT"
  chk "el tunel SOCKS esta escuchando en :$E1_SOCKS_PORT" bash -c "sudo ss -tlnp | grep -q ':$E1_SOCKS_PORT '"
  chk "por el tunel + sin auth -> 401" \
      bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 8 -x $P http://$E1_HOST:$E1_PORT/ | grep -q 401"
  chk "por el tunel + auth, pero sin pedir espaniol -> NO trae la flag" \
      bash -c "! curl -s --max-time 8 -x $P -u $E1_USER:$E1_PASS http://$E1_HOST:$E1_PORT/ | grep -q 'FLAG{'"
  chk "por el tunel + auth + Accept-Language: es -> trae la flag" \
      bash -c "curl -s --max-time 8 -x $P -u $E1_USER:$E1_PASS -H 'Accept-Language: es' http://$E1_HOST:$E1_PORT/ | grep -q 'FLAG{'"
  resumen "Ej1"
}

pista_ej1() {
  cat <<EOF
  Ej1:
  - El tunel es un proxy SOCKS (lo armo un 'ssh -D'). curl habla con un proxy SOCKS con -x
    y el esquema socks5h (con h = que resuelva el proxy). El puerto lo ves con ss.
  - El panel pide usuario y clave (Basic auth): son las credenciales de agente que te da la
    consigna. curl las manda con -u usuario:clave.
  - Con auth entras pero ves la edicion equivocada. El header "Vary" te dice segun que cambia
    la respuesta. Pedile al server la otra edicion con el header de negociacion que
    corresponde.
EOF
}

solucion_ej1() {
  tit "Ej1 - resolucion"
  cat <<EOF
  El tunel es un proxy SOCKS en :$E1_SOCKS_PORT (ssh -D). Se usa con socks5h (resuelve el proxy).
  El panel pide Basic auth (agente / $E1_PASS) y negocia el idioma por Accept-Language; la flag
  esta solo en la edicion en espaniol:

    curl -v -x socks5h://localhost:$E1_SOCKS_PORT -u $E1_USER:$E1_PASS \\
         -H "Accept-Language: es" http://$E1_HOST:$E1_PORT/

  - -v para ver el header Vary: Accept-Language (ahi estaba la pista).
  - sin -H "Accept-Language: es" cae la edicion en ingles (redacted), sin la flag.
EOF
}

limpiar_ej1() {
  # matar el tunel SOCKS: por patron y, como respaldo, lo que escuche en el puerto (es nuestro)
  pkill -f "ssh -fN.*-D $E1_SOCKS_PORT localhost" 2>/dev/null
  sudo fuser -k "$E1_SOCKS_PORT/tcp" 2>/dev/null
  sudo rm -f /etc/nginx/sites-enabled/simulacro-2-ej1 "$E1_NGINX" "$E1_HTPASS"
  sudo rm -rf "$SRV/ej1"
  hosts_del SIM2-EJ1
  reload_nginx
}

# ============================================================ EJ2
montar_ej2() {
  limpiar_ej2 >/dev/null 2>&1
  paso "Ej2: reverse proxy + header que viaja de ida y vuelta"

  sudo install -d "$SRV/ej2"
  sudo tee "$E2_BACK" >/dev/null <<PY
#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
TOKEN = "$E2_TOKEN"
FLAG  = "FLAG{headers-ida-y-vuelta}"
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        parcial = self.headers.get("X-Parcial", "")
        if parcial == TOKEN:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("X-Flag", FLAG)   # <- el dato viaja en un header de respuesta
            self.end_headers()
            self.wfile.write(b"ok, agente. el dato viaja en un header de respuesta.\n")
        else:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("X-Expected", "X-Parcial")  # <- pista de que header mandar
            self.end_headers()
            self.wfile.write(b"Para el dato interno anunciate con el header del parcial "
                             b"(formato AAAA/C). El dato NO esta en el cuerpo.\n")
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", $E2_PORT), H).serve_forever()
PY
  nohup python3 "$E2_BACK" >/tmp/simulacro-2-ej2.log 2>&1 &
  echo $! > "$E2_PID"

  sudo tee "$E2_NGINX" >/dev/null <<EOF
# reverse proxy publico -> backend interno; reenvia el header X-Parcial del cliente
server {
    listen 80;
    server_name $E2_HOST;
    location / {
        proxy_pass http://127.0.0.1:$E2_PORT;
        proxy_set_header Host              \$host;
        proxy_set_header X-Parcial         \$http_x_parcial;   # <- el header del cliente llega al backend
    }
}
EOF
  sudo ln -sf "$E2_NGINX" /etc/nginx/sites-enabled/simulacro-2-ej2
  reload_nginx
  hosts_add SIM2-EJ2 "127.0.0.1   $E2_HOST"
  sleep 1

  tit "Montado. Consigna:"
  cat <<EOF
  Bloom tiene un portal publico en http://$E2_HOST/ que en realidad es un proxy a un
  servicio interno. El servicio guarda un dato que no muestra en la pagina. Conseguilo.
  Pista fuerte: el dato no esta en el cuerpo. Mira bien que te responde el servidor y que
  espera de vos.
  (si te trabas:  simulacro-2.sh pista ej2)
EOF
}

verificar_ej2() {
  tit "Ej2 - reverse proxy + headers"
  chk "el portal responde en :80 ($E2_HOST)" \
      bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 6 http://$E2_HOST/ | grep -qE '200'"
  chk "sin el header correcto NO aparece la flag" \
      bash -c "! curl -s -i --max-time 6 http://$E2_HOST/ | grep -q 'FLAG{'"
  chk "con X-Parcial: $E2_TOKEN la flag vuelve en el header X-Flag" \
      bash -c "curl -s -i --max-time 6 -H 'X-Parcial: $E2_TOKEN' http://$E2_HOST/ | grep -i '^X-Flag:' | grep -q 'FLAG{'"
  resumen "Ej2"
}

pista_ej2() {
  cat <<EOF
  Ej2:
  - 'El dato no esta en el cuerpo' = esta en un HEADER de respuesta. Para ver los headers,
    curl -v (o -i).
  - La primera respuesta trae un header que te dice que header espera de vos (algo tipo
    'X-Expected'). Mandaselo con -H, con el valor que pide el enunciado (formato AAAA/C).
  - nginx reenvia ese header al backend, y el backend te contesta con el dato en otro header.
EOF
}

solucion_ej2() {
  tit "Ej2 - resolucion"
  cat <<EOF
  El backend solo suelta el dato si le mandas el header X-Parcial con el valor $E2_TOKEN, y lo
  devuelve en el header de respuesta X-Flag. El reverse proxy reenvia tu header al backend.

    curl -v -H "X-Parcial: $E2_TOKEN" http://$E2_HOST/
    # en la respuesta:  < X-Flag: FLAG{headers-ida-y-vuelta}

  Sin -v (o -i) no lo ves, porque no viaja en el cuerpo. La primera respuesta (sin el header)
  trae un X-Expected: X-Parcial que es la pista.
EOF
}

limpiar_ej2() {
  [ -f "$E2_PID" ] && { kill "$(cat "$E2_PID")" 2>/dev/null; rm -f "$E2_PID"; }
  pkill -f "$E2_BACK" 2>/dev/null
  sudo rm -f /etc/nginx/sites-enabled/simulacro-2-ej2 "$E2_NGINX"
  sudo rm -rf "$SRV/ej2"
  hosts_del SIM2-EJ2
  reload_nginx
}

# ============================================================ EJ3
montar_ej3() {
  limpiar_ej3 >/dev/null 2>&1
  paso "Ej3: zona DNS rota $E3_ZONE (hay que corregirla)"
  sudo install -d -o root -g bind /etc/bind/zones
  # zona con 3 errores a proposito (ver pista/solucion)
  sudo tee "$E3_ZONEFILE" >/dev/null <<EOF
\$TTL 1h
\$ORIGIN $E3_ZONE.
@   IN  SOA ns1.$E3_ZONE. admin@$E3_ZONE. (
            2026010101 1h 15m 2w 1h )
@           IN  NS    ns1.$E3_ZONE.
ns1         IN  A     10.0.0.53
@           IN  A     10.0.0.80
www         IN  CNAME @
www         IN  A     10.0.0.80
@           IN  MX 10 mail.$E3_ZONE
mail        IN  A     10.0.0.25
EOF
  if ! grep -q "zone \"$E3_ZONE\"" "$NCL"; then
    sudo tee -a "$NCL" >/dev/null <<EOF
// --- SIM2-EJ3 (lo saca simulacro-2.sh limpiar ej3) ---
zone "$E3_ZONE" { type master; file "$E3_ZONEFILE"; allow-transfer { 127.0.0.1; }; notify no; };
// --- FIN SIM2-EJ3 ---
EOF
  fi
  sudo rndc reconfig 2>/dev/null
  tit "Montado. Consigna:"
  cat <<EOF
  La zona "$E3_ZONE" ($E3_ZONEFILE) esta rota: bind no la carga. Corregila para que:
    - cargue sin errores (sudo named-checkzone $E3_ZONE $E3_ZONEFILE),
    - resuelva @ y www (A), ns1, y el MX apuntando a mail.$E3_ZONE,
  y recarga bind. Son 3 errores tipicos de archivos de zona.
  Pista inicial: empeza por 'sudo named-checkzone $E3_ZONE $E3_ZONEFILE', te marca las lineas.
  (si te trabas:  simulacro-2.sh pista ej3)
EOF
}

verificar_ej3() {
  tit "Ej3 - zona $E3_ZONE corregida"
  local d="dig @127.0.0.1 +norecurse +noall +answer"
  chk "named-checkzone pasa sin errores" bash -c "sudo named-checkzone $E3_ZONE $E3_ZONEFILE | tail -1 | grep -q OK"
  chk "la zona responde autoritativa (flag aa)" bash -c "dig @127.0.0.1 +norecurse $E3_ZONE SOA | grep -q 'flags:.* aa'"
  chk "el mail del SOA quedo bien (admin.$E3_ZONE., no admin@)" \
      bash -c "$d $E3_ZONE SOA | grep -q 'admin.$E3_ZONE.'"
  chk "A de @ -> 10.0.0.80" bash -c "$d $E3_ZONE A | grep -q '10.0.0.80'"
  chk "www es CNAME a @ (sin A propio)" \
      bash -c "$d www.$E3_ZONE A | grep -q 'CNAME' && ! $d www.$E3_ZONE A | grep -qE 'www.$E3_ZONE.[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+A'"
  chk "MX apunta a mail.$E3_ZONE. (sin dominio duplicado)" \
      bash -c "$d $E3_ZONE MX | grep -qE 'mail.$E3_ZONE.$' && ! $d $E3_ZONE MX | grep -q '$E3_ZONE.$E3_ZONE'"
  resumen "Ej3"
}

pista_ej3() {
  cat <<EOF
  Ej3: corré 'sudo named-checkzone $E3_ZONE $E3_ZONEFILE' y leé los errores. Fijate:
  - El mail del SOA: la @ no va literal en un nombre DNS (en el SOA el '@' del mail se escribe
    como un punto).
  - Un mismo nombre no puede ser CNAME y ademas tener otros registros (CNAME and other data).
  - Los nombres absolutos terminan en punto; si a un destino le falta el punto final, se le
    pega el \$ORIGIN y queda duplicado (mirá a donde apunta el MX).
EOF
}

solucion_ej3() {
  tit "Ej3 - resolucion (te dejo la zona corregida aplicada)"
  sudo tee "$E3_ZONEFILE" >/dev/null <<EOF
\$TTL 1h
\$ORIGIN $E3_ZONE.
@   IN  SOA ns1.$E3_ZONE. admin.$E3_ZONE. (   ; el @ del mail se escribe como punto
            2026010102 1h 15m 2w 1h )          ; subi el serial
@           IN  NS    ns1.$E3_ZONE.
ns1         IN  A     10.0.0.53
@           IN  A     10.0.0.80
www         IN  CNAME @                         ; www es SOLO CNAME (sin A)
@           IN  MX 10 mail.$E3_ZONE.            ; punto final: si no, queda mail.$E3_ZONE.$E3_ZONE.
mail        IN  A     10.0.0.25
EOF
  sudo named-checkzone "$E3_ZONE" "$E3_ZONEFILE"
  sudo rndc reload "$E3_ZONE" 2>/dev/null || sudo rndc reload
  cat <<EOF

  Los 3 errores eran:
  1. SOA: 'admin@$E3_ZONE.' -> 'admin.$E3_ZONE.' (la @ del mail se escribe como punto).
  2. www tenia CNAME y ademas un A: un CNAME no puede convivir con otros registros. Se saca el A.
  3. MX 'mail.$E3_ZONE' sin punto final -> se le pegaba el \$ORIGIN (mail.$E3_ZONE.$E3_ZONE.).
     Con el punto final queda mail.$E3_ZONE.
EOF
}

limpiar_ej3() {
  sudo sed -i '/^\/\/ --- SIM2-EJ3/,/^\/\/ --- FIN SIM2-EJ3/d' "$NCL"
  sudo rm -f "$E3_ZONEFILE" "$E3_ZONEFILE.jnl"
  sudo rndc reconfig 2>/dev/null
}

# ============================================================ EJ4
montar_ej4() {
  limpiar_ej4 >/dev/null 2>&1
  paso "Ej4: mail a mano con encoded-words + header X-Parcial + base64"
  id "$E4_USER" >/dev/null 2>&1 || sudo useradd -m -s /bin/bash "$E4_USER"
  echo "$E4_USER:$E4_PASS" | sudo chpasswd
  sudo -u "$E4_USER" mkdir -p "/home/$E4_USER/Maildir/cur" "/home/$E4_USER/Maildir/new" "/home/$E4_USER/Maildir/tmp"
  tit "Montado. Consigna:"
  cat <<EOF
  Mandá un informe por SMTP a mano (:25) a la casilla $E4_USER@$E4_DOMAIN (POP3 $E4_USER/$E4_PASS).
  Requisitos del informe:
    - Subject:  Informe: situación crítica   (con tildes y todo, en castellano)
    - un header  X-Parcial: $E4_TOKEN
    - el cuerpo SOLO en base64 (nada de quoted-printable)
  Despues verificá por POP3 que entro.
  Pista: un Subject con tildes/eñes NO puede ir en texto plano en un header. Averigua como se
  codifican los headers con caracteres no-ASCII (MIME "encoded-words").
  (si te trabas:  simulacro-2.sh pista ej4)
EOF
}

verificar_ej4() {
  tit "Ej4 - mail con encoded-words + X-Parcial + base64"
  local md="/home/$E4_USER/Maildir"
  chk "postfix :25 y dovecot :110 escuchando" bash -c "sudo ss -tulpn | grep -q ':25 ' && sudo ss -tulpn | grep -q ':110 '"
  chk "login POP3 $E4_USER funciona" \
      bash -c "printf 'USER $E4_USER\r\nPASS $E4_PASS\r\nSTAT\r\nQUIT\r\n' | nc -C -w3 127.0.0.1 110 | grep -qE '^\\+OK [0-9]'"
  chk "llego un mail con el header X-Parcial: $E4_TOKEN" \
      bash -c "sudo grep -rlsi 'X-Parcial: $E4_TOKEN' '$md/new' '$md/cur' 2>/dev/null | head -1 | grep -q ."
  chk "el Subject esta en encoded-words (=?...?=)" \
      bash -c "sudo grep -rlsi 'Subject:.*=?.*?=' '$md/new' '$md/cur' 2>/dev/null | head -1 | grep -q ."
  chk "el cuerpo va en base64 (Content-Transfer-Encoding: base64)" \
      bash -c "sudo grep -rlsi 'Content-Transfer-Encoding: base64' '$md/new' '$md/cur' 2>/dev/null | head -1 | grep -q ."
  resumen "Ej4"
}

pista_ej4() {
  cat <<EOF
  Ej4:
  - Un header no es 8-bit: para meter tildes/eñes en el Subject se usa MIME "encoded-words",
    con el formato  =?charset?codificacion?texto?=  . La codificacion puede ser B (base64) o
    Q (quoted-printable). Ej: para base64 -> =?UTF-8?B?<base64 del subject>?=
  - El cuerpo en base64:  generalo con  echo -n 'tu texto' | base64  y poné el header
    Content-Transfer-Encoding: base64 antes de la linea en blanco.
  - No te olvides el X-Parcial: $E4_TOKEN como un header mas, y cerrar el DATA con la linea del punto.
EOF
}

solucion_ej4() {
  tit "Ej4 - resolucion"
  local subj; subj=$(printf '%s' 'Informe: situación crítica' | base64)
  local body; body=$(printf '%s' 'sin novedades en el frente' | base64)
  cat <<EOF
  El Subject con tildes va en encoded-words base64, y el cuerpo en base64. Sesion:

    nc -C 127.0.0.1 25
    EHLO pdc.lab
    MAIL FROM:<$E4_USER@$E4_DOMAIN>
    RCPT TO:<$E4_USER@$E4_DOMAIN>
    DATA
    From: Topo <$E4_USER@$E4_DOMAIN>
    To: <$E4_USER@$E4_DOMAIN>
    Subject: =?UTF-8?B?$subj?=
    X-Parcial: $E4_TOKEN
    Content-Type: text/plain; charset=UTF-8
    Content-Transfer-Encoding: base64

    $body
    .
    QUIT

  (=?UTF-8?B?$subj?= es "Informe: situación crítica" en encoded-words base64.)
  Verificar por POP3: USER/PASS/STAT/LIST/RETR 1.
EOF
}

limpiar_ej4() {
  sudo userdel -r "$E4_USER" 2>/dev/null
}

# ============================================================ dispatcher
EJ="${2:-todo}"
accion() {
  local v="$1" e="$2"
  case "$e" in
    ej1) ${v}_ej1;; ej2) ${v}_ej2;; ej3) ${v}_ej3;; ej4) ${v}_ej4;;
    todo) ${v}_ej1; ${v}_ej2; ${v}_ej3; ${v}_ej4;;
    *) echo "ejercicio invalido: $e (ej1|ej2|ej3|ej4|todo)"; exit 2;;
  esac
}
case "${1:-}" in
  montar)    accion montar "$EJ";;
  verificar) accion verificar "$EJ";;
  limpiar)   accion limpiar "$EJ"; echo "limpio: $EJ";;
  pista)     accion pista "$EJ";;
  solucion)  accion solucion "$EJ";;
  *) sed -n '2,24p' "$0"; exit 1;;
esac

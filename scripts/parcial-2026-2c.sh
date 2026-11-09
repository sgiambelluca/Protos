#!/usr/bin/env bash
# ============================================================
# parcial-2026-2c.sh  -  practicar en ESTA VM el parcial práctico 2026 2C
#                        (el que rendiste; enunciados y resolución en apuntes/20-parcial-2026-2c.md)
#
# Uso:  ~/Protos/scripts/parcial-2026-2c.sh  montar|verificar|limpiar|solucion  [ej1|ej2|ej3|ej4|todo]
#
#   montar [ejN]     levanta los servidores de ese ejercicio (o de los 4 si no aclarás)
#   verificar [ejN]  corrige lo que resolviste: OK / FALLA por requisito
#   limpiar  [ejN]   saca TODO lo que montó este script (servidores + tu solución de ese ej)
#   solucion [ejN]   imprime la resolución paso a paso (y en el Ej4 te la deja aplicada)
#
# Los 4 ejercicios corren por loopback en esta sola VM (como en el parcial):
#   Ej1  proxy Squid en :3126 delante de un "hackerspace" que SOLO se resuelve por el proxy
#        (practicás curl -x, resolución de nombre del lado del proxy = socks5h, y Basic auth)
#   Ej2  nginx con vhost por Host (google.com en :80) + vhost interno (secrethost en :81 -> :8000)
#        + SSH del usuario pepito con clave privada y passphrase
#   Ej3  SMTP y POP3 a mano con nc (mandar un mail MIME base64 y verificarlo)
#   Ej4  reconstruir la zona DNS cachito.parcial a partir de una captura PCAP, con bind9
#
# NO toca tus zonas cachito.com / pepito.com / foo.pdc.lab ni tu /var/www.
# Todo lo suyo vive en /srv/parcial-2026-2c, usuarios propios y marcadores en los configs.
# ============================================================
set -uo pipefail

# el pcap del Ej4 puede estar al lado del script (carpeta practica) o en ejercicios/...
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if   [ -f "$SELF_DIR/ej4/backup.pcap" ];                                   then BASE="$SELF_DIR"
elif [ -f "$HOME/Protos/practica-simulacro-parcial/ej4/backup.pcap" ];     then BASE="$HOME/Protos/practica-simulacro-parcial"
else BASE="$HOME/Protos/ejercicios/parciales/2026-2c"; fi
SRV=/srv/parcial-2026-2c

# --- Ej1 ---
SQUID_CONF=/etc/squid/parcial-ej1.conf
SQUID_HOSTS=/etc/squid/parcial-ej1-hosts
E1_ROOT=$SRV/ej1/www
E1_NGINX=/etc/nginx/sites-available/parcial-ej1
E1_HTPASS=/etc/nginx/parcial-ej1.htpasswd
E1_PROXY_PORT=3126
E1_ORIGIN_PORT=8090
E1_MEMBER_USER=debsec
E1_MEMBER_PASS=hackerspace

# --- Ej2 ---
E2_ROOT=$SRV/ej2/www
E2_BACK=$SRV/ej2/backend
E2_NGINX=/etc/nginx/sites-available/parcial-ej2
E2_BACK_PORT=8000
E2_SSH_USER=pepito
E2_PASSPHRASE=clave-del-parcial

# --- Ej3 ---
E3_USER=debsec
E3_PASS=debsec
E3_DOMAIN=pdc.lab

# --- Ej4 ---
E4_ZONE=cachito.parcial
E4_ZONEFILE=/etc/bind/zones/db.cachito.parcial
E4_DL_PORT=8008   # 8080 es tu protos-python-http.service, no lo pisamos
E4_DL_PID=/tmp/parcial-ej4-http.pid
E4_IP=192.168.0.238

# ------------------------------------------------------------ helpers
c_az='\033[1;34m'; c_bold='\033[1m'; c_ok='\033[32m'; c_mal='\033[31m'; c_0='\033[0m'
paso() { printf "\n${c_az}==> %s${c_0}\n" "$*"; }
tit()  { printf "\n${c_bold}%s${c_0}\n" "$*"; }
info() { printf "  info  %s\n" "$*"; }
ok=0; mal=0
chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then printf "  ${c_ok}OK   ${c_0} %s\n" "$d"; ok=$((ok+1)); else printf "  ${c_mal}FALLA${c_0} %s\n" "$d"; mal=$((mal+1)); fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then printf "  ${c_mal}FALLA${c_0} %s\n" "$d"; mal=$((mal+1)); else printf "  ${c_ok}OK   ${c_0} %s\n" "$d"; ok=$((ok+1)); fi; }
resumen() { printf "\n  %s: ${c_ok}%d OK${c_0}, ${c_mal}%d FALLA${c_0}\n" "$1" "$ok" "$mal"; ok=0; mal=0; }
need_nginx_reload() { sudo nginx -t >/dev/null 2>&1 && sudo systemctl reload nginx; }

# ============================================================ EJ1
montar_ej1() {
  limpiar_ej1 >/dev/null 2>&1
  paso "Ej1: Squid en :$E1_PROXY_PORT + hackerspace (sólo alcanzable por el proxy)"

  # sitio hackerspace (nginx, SÓLO en loopback:8090)
  sudo install -d "$E1_ROOT" "$E1_ROOT/novedades"
  sudo tee "$E1_ROOT/index.html" >/dev/null <<'HTML'
<!doctype html><html lang="es"><meta charset="utf-8"><title>DebSec hackerspace</title>
<h1>// DebSec hackerspace //</h1>
<p>Bienvenido, camarada. El plan contra Bloom esta en el tablon de novedades.</p>
<p>El tablon es solo para miembros. Entra con tus credenciales de miembro:</p>
<pre>  usuario: debsec
  clave  : hackerspace</pre>
<p>-> <a href="/novedades/">/novedades/</a></p>
HTML
  sudo tee "$E1_ROOT/novedades/index.html" >/dev/null <<'HTML'
<!doctype html><html lang="es"><meta charset="utf-8"><title>Novedades DebSec</title>
<h1>Novedades del grupo</h1>
<ul>
  <li>Bloom movio el sistema de trackeo ct 2.0 al host 192.168.0.238.</li>
  <li>Proxima reunion: miercoles 22:00, sala 3126.</li>
  <li>FLAG{proxy-mas-basic-auth-ok}</li>
</ul>
<p>Pudiste leer esto => pasaste por el proxy Y te autenticaste. Ese era el ejercicio.</p>
HTML
  sudo chown -R www-data:www-data "$SRV/ej1"

  # Basic auth del tablon (sin apache2-utils: hash apr1 con openssl)
  local hash; hash=$(openssl passwd -apr1 "$E1_MEMBER_PASS")
  echo "$E1_MEMBER_USER:$hash" | sudo tee "$E1_HTPASS" >/dev/null
  sudo chmod 640 "$E1_HTPASS"; sudo chown root:www-data "$E1_HTPASS"

  sudo tee "$E1_NGINX" >/dev/null <<EOF
# hackerspace del Ej1: escucha SOLO en loopback:$E1_ORIGIN_PORT
server {
    listen 127.0.0.1:$E1_ORIGIN_PORT;
    server_name hackerspace.protos.foo;
    root $E1_ROOT;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
    location /novedades/ {
        auth_basic "DebSec - solo miembros";
        auth_basic_user_file $E1_HTPASS;
    }
}
EOF
  sudo ln -sf "$E1_NGINX" /etc/nginx/sites-enabled/parcial-ej1
  need_nginx_reload

  # Squid :3126 - forward proxy. El nombre del hackerspace SOLO lo conoce el proxy
  # (hosts_file de squid), no /etc/hosts: por eso directo "no resuelve" y por el proxy si.
  echo "127.0.0.1 hackerspace.protos.foo" | sudo tee "$SQUID_HOSTS" >/dev/null
  sudo tee "$SQUID_CONF" >/dev/null <<EOF
http_port $E1_PROXY_PORT
acl lab src 127.0.0.1/32 ::1
http_access allow lab
http_access deny all
cache deny all
hosts_file $SQUID_HOSTS
dns_nameservers 127.0.0.1
pid_filename /run/squid-parcial-ej1.pid
access_log /var/log/squid/parcial-ej1.log
cache_log /var/log/squid/parcial-ej1-cache.log
coredump_dir /var/spool/squid
EOF
  sudo mkdir -p /var/log/squid /var/spool/squid
  sudo chown -R proxy:proxy /var/log/squid /var/spool/squid 2>/dev/null || true
  sudo squid -f "$SQUID_CONF" 2>/dev/null
  sleep 1

  # ej1.protos.foo (el proxy) SÍ va en /etc/hosts para poder nombrarlo en -x
  if ! grep -q '^# --- PARCIAL-2026-2C-EJ1' /etc/hosts; then
    sudo tee -a /etc/hosts >/dev/null <<'EOF'
# --- PARCIAL-2026-2C-EJ1 (lo saca parcial-2026-2c.sh limpiar ej1) ---
127.0.0.1   ej1.protos.foo
# --- FIN PARCIAL-2026-2C-EJ1 ---
EOF
  fi

  tit "Montado. Consigna:"
  cat <<EOF
  Conectate al hackerspace de DebSec. Solo se llega mediante el proxy
      http://ej1.protos.foo:$E1_PROXY_PORT
  y el tablon de novedades es solo para miembros. Decime que dice el ultimo
  anuncio del tablon.
  (si probas 'curl http://hackerspace.protos.foo:$E1_ORIGIN_PORT/' directo, no resuelve:
   ese nombre solo lo conoce el proxy. Esa es la gracia de -x / socks5h.)
EOF
}

verificar_ej1() {
  tit "Ej1 - proxy Squid + Basic auth"
  chk "Squid escucha en :$E1_PROXY_PORT" bash -c "sudo ss -tulpn | grep -q ':$E1_PROXY_PORT '"
  chk_not "hackerspace NO resuelve directo (sin proxy)" \
      bash -c "curl -s --max-time 5 http://hackerspace.protos.foo:$E1_ORIGIN_PORT/ -o /dev/null"
  chk "por el proxy SÍ se llega al index" \
      bash -c "curl -s --retry 2 --retry-connrefused --max-time 8 -x http://ej1.protos.foo:$E1_PROXY_PORT http://hackerspace.protos.foo:$E1_ORIGIN_PORT/ | grep -q hackerspace"
  chk "el tablon /novedades/ SIN auth da 401" \
      bash -c "curl -s -o /dev/null -w '%{http_code}' --retry 2 --retry-connrefused --max-time 8 -x http://ej1.protos.foo:$E1_PROXY_PORT http://hackerspace.protos.foo:$E1_ORIGIN_PORT/novedades/ | grep -q 401"
  chk "con proxy + Basic auth se lee la FLAG del tablon" \
      bash -c "curl -s --retry 2 --retry-connrefused --max-time 8 -x http://ej1.protos.foo:$E1_PROXY_PORT -u $E1_MEMBER_USER:$E1_MEMBER_PASS http://hackerspace.protos.foo:$E1_ORIGIN_PORT/novedades/ | grep -q 'FLAG{'"
  resumen "Ej1"
}

solucion_ej1() {
  tit "Ej1 - resolución"
  cat <<EOF
  1) El index del hackerspace se alcanza SOLO por el proxy (su nombre lo conoce el proxy,
     no tu resolver). Como con socks5h, el que resuelve el nombre es el proxy:

     curl -x http://ej1.protos.foo:$E1_PROXY_PORT http://hackerspace.protos.foo:$E1_ORIGIN_PORT/

     Ahi ves las credenciales de miembro (debsec / hackerspace) y el link /novedades/.

  2) El tablon /novedades/ pide Basic auth -> lo pasás con -u:

     curl -x http://ej1.protos.foo:$E1_PROXY_PORT -u $E1_MEMBER_USER:$E1_MEMBER_PASS \\
          http://hackerspace.protos.foo:$E1_ORIGIN_PORT/novedades/

     El ultimo anuncio es la FLAG{...}.

  Nota: -x con un proxy HTTP manda el pedido en "forma absoluta" (GET http://host/ ...).
  socks5h:// haria lo mismo con un proxy SOCKS resolviendo el nombre del lado del proxy;
  socks5:// (sin h) resolveria el nombre de TU lado (y aca fallaria, igual que el directo).
EOF
}

limpiar_ej1() {
  sudo squid -f "$SQUID_CONF" -k shutdown 2>/dev/null
  sleep 1; sudo pkill -f "squid -f $SQUID_CONF" 2>/dev/null
  sudo rm -f "$SQUID_CONF" "$SQUID_HOSTS"
  sudo rm -f /etc/nginx/sites-enabled/parcial-ej1 "$E1_NGINX" "$E1_HTPASS"
  sudo rm -rf "$SRV/ej1"
  sudo sed -i '/^# --- PARCIAL-2026-2C-EJ1/,/^# --- FIN PARCIAL-2026-2C-EJ1/d' /etc/hosts
  need_nginx_reload
}

# ============================================================ EJ2
montar_ej2() {
  limpiar_ej2 >/dev/null 2>&1
  paso "Ej2: nginx vhost por Host (google.com) + interno (secrethost->:$E2_BACK_PORT) + SSH pepito"

  sudo install -d "$E2_ROOT" "$E2_ROOT/sec" "$E2_BACK"
  sudo tee "$E2_ROOT/index.html" >/dev/null <<'HTML'
<!doctype html><meta charset="utf-8"><title>google.com</title><h1>google.com (falso)</h1>
<p>Sitio del puerto 80, root /var/www. La clave privada esta en /sec/mykey.</p>
HTML

  # clave de pepito, protegida con passphrase; la privada queda servida en /sec/mykey
  sudo rm -f /tmp/pepito_key /tmp/pepito_key.pub
  sudo ssh-keygen -q -t ed25519 -N "$E2_PASSPHRASE" -C "pepito@secrethost" -f /tmp/pepito_key
  sudo install -m 644 /tmp/pepito_key "$E2_ROOT/sec/mykey"
  sudo chown -R www-data:www-data "$SRV/ej2"

  # backend interno (:8000) con la passphrase
  sudo tee "$E2_BACK/index.html" >/dev/null <<EOF
<!doctype html><meta charset="utf-8"><title>secrethost interno</title>
<h1>host interno (127.0.0.1:$E2_BACK_PORT)</h1>
<p>Contenido NO accesible directo desde afuera.</p>
<p>La passphrase de la clave privada de pepito es: <b>$E2_PASSPHRASE</b></p>
EOF
  sudo chown -R www-data:www-data "$E2_BACK"

  sudo tee "$E2_NGINX" >/dev/null <<EOF
# vhost "google.com" en :80 (se elige por el header Host)
server {
    listen 80;
    server_name google.com;
    root $E2_ROOT;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
}
# backend interno en loopback:$E2_BACK_PORT
server {
    listen 127.0.0.1:$E2_BACK_PORT;
    server_name secrethost;
    root $E2_BACK;
    index index.html;
}
# proxy en :81 que reenvia al backend interno (se elige por Host: secrethost)
server {
    listen 81;
    server_name secrethost;
    location / { proxy_pass http://127.0.0.1:$E2_BACK_PORT/; }
}
EOF
  sudo ln -sf "$E2_NGINX" /etc/nginx/sites-enabled/parcial-ej2
  need_nginx_reload

  # usuario pepito con la clave publica autorizada
  id "$E2_SSH_USER" >/dev/null 2>&1 || sudo useradd -m -s /bin/bash "$E2_SSH_USER"
  sudo install -d -m 700 -o "$E2_SSH_USER" -g "$E2_SSH_USER" "/home/$E2_SSH_USER/.ssh"
  sudo install -m 600 -o "$E2_SSH_USER" -g "$E2_SSH_USER" /tmp/pepito_key.pub "/home/$E2_SSH_USER/.ssh/authorized_keys"
  sudo rm -f /tmp/pepito_key /tmp/pepito_key.pub

  tit "Montado. Consigna:"
  cat <<EOF
  El host tiene nginx con vhost google.com en :80 (root /var/www) y un vhost interno
  "secrethost" en :81 que reenvia a 127.0.0.1:$E2_BACK_PORT. Ademas, SSH solo acepta a
  "pepito" con clave privada, guardada en /sec/mykey, pero con passphrase.
  Extrae la clave, consegui la passphrase y entra por SSH como pepito.
EOF
}

verificar_ej2() {
  tit "Ej2 - vhosts + reverse proxy + SSH con passphrase"
  local tmp; tmp=$(mktemp -d)
  curl -s --retry 3 --retry-connrefused --max-time 8 http://127.0.0.1/sec/mykey -H "Host: google.com" -o "$tmp/mykey"
  chk "la clave se baja por el vhost google.com (:80, Host header)" \
      bash -c "head -1 '$tmp/mykey' | grep -q 'BEGIN OPENSSH PRIVATE KEY'"
  chmod 600 "$tmp/mykey" 2>/dev/null   # ssh-keygen/ssh rechazan la clave con permisos abiertos (paso 2 de la consigna)
  chk "la clave privada esta protegida con passphrase" \
      bash -c "! ssh-keygen -y -P '' -f '$tmp/mykey' >/dev/null 2>&1"
  local pass; pass=$(curl -s --retry 3 --retry-connrefused --max-time 8 http://127.0.0.1:81/ -H "Host: secrethost" | grep -oE 'pepito es: <b>[^<]+' | sed 's/.*<b>//')
  chk "la passphrase se obtiene por el proxy interno (:81, Host secrethost)" \
      test -n "$pass"
  chk "esa passphrase realmente abre la clave" \
      bash -c "ssh-keygen -y -P '$pass' -f '$tmp/mykey' >/dev/null 2>&1"
  chmod 600 "$tmp/mykey" 2>/dev/null
  if [ -n "$pass" ]; then
    local derived authk
    derived=$(ssh-keygen -y -P "$pass" -f "$tmp/mykey" 2>/dev/null | awk '{print $1" "$2}')
    authk=$(sudo awk '{print $1" "$2}' "/home/$E2_SSH_USER/.ssh/authorized_keys" 2>/dev/null)
    chk "la clave corresponde al authorized_keys de pepito (login valido)" \
        bash -c "[ -n '$derived' ] && [ \"$derived\" = \"$authk\" ]"
  fi
  rm -rf "$tmp" 2>/dev/null; rmdir "$tmp" 2>/dev/null
  resumen "Ej2"
}

solucion_ej2() {
  tit "Ej2 - resolución"
  cat <<EOF
  1) Bajar la clave privada (vhost del :80, se elige con el Host header):
       curl http://127.0.0.1/sec/mykey -H "Host: google.com" -o mykey
       head -1 mykey   # -----BEGIN OPENSSH PRIVATE KEY-----
  2) Permisos estrictos (ssh rechaza claves con permisos abiertos):
       chmod 600 mykey
  3) La passphrase esta en el host interno, que llega por el proxy del :81:
       curl http://127.0.0.1:81/ -H "Host: secrethost"
       # -> "La passphrase ... es: $E2_PASSPHRASE"
  4) Entrar por SSH como pepito (cuando pida passphrase, poner la del paso 3):
       ssh -i mykey $E2_SSH_USER@127.0.0.1
EOF
}

limpiar_ej2() {
  sudo rm -f /etc/nginx/sites-enabled/parcial-ej2 "$E2_NGINX"
  sudo rm -rf "$SRV/ej2"
  sudo userdel -r "$E2_SSH_USER" 2>/dev/null
  need_nginx_reload
}

# ============================================================ EJ3
montar_ej3() {
  limpiar_ej3 >/dev/null 2>&1
  paso "Ej3: casilla de correo para practicar SMTP y POP3 a mano"
  id "$E3_USER" >/dev/null 2>&1 || sudo useradd -m -s /bin/bash "$E3_USER"
  echo "$E3_USER:$E3_PASS" | sudo chpasswd
  # mail semilla DE friend@pdc.lab, MIME base64 (como el del parcial)
  local body; body=$(printf '%s' 'Hola, soy friend. Confirma que te llego este mail.' | base64)
  sudo tee /tmp/semilla-ej3.eml >/dev/null <<EOF
From: Friend <friend@$E3_DOMAIN>
To: <$E3_USER@$E3_DOMAIN>
Subject: Hola
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

$body
EOF
  sudo sendmail -f "friend@$E3_DOMAIN" "$E3_USER@$E3_DOMAIN" < /tmp/semilla-ej3.eml
  sudo rm -f /tmp/semilla-ej3.eml
  sleep 1
  tit "Montado. Consigna:"
  cat <<EOF
  Hay una casilla nueva:  usuario POP3 '$E3_USER', clave '$E3_PASS', dominio $E3_DOMAIN.
  a) Verifica por POP3 (:110) si llego algun mail y leelo (acordate de decodificar el base64).
  b) Manda vos un mail por SMTP a mano (nc -C 127.0.0.1 25) a $E3_USER@$E3_DOMAIN,
     con Subject 'DebSec report' y cuerpo en base64. Despues confirma por POP3 que entro.
EOF
}

verificar_ej3() {
  tit "Ej3 - SMTP + POP3 a mano"
  local md="/home/$E3_USER/Maildir"   # los mails estan en new/ (sin leer) o cur/ (ya vistos por POP3)
  chk "postfix escucha SMTP en :25" bash -c "sudo ss -tulpn | grep -q ':25 '"
  chk "dovecot escucha POP3 en :110" bash -c "sudo ss -tulpn | grep -q ':110 '"
  chk "login POP3 $E3_USER funciona" bash -c "
      printf 'USER $E3_USER\r\nPASS $E3_PASS\r\nSTAT\r\nQUIT\r\n' | nc -C -w3 127.0.0.1 110 | grep -qE '^\\+OK [0-9]'"
  chk "la casilla tiene el mail semilla de friend@pdc.lab" \
      bash -c "sudo grep -rls 'friend@$E3_DOMAIN' '$md/new' '$md/cur' 2>/dev/null | head -1 | grep -q ."
  chk "mandaste tu mail 'DebSec report' (entro a la casilla)" \
      bash -c "sudo grep -rls 'Subject: DebSec report' '$md/new' '$md/cur' 2>/dev/null | head -1 | grep -q ."
  resumen "Ej3"
}

solucion_ej3() {
  tit "Ej3 - resolución"
  cat <<EOF
  a) Leer por POP3 (:110):
       nc -C 127.0.0.1 110
       USER $E3_USER
       PASS $E3_PASS
       STAT            # cuantos mails hay
       LIST            # numero + tamanio
       RETR 1          # muestra el mail; el cuerpo viene en base64
       QUIT
     Para decodificar el cuerpo:  echo '<base64>' | base64 -d

  b) Mandar un mail a mano por SMTP (:25). Con nc hace falta -C (CRLF):
       nc -C 127.0.0.1 25
       EHLO pdc.lab
       MAIL FROM:<$E3_USER@$E3_DOMAIN>
       RCPT TO:<$E3_USER@$E3_DOMAIN>
       DATA
       From: DebSec <$E3_USER@$E3_DOMAIN>
       To: <$E3_USER@$E3_DOMAIN>
       Subject: DebSec report
       Content-Type: text/plain; charset=UTF-8
       Content-Transfer-Encoding: base64

       $(printf '%s' 'ok, todo en orden' | base64)
       .
       QUIT
     El servidor responde "250 ... queued" recien cuando mandás la linea del punto solo.
EOF
}

limpiar_ej3() {
  sudo userdel -r "$E3_USER" 2>/dev/null
}

# ============================================================ EJ4
montar_ej4() {
  limpiar_ej4 >/dev/null 2>&1
  paso "Ej4: reconstruir la zona DNS $E4_ZONE desde una captura PCAP"
  if [ ! -f "$BASE/ej4/backup.pcap" ]; then
    info "falta $BASE/ej4/backup.pcap (sincronizá el repo con rsync a la VM)"; return 1
  fi
  # servidor http para "descargar" la captura, como en el parcial (corre como vos, no www-data)
  nohup python3 -m http.server "$E4_DL_PORT" --bind 127.0.0.1 --directory "$BASE/ej4" \
        >/tmp/parcial-ej4-http.log 2>&1 &
  echo $! > "$E4_DL_PID"
  sleep 1
  tit "Montado. Consigna:"
  cat <<EOF
  Cachito borro la config de la zona DNS y no hay backups. Por suerte quedo una captura
  con queries y replies del namemaster. Bajala, reconstrui la zona "$E4_ZONE" con bind9
  y agrega un TXT que diga "cachito tiene prohibido editar este archivo".

    curl -O http://127.0.0.1:$E4_DL_PORT/backup.pcap
    wireshark backup.pcap        # (la GUI no tiene el perfil AppArmor que molesta a tshark)

  La zona va en:  $E4_ZONEFILE   y la declarás en /etc/bind/named.conf.local
  Verifica con:   dig @127.0.0.1 $E4_ZONE  (y cada nombre de la captura); tienen que traer 'aa'.
EOF
}

verificar_ej4() {
  tit "Ej4 - zona $E4_ZONE reconstruida"
  local d="dig @127.0.0.1 +norecurse +noall +answer"
  chk "la zona responde autoritativa (flag aa)" \
      bash -c "dig @127.0.0.1 +norecurse $E4_ZONE SOA | grep -q 'flags:.* aa'"
  chk "SOA serial 2018010101 (original 2018010100 + 1 por el TXT)" bash -c "$d $E4_ZONE SOA | grep -q ' 2018010101 '"
  chk "NS ns1.$E4_ZONE" bash -c "$d $E4_ZONE NS | grep -q 'ns1.$E4_ZONE.'"
  chk "A de @ -> $E4_IP" bash -c "$d $E4_ZONE A | grep -q '$E4_IP'"
  chk "A de ns1 -> $E4_IP" bash -c "$d ns1.$E4_ZONE A | grep -q '$E4_IP'"
  chk "A de mail -> $E4_IP" bash -c "$d mail.$E4_ZONE A | grep -q '$E4_IP'"
  chk "MX 10 mail.$E4_ZONE" bash -c "$d $E4_ZONE MX | grep -qE '10[[:space:]]+mail.$E4_ZONE'"
  chk "www es CNAME a @" bash -c "$d www.$E4_ZONE CNAME | grep -q '$E4_ZONE.'"
  chk "TXT meme conserva su TTL 864000" bash -c "$d $E4_ZONE TXT | awk '/meme/{print \$2}' | grep -qx 864000"
  chk "TXT nuevo: 'cachito tiene prohibido editar este archivo'" \
      bash -c "$d $E4_ZONE TXT | grep -qi 'prohibido editar'"
  chk "nombre inexistente -> NXDOMAIN" \
      bash -c "dig @127.0.0.1 +norecurse noexiste.$E4_ZONE A | grep -q 'status: NXDOMAIN'"
  resumen "Ej4"
}

solucion_ej4() {
  tit "Ej4 - resolución (te dejo la zona aplicada)"
  sudo install -d -o root -g bind /etc/bind/zones
  sudo tee "$E4_ZONEFILE" >/dev/null <<EOF
\$TTL 3600
\$ORIGIN $E4_ZONE.
@   IN  SOA ns1.$E4_ZONE. admin.$E4_ZONE. (
            2018010101 ; serial original (2018010100) + 1 por agregar el TXT
            3600 1800 1209600 300 )
@           IN  NS    ns1.$E4_ZONE.
ns1         IN  A     $E4_IP
@           IN  A     $E4_IP
www         IN  CNAME @
@           IN  MX 10 mail.$E4_ZONE.
mail        IN  A     $E4_IP
; los dos TXT de @ son el MISMO RRset (cachito.parcial/TXT): comparten UN solo TTL.
; BIND toma el del primero (864000) para ambos y avisa "TTL set to prior TTL" (es correcto).
@       864000 IN TXT "cachito meme: no toques la zona"
@              IN TXT "cachito tiene prohibido editar este archivo"
EOF
  if ! grep -q "zone \"$E4_ZONE\"" /etc/bind/named.conf.local; then
    sudo tee -a /etc/bind/named.conf.local >/dev/null <<EOF
// --- PARCIAL-2026-2C-EJ4 (lo saca parcial-2026-2c.sh limpiar ej4) ---
zone "$E4_ZONE" { type master; file "$E4_ZONEFILE"; allow-transfer { 127.0.0.1; }; notify no; };
// --- FIN PARCIAL-2026-2C-EJ4 ---
EOF
  fi
  sudo named-checkzone "$E4_ZONE" "$E4_ZONEFILE"
  sudo rndc reconfig
  echo; dig @127.0.0.1 +norecurse $E4_ZONE ANY +noall +answer 2>/dev/null
  cat <<'EOF'

  Como se saca cada cosa de la captura:
  - $TTL / TTL de cada record  = el TTL de la respuesta autoritativa (flag aa) en Wireshark.
  - SOA  = de una respuesta negativa (NXDOMAIN): viene en la seccion Authority.
           El serial sube en 1 porque agregamos un TXT.
  - A / NS / MX / CNAME / TXT = uno por cada reply que aparezca en la captura.
  - www es CNAME a @ (no un A).  El TXT "meme" tenia TTL 864000 (10 dias), distinto del resto.
EOF
}

limpiar_ej4() {
  [ -f "$E4_DL_PID" ] && { kill "$(cat "$E4_DL_PID")" 2>/dev/null; rm -f "$E4_DL_PID"; }
  pkill -u "$USER" -f "http.server $E4_DL_PORT" 2>/dev/null   # -u $USER: sólo mis procesos, nunca tu www-data
  sudo sed -i '/^\/\/ --- PARCIAL-2026-2C-EJ4/,/^\/\/ --- FIN PARCIAL-2026-2C-EJ4/d' /etc/bind/named.conf.local
  sudo rm -f "$E4_ZONEFILE" "$E4_ZONEFILE.jnl"
  sudo rndc reconfig 2>/dev/null
}

# ============================================================ dispatcher
EJ="${2:-todo}"
accion() { # accion <verbo> <ej>
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
  solucion)  accion solucion "$EJ";;
  *) sed -n '2,20p' "$0"; exit 1;;
esac

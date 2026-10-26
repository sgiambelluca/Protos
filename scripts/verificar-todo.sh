#!/usr/bin/env bash
# ============================================================
# verificar-todo.sh  -  chequea que cada ejercicio configurado funcione
# Uso:  ~/Protos/scripts/verificar-todo.sh
# Cada línea dice OK o FALLA y qué comando la prueba (para repetirlo a mano).
# ============================================================

ok=0; mal=0
chk() {  # chk "descripción" comando...   (OK si el comando sale con 0)
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then printf '  \033[32mOK   \033[0m %s\n' "$desc"; ok=$((ok+1))
    else printf '  \033[31mFALLA\033[0m %s\n' "$desc"; mal=$((mal+1)); fi
}
tit() { printf '\n\033[1m%s\033[0m\n' "$*"; }
contiene() { grep -q -- "$1"; }   # stdin contiene $1

# ------------------------------------------------------------
tit "Servicios"
for s in nginx named postfix dovecot xinetd ssh protos-python-http systemd-resolved; do
    chk "servicio $s activo                (systemctl status $s)" systemctl is-active --quiet "$s"
done

# ------------------------------------------------------------
tit "Guía 2 - HTTP / nginx"
chk "nginx -t sin errores" sudo nginx -t
chk "E36 Host: foo  -> Bienvenido a Foo  (curl -H 'Host: foo' http://127.0.0.1/)" \
    bash -c "curl -s -H 'Host: foo' http://127.0.0.1/ | grep -q 'Bienvenido a Foo' || curl -s -H 'Host: foo' http://127.0.0.1/ | grep -q 'Hola mundo'"
chk "E36 Host: bar  -> Bienvenido a Bar" bash -c "curl -s -H 'Host: bar' http://127.0.0.1/ | grep -q 'Bienvenido a Bar'"
chk "E36 por IP     -> What?             (curl http://10.0.2.15/)" bash -c "curl -s http://10.0.2.15/ | grep -q 'What?'"
chk "E36 Host: cualquiera -> What?" bash -c "curl -s -H 'Host: nadie' http://127.0.0.1/ | grep -q 'What?'"
chk "E37 /etc/hosts resuelve foo         (getent hosts foo)" getent hosts foo
chk "E37 http://foo/ por nombre" bash -c "curl -s http://foo/ | grep -qE 'Bienvenido a Foo|Hola mundo'"
chk "E39 backend Python 127.0.0.1:8080   (curl http://127.0.0.1:8080/)" bash -c "curl -s http://127.0.0.1:8080/ | grep -q 'Hola mundo'"
chk "E40 gzip en foo  (curl -sI -H 'Accept-Encoding: gzip' -H 'Host: foo' http://127.0.0.1/grande.html)" \
    bash -c "curl -sI -H 'Accept-Encoding: gzip' -H 'Host: foo' http://127.0.0.1/grande.html | grep -qi '^Content-Encoding: gzip'"
chk "E40 gzip en bar" \
    bash -c "curl -sI -H 'Accept-Encoding: gzip' -H 'Host: bar' http://127.0.0.1/grande.html | grep -qi '^Content-Encoding: gzip'"
chk "E41 https://foo/ con certificado válido (curl https://foo/)" bash -c "curl -sf https://foo/ >/dev/null"

# ------------------------------------------------------------
tit "Guía 3 - DNS / bind9"
chk "named-checkconf -z (config + todas las zonas)" sudo named-checkconf -z
chk "E50 SOA foo.pdc.lab               (dig @127.0.0.1 foo.pdc.lab SOA)" bash -c "dig +short @127.0.0.1 foo.pdc.lab SOA | grep -q ns1.foo.pdc.lab"
chk "E50 NS  foo.pdc.lab" bash -c "dig +short @127.0.0.1 foo.pdc.lab NS | grep -q ns1.foo.pdc.lab"
chk "E50 MX  foo.pdc.lab" bash -c "dig +short @127.0.0.1 foo.pdc.lab MX | grep -q '10 mail.foo.pdc.lab'"
chk "E50 A   ubuntua.foo.pdc.lab" bash -c "dig +short @127.0.0.1 ubuntua.foo.pdc.lab A | grep -q 10.0.2.15"
chk "E50 CNAME vm.foo.pdc.lab" bash -c "dig +short @127.0.0.1 vm.foo.pdc.lab | grep -q ubuntua.foo.pdc.lab"
chk "E50 TTL propio www (30s)" bash -c "dig +noall +answer @127.0.0.1 www.foo.pdc.lab | grep -qE '\s30\s'"
chk "E50 inversa 10.0.2.15             (dig @127.0.0.1 -x 10.0.2.15)" bash -c "dig +short @127.0.0.1 -x 10.0.2.15 | grep -q ubuntua.foo.pdc.lab"
chk "zona de clase pepito.com carga" bash -c "dig +short @127.0.0.1 pepito.com MX | grep -q smtp.pepito.com"
chk "zona de clase cachito.com carga" bash -c "dig +short @127.0.0.1 cachito.com SOA | grep -q ns1.cachito.com"
chk "named hace recursión (google.com)" bash -c "dig +short @127.0.0.1 google.com A | grep -qE '^[0-9.]+$'"
chk "E53 resolved usa 127.0.0.1         (resolvectl status)" bash -c "resolvectl status | grep -A3 '^Global' | grep -q '127.0.0.1'"
chk "E53 el sistema resuelve foo.pdc.lab por bind (getent hosts foo.pdc.lab)" bash -c "getent hosts foo.pdc.lab | grep -q 10.0.2.15"
chk "E48 alt.foo.pdc.lab -> 302 a protos.foo (curl -sI http://alt.foo.pdc.lab/)" \
    bash -c "curl -sI http://alt.foo.pdc.lab/ | grep -qi '^Location: http://protos.foo/'"
codigo=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://foo.pdc.lab/)
printf '  info  E47 http://foo.pdc.lab/ devolvió HTTP %s  (502 = nginx OK pero protos.foo no responde)\n' "$codigo"

# ------------------------------------------------------------
tit "Guía 4 - Correo"
chk "SMTP postfix responde 220 en :25    (nc -C localhost 25)" bash -c "timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/25; head -c 3 <&3' | grep -q 220"
chk "POP3 dovecot responde +OK en :110   (nc -C localhost 110)" bash -c "timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/110; head -c 3 <&3' | grep -q '+OK'"
chk "postfix acepta @foo.pdc.lab        (postconf mydestination)" bash -c "postconf -h mydestination | grep -qw foo.pdc.lab"
chk "home_mailbox = Maildir/" bash -c "postconf -h home_mailbox | grep -q '^Maildir/$'"
chk "dovecot lee ~/Maildir               (doveconf mail_path)" bash -c "sudo doveconf -h mail_path | grep -q Maildir"
chk "mutt instalado y ~/.muttrc" bash -c "command -v mutt && test -f ~/.muttrc"

# ------------------------------------------------------------
tit "Guía 5/6 - xinetd (telnet, echo, daytime, time)"
chk "E71 telnet :23 ofrece login        (telnet localhost)" bash -c "(sleep 2) | timeout 4 telnet localhost 2>/dev/null | grep -qi 'login'"
chk "E75 echo TCP :7                    (nc localhost 7)" bash -c "echo hola | timeout 2 nc -q1 127.0.0.1 7 | grep -q hola"
chk "E76 echo UDP :7                    (nc -u localhost 7)" bash -c "echo hola | timeout 2 nc -u -w1 127.0.0.1 7 | grep -q hola"
chk "E72 daytime TCP :13                (nc localhost 13)" bash -c "timeout 2 nc 127.0.0.1 13 | grep -q '[0-9]'"
chk "E72 time TCP :37                   (nc localhost 37 | xxd)" bash -c "timeout 2 nc 127.0.0.1 37 | head -c4 | wc -c | grep -q 4"

# ------------------------------------------------------------
tit "Guía 11 - SSH"
chk "E100 ssh localhost sin contraseña  (ssh localhost)" ssh -o BatchMode=yes -o ConnectTimeout=3 localhost true

printf '\nResultado: %d OK, %d FALLA\n' "$ok" "$mal"
[ "$mal" -eq 0 ]

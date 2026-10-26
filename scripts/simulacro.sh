#!/usr/bin/env bash
# ============================================================
# simulacro.sh  -  practicar en ESTA VM el simulacro de parcial (apuntes/17-simulacro.md)
#
# Uso:  ~/Protos/scripts/simulacro.sh montar | verificar | limpiar
#
#   montar     levanta lo que en el parcial pone la cátedra:
#                Ej 1  la zona ROTA sucursal.foo cargada en bind (/etc/bind/zones/db.sucursal.foo)
#                Ej 2  el backend http://interno.protos.foo (otro server de nginx)
#                Ej 3  http://recurso.protos.foo:8080/data/ con Basic auth y negociación de
#                      contenido, y un proxy SOCKS en proxy.protos.foo:1080 (ssh -D a localhost)
#                Ej 5  /tmp/pdc, que se escribe solo cada 2 s (localhost hace de pampero)
#   verificar  corrige lo que hiciste: OK / FALLA por cada requisito
#   limpiar    saca lo de montar Y tu solución en las rutas de la resolución (sitio "seguro",
#              su certificado y la línea de seguro.protos.foo en /etc/hosts). Los mails quedan.
#
# El Ej 4 (DHCP) se practica con:  ~/Protos/scripts/practicar-dhcp.sh tu-dhcpd.conf
# El Ej 6 necesita la red del laboratorio.
# Mientras está montado, verificar-todo.sh da FALLA en "named-checkconf -z" hasta que
# arregles la zona (es lo esperable: la zona rota es el ejercicio).
# ============================================================
set -uo pipefail

SIM="$HOME/Protos/ejercicios/simulacro"
ZONA=/etc/bind/zones/db.sucursal.foo
PDC_PID=/tmp/simulacro-pdc.pid
SOCKS_CMD='ssh -fN -o BatchMode=yes -o ExitOnForwardFailure=yes -D 1080 localhost'

paso() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
tit()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
info() { printf '  info  %s\n' "$*"; }
ok=0; mal=0
chk() {  # chk "descripción" comando...   (OK si el comando sale con 0)
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then printf '  \033[32mOK   \033[0m %s\n' "$desc"; ok=$((ok+1))
    else printf '  \033[31mFALLA\033[0m %s\n' "$desc"; mal=$((mal+1)); fi
}

# ------------------------------------------------------------
sacar_entorno() {   # deshace "montar" (no toca tu solución ni recarga nginx)
    sudo sed -i '/^# --- SIMULACRO/,/^# --- FIN SIMULACRO/d' /etc/hosts
    if grep -q '^// --- SIMULACRO' /etc/bind/named.conf.local; then
        sudo sed -i '/^\/\/ --- SIMULACRO/,/^\/\/ --- FIN SIMULACRO/d' /etc/bind/named.conf.local
        sudo rndc reconfig          # bind deja de servir sucursal.foo
    fi
    sudo rm -f "$ZONA" "$ZONA.jnl"
    sudo rm -f /etc/nginx/sites-enabled/sim-interno /etc/nginx/sites-enabled/sim-recurso \
               /etc/nginx/sites-available/sim-interno /etc/nginx/sites-available/sim-recurso \
               /etc/nginx/simulacro.htpasswd
    sudo rm -rf /srv/simulacro
    pkill -f "^$SOCKS_CMD" 2>/dev/null
    if [ -f "$PDC_PID" ]; then kill "$(cat "$PDC_PID")" 2>/dev/null; rm -f "$PDC_PID"; fi
    rm -f /tmp/pdc
}

montar() {
    sacar_entorno                 # por si quedó algo de una vuelta anterior

    paso "Ej 1: zona ROTA sucursal.foo en bind"
    sudo install -m 644 -o root -g bind "$SIM/ej1-db.sucursal.foo-ORIGINAL-con-errores.db" "$ZONA"
    sudo tee -a /etc/bind/named.conf.local >/dev/null <<EOF
// --- SIMULACRO (lo agrega/saca ~/Protos/scripts/simulacro.sh) ---
zone "sucursal.foo" {
	type master;
	file "$ZONA";
	notify no;      // en la VM no hay secundarios (y así no le manda NOTIFY a 192.168.50.1, que no es nuestra)
};
// --- FIN SIMULACRO ---
EOF
    sudo rndc reconfig
    sudo named-checkzone sucursal.foo "$ZONA" | tail -n 2     # tiene que fallar: ese es el ejercicio

    paso "Ej 2 y 3: nombres de la cátedra en /etc/hosts"
    sudo tee -a /etc/hosts >/dev/null <<'EOF'
# --- SIMULACRO (lo agrega/saca ~/Protos/scripts/simulacro.sh) ---
127.0.0.1   interno.protos.foo proxy.protos.foo
127.0.0.2   recurso.protos.foo
# --- FIN SIMULACRO ---
EOF
    getent hosts interno.protos.foo recurso.protos.foo

    paso "Ej 2 y 3: servidores de la cátedra en nginx (sim-interno, sim-recurso)"
    sudo install -m 644 "$SIM/catedra/nginx-sim-interno" /etc/nginx/sites-available/sim-interno
    sudo install -m 644 "$SIM/catedra/nginx-sim-recurso" /etc/nginx/sites-available/sim-recurso
    sudo ln -sf /etc/nginx/sites-available/sim-interno /etc/nginx/sites-enabled/sim-interno
    sudo ln -sf /etc/nginx/sites-available/sim-recurso /etc/nginx/sites-enabled/sim-recurso
    sudo mkdir -p /srv/simulacro
    sudo cp -r "$SIM/catedra/recurso" /srv/simulacro/
    printf 'admin:%s\n' "$(openssl passwd -apr1 secret123)" | sudo tee /etc/nginx/simulacro.htpasswd >/dev/null
    sudo chown root:www-data /etc/nginx/simulacro.htpasswd
    sudo chmod 640 /etc/nginx/simulacro.htpasswd
    sudo nginx -t -q && sudo systemctl reload nginx && sleep 1

    paso "Ej 3: proxy SOCKS en proxy.protos.foo:1080 (ssh -D a localhost)"
    $SOCKS_CMD </dev/null >/dev/null 2>&1 \
        && echo "escuchando en 127.0.0.1:1080" \
        || echo "no pude levantarlo: ¿'ssh localhost' pide contraseña? ¿el 1080 está ocupado? (ss -ltnp)"

    paso "Ej 5: /tmp/pdc se escribe solo cada 2 segundos"
    nohup bash -c 'while :; do date "+%T  línea nueva en /tmp/pdc" >> /tmp/pdc; sleep 2; done' \
        </dev/null >/dev/null 2>&1 &
    echo $! > "$PDC_PID"

    paso "Listo. Resolvé los enunciados de apuntes/17-simulacro.md. En esta VM:"
    cat <<'EOF'
  Ej 1  la zona está en /etc/bind/zones/db.sucursal.foo (journalctl -u named -n 20: por qué no carga)
  Ej 2  el backend es http://interno.protos.foo   ->  armá https://seguro.protos.foo
  Ej 3  proxy socks5h://proxy.protos.foo:1080, recurso http://recurso.protos.foo:8080/data/
  Ej 4  ~/Protos/scripts/practicar-dhcp.sh tu-dhcpd.conf
  Ej 5  pampero = localhost. Como es la MISMA máquina, el puerto local tiene que ser otro
        (por ejemplo, nc -l en 8099 y ssh -R 6402:localhost:8099 localhost ...)
  Ej 7  nc -C localhost 25, al usuario local (RCPT TO:<sgiambelluca@pdc.lab>); leerlo con mutt o POP3
Al terminar:  ~/Protos/scripts/simulacro.sh verificar
EOF
}

# ------------------------------------------------------------
# chequeos del Ej 1 (usan las variables que llena verificar)
rname_ok()    { [ -n "$rname" ] && [[ "$rname" != *@* ]]; }
mname_es_ns() { [ -n "$mname" ] && grep -qxF "$mname" <<< "$ns"; }
tiempos_ok()  { [ -n "$refresh" ] && [ "$refresh" -le 86400 ] && [ "$minimo" -le 3600 ]; }
expire_ok()   { [ -n "$expire" ] && [ "$expire" -gt $((refresh + retry)) ]; }
mx_ok() {
    local destino
    destino=$(dig +short @127.0.0.1 sucursal.foo MX | awk '{print $2}' | head -1)
    [ -n "$destino" ] && dig +short @127.0.0.1 "$destino" A | grep -qE '^[0-9.]+$'
}
# chequeos del Ej 2
cert_san_ok() {
    openssl s_client -connect 127.0.0.1:443 -servername seguro.protos.foo </dev/null 2>/dev/null \
        | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -q 'DNS:seguro.protos.foo'
}
# chequeos del Ej 7 (sobre el último mail con X-Parcial: 2026/2)
cuerpo_ok() { awk 'f; /^$/ {f=1}' "$mail" | base64 -d 2>/dev/null | grep -q '¡Hola mundo!'; }
sin_qp()    { [ -n "$mail" ] && ! grep -qi 'quoted-printable' "$mail"; }

verificar() {
    tit "Ej 1 - zona sucursal.foo"
    chk "named-checkzone sin errores    (sudo named-checkzone sucursal.foo $ZONA)" \
        sudo named-checkzone sucursal.foo "$ZONA"
    chk "bind la sirve con autoridad, flag aa   (dig @127.0.0.1 sucursal.foo SOA)" \
        bash -c "dig +norec @127.0.0.1 sucursal.foo SOA | grep -q 'flags:.* aa'"
    read -r mname rname serial refresh retry expire minimo <<< "$(dig +short @127.0.0.1 sucursal.foo SOA)"
    ns=$(dig +short @127.0.0.1 sucursal.foo NS)
    chk "serial subido (era 2026010501, ahora ${serial:-?})" test "${serial:-0}" -gt 2026010501
    chk "mail del responsable con '.' y no '@' (${rname:-?})" rname_ok
    chk "MNAME del SOA (${mname:-?}) es uno de los NS" mname_es_ns
    chk "refresh <= 1 día (${refresh:-?}) y negative TTL <= 1 h (${minimo:-?})" tiempos_ok
    chk "expire (${expire:-?}) > refresh + retry" expire_ok
    chk "www.sucursal.foo resuelve a una IP   (dig @127.0.0.1 www.sucursal.foo)" \
        bash -c "dig +short @127.0.0.1 www.sucursal.foo A | grep -qE '^[0-9.]+$'"
    chk "el MX apunta a un nombre que tiene A" mx_ok

    tit "Ej 2 - https://seguro.protos.foo sirve lo de http://interno.protos.foo"
    chk "(entorno) interno.protos.foo responde" \
        bash -c "curl -s http://interno.protos.foo/ | grep -q 'Contenido de interno'"
    chk "seguro.protos.foo resuelve   (getent hosts seguro.protos.foo)" getent hosts seguro.protos.foo
    chk "curl https://seguro.protos.foo SIN flags trae lo de interno" \
        bash -c "curl -s https://seguro.protos.foo/ | grep -q 'Contenido de interno'"
    chk "es proxy y no redirect: HTTP 200, la URL no cambia" \
        bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' https://seguro.protos.foo/)\" = 200 ]"
    chk "el certificado tiene SAN DNS:seguro.protos.foo (lo exigen los navegadores)" cert_san_ok

    tit "Ej 3 - curl por SOCKS a recurso.protos.foo (chequea el entorno; tu comando está en el apunte)"
    chk "(entorno) proxy SOCKS escuchando en 127.0.0.1:1080" bash -c "ss -ltn | grep -q '127.0.0.1:1080 '"
    chk "(entorno) sin credenciales -> 401" \
        bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -x socks5h://proxy.protos.foo:1080 http://recurso.protos.foo:8080/data/)\" = 401 ]"
    chk "(entorno) text/plain + es + Basic auth -> la versión en español" \
        bash -c "curl -s -x socks5h://proxy.protos.foo:1080 -u admin:secret123 -H 'Accept: text/plain' -H 'Accept-Language: es' http://recurso.protos.foo:8080/data/ | grep -q 'texto plano y en español'"
    info "acá socks5:// (sin h) también anda porque la VM resuelve recurso.protos.foo; en el parcial no"

    tit "Ej 5 - túnel SSH + tail -f"
    chk "(entorno) /tmp/pdc se está escribiendo" bash -c "[ -f '$PDC_PID' ] && kill -0 \$(cat '$PDC_PID')"
    if ss -ltn | grep -q ':6402 '; then info "hay algo escuchando en el 6402 (¿tu túnel -R?)"
    else info "nada escucha en el 6402 ahora (normal si ya cerraste el túnel)"; fi
    info "se corrige a ojo: tail -f archivo.log tiene que mostrar una línea nueva cada 2 s"

    tit "Ej 7 - mail (el último que llegó a ~/Maildir con X-Parcial: 2026/2)"
    mail=$(grep -rl '^X-Parcial: 2026/2' ~/Maildir/new ~/Maildir/cur 2>/dev/null | xargs -r ls -t | head -1)
    chk "llegó un mail con X-Parcial: 2026/2 ${mail:+(${mail#"$HOME"/})}" test -n "$mail"
    chk "Content-Transfer-Encoding: base64" grep -qi '^Content-Transfer-Encoding: base64' "$mail"
    chk "nada en quoted-printable (requisito 6)" sin_qp
    chk "el cuerpo decodifica a ¡Hola mundo!" cuerpo_ok
    chk "Subject como encoded-word (=?UTF-8?B?...?=)" grep -qiE '^Subject: =\?utf-8\?[bq]\?' "$mail"
    chk "From con la cuenta del ITBA" grep -qiE '^From:.*@itba\.edu\.ar' "$mail"
    chk "MIME-Version y charset UTF-8" bash -c "grep -qi '^MIME-Version: 1.0' '$mail' && grep -qiE '^Content-Type: text/plain;.*charset=\"?utf-8' '$mail'"
    info "postfix agrega Date, Message-Id y From si faltan (porque venís de localhost): ponelos igual"

    printf '\nResultado: %d OK, %d FALLA\n' "$ok" "$mal"
    [ "$mal" -eq 0 ]
}

# ------------------------------------------------------------
limpiar() {
    paso "Saco el entorno del simulacro"
    sacar_entorno

    paso "Saco tu solución (las rutas de la resolución)"
    local f quitado_ca=no
    for f in /etc/nginx/sites-enabled/seguro /etc/nginx/sites-available/seguro \
             /etc/ssl/certs/seguro.crt /etc/ssl/private/seguro.key \
             /usr/local/share/ca-certificates/seguro.crt; do
        if sudo test -e "$f" -o -L "$f"; then
            sudo rm -f "$f"; echo "  borrado $f"
            [ "$f" = /usr/local/share/ca-certificates/seguro.crt ] && quitado_ca=si
        fi
    done
    # --fresh: sin él, el bundle se rehace bien pero quedan symlinks rotos (seguro.pem, <hash>.0) en /etc/ssl/certs
    [ "$quitado_ca" = si ] && sudo update-ca-certificates --fresh >/dev/null 2>&1 && echo "  almacén del sistema rehecho sin seguro.crt"
    if grep -qE '(^|[[:space:]])seguro\.protos\.foo([[:space:]]|$)' /etc/hosts; then
        sudo sed -i -E '/(^|[[:space:]])seguro\.protos\.foo([[:space:]]|$)/d' /etc/hosts
        echo "  borrada la línea de seguro.protos.foo en /etc/hosts"
    fi

    sudo nginx -t -q && sudo systemctl reload nginx
    echo "Listo. Los mails de prueba quedan en ~/Maildir."
}

case "${1:-}" in
    montar)    montar ;;
    verificar) verificar ;;
    limpiar)   limpiar ;;
    *)         sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

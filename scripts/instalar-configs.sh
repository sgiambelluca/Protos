#!/usr/bin/env bash
# ============================================================
# instalar-configs.sh  -  (re)aplica TODAS las configuraciones de práctica
#
# Copia ~/Protos/config/* a su lugar en /etc, /var/www, /srv, y recarga
# los servicios. Es idempotente: se puede correr varias veces.
# Úsalo si rompiste algo practicando y querés volver al estado "bueno".
#
# OJO: PISA los archivos de /etc que están en ~/Protos/config/
# (nginx foo/bar/what/..., bind named.conf.*, zonas, xinetd telnetd).
# Los originales de antes del 26/10 están en ~/Protos/backups-originales/
#
# Uso:   ~/Protos/scripts/instalar-configs.sh
# ============================================================
set -euo pipefail

P="$HOME/Protos"
C="$P/config"
paso() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# ------------------------------------------------------------
paso "nginx (Guía 2 E36-E41, Guía 3 E47-E48)"
sudo install -m 644 "$C/etc/nginx/snippets/protos-gzip.conf" /etc/nginx/snippets/
for s in foo foo-proxy bar what foo.pdc.lab alt.foo.pdc.lab; do
    sudo install -m 644 "$C/etc/nginx/sites-available/$s" /etc/nginx/sites-available/
done
for d in foo bar what; do
    sudo install -d -m 755 "/var/www/$d"
    sudo install -m 644 "$C/var/www/$d/"*.html "/var/www/$d/"
done

# E41: CA local + certificado para "foo" con mkcert
if [ ! -f "$(mkcert -CAROOT)/rootCA.pem" ]; then
    mkcert -install                       # crea la CA y la instala en el sistema y en Firefox
fi
if [ ! -f /etc/nginx/ssl/foo.pem ]; then
    tmp=$(mktemp -d)
    (cd "$tmp" && mkcert foo)             # genera foo.pem (público) y foo-key.pem (privado)
    sudo install -d -m 755 /etc/nginx/ssl
    sudo install -m 644 "$tmp/foo.pem"     /etc/nginx/ssl/foo.pem
    sudo install -m 600 "$tmp/foo-key.pem" /etc/nginx/ssl/foo-key.pem
    rm -rf "$tmp"
fi

# Firefox de Ubuntu es un snap: mkcert no siempre encuentra su perfil.
# Se agrega la CA a mano en cada perfil con certutil (libnss3-tools).
for prof in "$HOME"/snap/firefox/common/.mozilla/firefox/*.default*; do
    [ -f "$prof/cert9.db" ] || continue
    certutil -A -d "sql:$prof" -t "C,," -n "mkcert CA (Protos)" -i "$(mkcert -CAROOT)/rootCA.pem" || true
done

# habilitar sitios (symlinks en sites-enabled). foo arranca en modo estático.
cd /etc/nginx/sites-enabled
sudo rm -f default                                  # tenía default_server -> chocaba con "what"
for s in foo bar what foo.pdc.lab alt.foo.pdc.lab; do
    sudo ln -sfn "/etc/nginx/sites-available/$s" "$s"
done
cd - >/dev/null
sudo nginx -t
sudo systemctl reload nginx

# ------------------------------------------------------------
paso "backend Python para el proxy reverso (Guía 2 E39)"
sudo install -d -m 755 /srv/protos-python
sudo install -m 644 "$C/srv/protos-python/index.html" /srv/protos-python/
sudo install -m 644 "$C/etc/systemd/system/protos-python-http.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now protos-python-http.service

# ------------------------------------------------------------
paso "bind9 (Guía 3 E50-E54)"
sudo install -m 644 -o root -g bind "$C/etc/bind/named.conf.options" /etc/bind/
sudo install -m 644 -o root -g bind "$C/etc/bind/named.conf.local"   /etc/bind/
for z in db.foo.pdc.lab db.10.0.2 db.cachito.com.local; do
    sudo install -m 644 -o root -g bind "$C/etc/bind/zones/$z" /etc/bind/zones/
done
sudo named-checkconf -z
sudo systemctl reload named

# ------------------------------------------------------------
paso "systemd-resolved usa nuestro bind como DNS (Guía 3 E53)"
sudo install -d -m 755 /etc/systemd/resolved.conf.d
sudo install -m 644 "$C/etc/systemd/resolved.conf.d/protos-bind.conf" /etc/systemd/resolved.conf.d/
sudo systemctl restart systemd-resolved

# ------------------------------------------------------------
paso "/etc/hosts: foo y bar (Guía 2 E37)"
if ! grep -q 'PROTOS-E37' /etc/hosts; then
    sudo tee -a /etc/hosts >/dev/null <<'EOF'

# --- PROTOS-E37: nombres de los virtual hosts de nginx (Guía 2) ---
# (foo.pdc.lab NO va acá a propósito: lo resuelve nuestro bind, Guía 3 E47)
127.0.0.1   foo bar
EOF
fi

# ------------------------------------------------------------
paso "xinetd: telnet (Guía 5 E71)"
sudo install -m 644 "$C/etc/xinetd.d/telnetd" /etc/xinetd.d/telnetd
sudo systemctl restart xinetd

# ------------------------------------------------------------
paso "postfix: aceptar mail para @foo.pdc.lab (Guía 4)"
if ! postconf -h mydestination | grep -qw 'foo.pdc.lab'; then
    sudo postconf -e "mydestination = $(postconf -h mydestination), foo.pdc.lab"
    sudo systemctl reload postfix
fi

# ------------------------------------------------------------
paso "mutt (Guía 4 E59-E60)"
[ -f "$HOME/.muttrc" ] || install -m 600 "$C/home/muttrc" "$HOME/.muttrc"

# ------------------------------------------------------------
paso "SSH sin contraseña a localhost (Guía 11 E100)"
[ -f "$HOME/.ssh/id_ed25519" ] || ssh-keygen -t ed25519 -N "" -C "sgiambelluca@UbuntuA (Protos E100)" -f "$HOME/.ssh/id_ed25519" -q
grep -qF "$(cut -d' ' -f2 "$HOME/.ssh/id_ed25519.pub")" "$HOME/.ssh/authorized_keys" 2>/dev/null \
    || cat "$HOME/.ssh/id_ed25519.pub" >> "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
ssh-keygen -F localhost >/dev/null || ssh-keyscan -t ed25519 localhost 2>/dev/null >> "$HOME/.ssh/known_hosts"

paso "Listo. Ahora corré:  ~/Protos/scripts/verificar-todo.sh"

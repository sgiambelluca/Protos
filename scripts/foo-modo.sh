#!/usr/bin/env bash
# ============================================================
# foo-modo.sh  -  cambia el sitio "foo" de nginx entre:
#   estatico : sirve /var/www/foo ("Bienvenido a Foo")      (Guía 2 E36)
#   proxy    : proxy reverso a Python en 127.0.0.1:8080     (Guía 2 E39)
#
# No pueden estar los dos habilitados a la vez porque tienen el mismo
# server_name (nginx avisa "conflicting server name" y usa el primero).
#
# Uso:  ~/Protos/scripts/foo-modo.sh proxy
#       ~/Protos/scripts/foo-modo.sh estatico
# ============================================================
set -euo pipefail

case "${1:-}" in
    estatico) origen=/etc/nginx/sites-available/foo ;;
    proxy)    origen=/etc/nginx/sites-available/foo-proxy
              systemctl is-active --quiet protos-python-http || sudo systemctl start protos-python-http ;;
    *) echo "uso: $0 estatico|proxy"; exit 1 ;;
esac

sudo ln -sfn "$origen" /etc/nginx/sites-enabled/foo   # el symlink se sigue llamando "foo"
sudo nginx -t
sudo systemctl reload nginx
sleep 1   # el reload es "graceful": los workers viejos terminan lo suyo antes de morir
echo "foo en modo: $1"
curl -s -H 'Host: foo' http://127.0.0.1/

#!/usr/bin/env python3
"""
sctp-recv.py - Guía 6 E74: receptor SCTP (reemplaza a `ncat -l --sctp`).

En esta VM (ncat 7.98, kernel 7.0) el MODO ESCUCHA de ncat con --sctp acepta
la asociación pero no entrega los datos (el archivo queda vacío). El ENVÍO con
ncat sí funciona, así que se usa este script para recibir.

Uso:   ./sctp-recv.py 4000 > recibido.txt          (terminal 1)
       ncat --sctp --send-only localhost 4000 < archivo   (terminal 2)
"""
import socket
import sys

puerto = int(sys.argv[1]) if len(sys.argv) > 1 else 4000

# SOCK_STREAM + IPPROTO_SCTP = SCTP "estilo uno a uno" (se usa igual que TCP)
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_SCTP)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("0.0.0.0", puerto))
srv.listen(1)
print(f"esperando asociación SCTP en el puerto {puerto}...", file=sys.stderr)

conn, origen = srv.accept()
total = 0
while True:
    datos = conn.recv(65536)
    if not datos:          # el otro extremo cerró (SHUTDOWN)
        break
    sys.stdout.buffer.write(datos)
    total += len(datos)
print(f"recibidos {total} bytes de {origen[0]}:{origen[1]}", file=sys.stderr)

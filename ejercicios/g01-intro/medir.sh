#!/usr/bin/env bash
# ============================================================
# medir.sh - Guía 1 E2: mide copy con buffer 0 (sendfile), 1, 512, 1024, 2048, 4096
#
# Uso:  ./medir.sh            -> archivo de ~100 MB (el del enunciado)
#       ./medir.sh 10         -> archivo de 10 MB (más rápido; buffer 1 con 100 MB tarda minutos)
#
# Qué mirar en la salida de time:
#   real = tiempo de reloj
#   user = CPU en modo usuario (el bucle de copy)
#   sys  = CPU en el kernel (las syscalls read/write/sendfile)
# Con buffer chico -> muchísimas syscalls -> sys enorme.
# Con sendfile     -> user ~ 0: todo pasa en el kernel, sin copiar a espacio de usuario.
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

MB=${1:-100}
IN=/tmp/archivo-in
OUT=/tmp/archivo-out

make -s copy

# Sugerencia del enunciado: dd if=/dev/urandom of=archivo-in bs=4096 count=25600  (~100 MB)
if [ ! -f "$IN" ] || [ "$(stat -c %s "$IN")" -ne $((MB * 1024 * 1024)) ]; then
    echo "Generando $IN de $MB MB con dd..."
    dd if=/dev/urandom of="$IN" bs=4096 count=$((MB * 256)) status=none
fi

TIMEFORMAT='real %3R s   user %3U s   sys %3S s'
for tam in 0 4096 2048 1024 512 1; do
    printf 'buffer %-5s ' "$tam"
    time ./copy "$IN" "$OUT" "$tam"
    cmp -s "$IN" "$OUT" || echo "  ¡ERROR: la copia no es igual al original!"
done
rm -f "$OUT"

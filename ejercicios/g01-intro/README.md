# Guía 1: introducción y repaso

Teoría (codificaciones, Unicode, endianness, serialización): `../../apuntes/01-unix-y-codificaciones.md`

| Archivo | Ejercicio |
|---|---|
| `copy.c`, `medir.sh`, `Makefile` | E2: read/write con distintos buffers vs sendfile |
| `Unicode.java` | E6: `"ἵ5"` y por qué `length()` da 2 |
| `FORMATO-LOG.md`, `logwrite.c`, `logread.c` | E11: formato de archivo + ABNF + escritor y lector |

```bash
cd ~/Protos/ejercicios/g01-intro
make                      # compila copy, logwrite, logread

# E1
grep -rl boot /var/log 2>/dev/null           # archivos que contienen "boot" (-r recursivo, -l sólo nombres)
sudo grep -rl boot /var/log | xargs sudo tail -f    # y quedarse mirando entradas nuevas
journalctl -f                                # en Ubuntu moderno, muchos logs están en el journal

# E2
./medir.sh 10             # 10 MB (rápido). Sin argumento: 100 MB como el enunciado (buffer 1 tarda minutos)

# E6
java Unicode.java

# E11
./logwrite mensajes.log && ./logread mensajes.log
cat -A mensajes.log       # ver los bytes: $ = fin de línea, M-C... = bytes UTF-8 > 127
```

## Resultado de E2 en esta VM (archivo de 5 MB)

```
buffer 0     real 0.002 s   user 0.000 s   sys 0.002 s     <- sendfile
buffer 4096  real 0.002 s   user 0.000 s   sys 0.002 s
buffer 512   real 0.008 s   user 0.001 s   sys 0.006 s
buffer 1     real 3.250 s   user 0.470 s   sys 2.779 s     <- 10 millones de syscalls
```

- **Por qué hay tanta diferencia**: cada `read`/`write` es una syscall, con su cambio de
  modo usuario↔kernel y una copia de datos kernel↔usuario. Con buffer de 1 byte hay 2
  syscalls por byte, y el costo fijo de cada syscall domina (casi todo es tiempo `sys`).
- **Ventaja de sendfile**: la copia la hace el kernel de un descriptor a otro, **sin pasar
  los datos por espacio de usuario** (zero-copy) y en muy pocas syscalls. Así nginx manda
  archivos estáticos por un socket (`sendfile on;` en nginx.conf).

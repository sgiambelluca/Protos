# Práctica — Simulacro Parcial (2026 2C)

Los 4 ejercicios del parcial práctico 2026 2C de **Protocolos de Comunicación (ITBA 72.07)**,
armados como **escenarios repetibles** para practicar en la VM. Todo corre en una sola máquina por
loopback (como en el parcial): los servidores levantan en la VM y vos los resolvés con `curl`,
`dig`, `nc`, `ssh` desde la misma VM.

## Contenido

| Archivo | Qué es |
|---|---|
| `consigna.pdf` | **Sólo las consignas** de los 4 ejercicios, para hacer a ciegas |
| `solucion.pdf` | **La resolución completa** paso a paso, con las trampas |
| `parcial-2026-2c.sh` | El corrector: levanta, corrige y limpia cada escenario |
| `ej4/backup.pcap` | La captura del Ej4 (zona `cachito.parcial` para reconstruir) |
| `consigna.html` / `solucion.html` | Fuente de los PDFs (por si querés editarlos y regenerarlos) |

## Uso

```bash
S=~/Protos/practica-simulacro-parcial/parcial-2026-2c.sh

$S montar    ej1      # levanta los servidores del Ej1 (o ej2/ej3/ej4, o 'todo')
$S verificar ej1      # corrige: OK / FALLA por requisito
$S solucion  ej1      # imprime la resolución (en el Ej4 además deja la zona aplicada)
$S limpiar   ej1      # saca TODO lo del Ej1 (servidores + tu solución)
```

Flujo sugerido: hacé el ejercicio con `consigna.pdf` a mano, corregí con `verificar`, y recién si te
trabás mirá `solucion.pdf` o `solucion ejN`. Al terminar, `limpiar todo`.

## Qué practica cada uno

| Ej | Tema |
|---|---|
| 1 | Proxy Squid `:3126` → hackerspace que sólo resuelve por el proxy (como `socks5h`) + Basic auth |
| 2 | nginx vhost por `Host` (`google.com`) + proxy interno (`secrethost` → `:8000`) + SSH con passphrase |
| 3 | SMTP y POP3 a mano con `nc -C`, MIME base64 |
| 4 | Reconstruir una zona DNS desde un PCAP, con bind9 (la trampa del TTL por RRset) |

## Notas

- **Corre sólo en la VM** (Ubuntu). La única dependencia que se instaló fue **Squid** (para el Ej1);
  el resto (nginx, bind9, postfix, dovecot, sshd) ya estaba.
- **No toca** las zonas `cachito.com`/`pepito.com`/`foo.pdc.lab` ni `/var/www` ni el servicio de
  `:8080`: el lab usa nombres y puertos propios (`3126`, `81`, `8090`, `8000`, `8008`), usuarios
  propios (`pepito`, `debsec`) y `limpiar` sólo mata sus propios procesos.
- Las credenciales que aparecen (p. ej. `debsec/hackerspace`, `clave-del-parcial`) son de
  **práctica**, deliberadamente conocidas: el chiste del ejercicio es descubrirlas. No hay secretos
  reales (la clave SSH se genera al vuelo en cada `montar` y no se versiona).
- Explicación larga y repaso en [`../apuntes/20-parcial-2026-2c.md`](../apuntes/20-parcial-2026-2c.md).

### Regenerar los PDFs

```bash
cd practica-simulacro-parcial
for f in consigna solucion; do
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
     --no-pdf-header-footer --print-to-pdf="$f.pdf" "file://$PWD/$f.html"
done
```

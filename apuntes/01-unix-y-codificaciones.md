# 01: UNIX, syscalls y codificaciones (Guía 1)

## Entorno UNIX (E1)

```bash
grep -rl boot /var/log          # -r recursivo, -l sólo el nombre del archivo, -i ignora mayúsculas
grep -rn "texto" dir/           # -n número de línea
tail -f archivo                 # sigue el archivo: muestra lo que se agrega (Ctrl-C para salir)
tail -F archivo                 # igual, pero reabre el archivo si lo rotan (logrotate)
journalctl -f                   # logs del sistema (systemd). -u nginx = de una unidad
```

- `grep boot *` no entra a subdirectorios. El `*` lo expande **el shell**, no grep.
- En Ubuntu moderno muchos logs viven en el **journal**. `/var/log/syslog` existe sólo si
  está instalado rsyslog (en esta VM sí).

## Syscalls y sendfile (E2)

- Una **syscall** (`read`, `write`, `open`...) pasa de modo usuario a modo kernel. Tiene un
  costo fijo (cambio de contexto, validaciones) además de copiar los datos entre el buffer
  del kernel y el del proceso.
- Copiar con `read`/`write` y un buffer de N bytes hace ~2·(tamaño/N) syscalls. Con N=1 el
  costo fijo domina: casi todo el tiempo es `sys`.
- **`sendfile(out_fd, in_fd, &offset, count)`** copia **dentro del kernel**, de un
  descriptor a otro, sin pasar por espacio de usuario (*zero-copy*). Hay menos syscalls y
  menos copias. Lo usan los servidores web para mandar archivos estáticos por un socket
  (`sendfile on;` en nginx).
- `time` muestra **real** (reloj de pared), **user** (CPU en modo usuario) y **sys** (CPU
  en el kernel).
- `write` puede escribir **menos** bytes de los pedidos (*short write*): hay que hacer un
  bucle.

## Codificaciones de caracteres (E3 a E9)

| | Bits | Qué cubre | Notas |
|---|---|---|---|
| **ASCII** (RFC 20) | 7 (0–127) | inglés, dígitos, puntuación, controles (CR=13, LF=10) | base de todos los protocolos de texto |
| **ISO-8859-1** (Latin-1) | 8 (0–255) | ASCII + acentos de Europa occidental (á=0xE1, ñ=0xF1) | 1 byte por carácter; no tiene €, ni otros alfabetos |
| **Unicode** | — | **no es una codificación**: es el catálogo que asigna un *code point* (U+0000…U+10FFFF) a cada carácter | los primeros 256 code points coinciden con Latin-1 |
| **UTF-8** (RFC 3629) | 1 a 4 bytes | todo Unicode | compatible con ASCII; el estándar de la web, HTTP y JSON |
| **UTF-16** | 2 o 4 bytes | todo Unicode | lo que está fuera del plano básico (> U+FFFF) usa **pares subrogados**. Java y JavaScript usan UTF-16 internamente |
| **UTF-32** | 4 bytes fijos | todo Unicode | acceso directo al carácter i, pero ocupa mucho |

**Unicode vs UTF-8** (E4): Unicode es el "diccionario" (carácter → número). UTF-8 es una
forma de **escribir esos números en bytes**. El mismo texto Unicode se puede guardar en
UTF-8, UTF-16 o UTF-32.

### UTF-8 a mano

| Code point | Bytes | Patrón |
|---|---|---|
| U+0000–U+007F | 1 | `0xxxxxxx` |
| U+0080–U+07FF | 2 | `110xxxxx 10xxxxxx` |
| U+0800–U+FFFF | 3 | `1110xxxx 10xxxxxx 10xxxxxx` |
| U+10000–U+10FFFF | 4 | `11110xxx 10xxxxxx 10xxxxxx 10xxxxxx` |

Ejemplo: `ñ` = U+00F1 = `000 1111 0001` → `110 00011` `10 110001` = **C3 B1**.

**Auto-sincronizante** (E7): mirando un solo byte se sabe si es el comienzo de un carácter
(`0xxxxxxx` o `11xxxxxx`) o una continuación (`10xxxxxx`). Si se salta a cualquier posición
del stream, basta con retroceder hasta encontrar un byte de comienzo para seguir decodificando
bien. Un byte de continuación nunca se confunde con un carácter, así que buscar un substring
no da falsos positivos.

**Criterio UTF-8 / 16 / 32** (E5):

- **UTF-8**: texto mayormente ASCII (protocolos, código, HTML), compatibilidad, sin problemas
  de endianness.
- **UTF-16**: mucho texto CJK (que en UTF-8 ocupa 3 bytes y acá 2), o APIs que ya lo usan
  (Java, Windows, JS).
- **UTF-32**: procesamiento interno donde importa indexar por carácter en O(1).

### E6: `"ἵ5"` en Java o JS

El escape `\uXXXX` toma **exactamente 4 dígitos hex**. Entonces es U+1F35 (ἵ) seguido de
`'5'`, y por eso `length()` = 2. Para la pizza 🍕 (U+1F355) hay que escribir `"🍕"`
(par subrogado) o, en JS, `"\u{1F355}"`. Igual `length()` da **2**, porque cuenta unidades
UTF-16. Para contar caracteres: `codePointCount` (Java) o `[...s].length` (JS). Ver
`ejercicios/g01-intro/Unicode.java`.

### BOM (Byte Order Mark)

Es U+FEFF al principio del archivo. En UTF-16 indica el orden de bytes: `FE FF` = big
endian, `FF FE` = little endian. En UTF-8 (`EF BB BF`) no hace falta, y a veces rompe
scripts (`#!` deja de estar en el byte 0).

## Endianness (E8)

Es el orden en que se guardan los bytes de un número multibyte. Por ejemplo, 0x12345678:

- **Big endian**: `12 34 56 78`. El más significativo va primero. Es el **orden de red**
  (*network byte order*), el de los headers TCP/IP.
- **Little endian**: `78 56 34 12`. Lo usan x86 y ARM (casi siempre).
- En C: `htons`/`htonl` (host → red) y `ntohs`/`ntohl` (red → host). El término viene de
  *On holy wars and a plea for peace* (IEN 137).

## Texto plano vs binario (E9)

- **Texto plano**: sólo caracteres de una codificación más saltos de línea. Ejemplos en
  ASCII: los headers HTTP/SMTP y `/etc/hosts`. En UTF-8: JSON (RFC 8259 lo exige),
  Markdown. Hay formatos que **declaran su propia codificación adentro**: XML
  (`<?xml version="1.0" encoding="ISO-8859-1"?>`), HTML (`<meta charset="utf-8">`), los
  mails MIME (`Content-Type: text/plain; charset=utf-8`) y Python (`# -*- coding: latin-1 -*-`).
- **Binario**: bytes con una estructura propia (JPEG, ELF, ZIP, PNG, un pcap). Muchos
  empiezan con un **magic number** (JPEG `FF D8 FF`, PNG `89 50 4E 47`, ELF `7F 45 4C 46`,
  ZIP `50 4B`). `file` los reconoce.
- Fin de línea: UNIX `LF` (`\n`), Windows `CR LF` (`\r\n`). Los protocolos de Internet
  (HTTP, SMTP, POP3) usan **CR LF**.

## Serialización (E10, E11)

- **Volcar la memoria** (`fwrite(&struct, sizeof...)`) no es portable: depende del
  endianness, del tamaño de los tipos (`time_t`, `int`), del padding y del alineamiento. Y
  los **punteros** (`char *msg`) no tienen sentido en otro proceso.
- **Hay que definir un formato**: el orden de los campos, el tamaño de cada uno, el orden
  de bytes y la codificación del texto.
- **Datos de largo variable**:
  - **Null-terminated** (`"hola\0"`): es simple y no tiene límite de largo, pero **no puede
    contener el byte 0** y hay que leer byte a byte hasta encontrarlo.
  - **Chunked** (*length-prefixed*: largo y después los bytes): admite cualquier byte, el
    lector sabe de antemano cuánta memoria pedir y se puede saltar el campo sin leerlo. La
    contra es que hay que conocer el largo **antes** de escribir y el largo tiene un máximo.
  - **Delimitador con escape** (línea terminada en `\n`, escapando los `\n` internos): es
    legible, pero hay que escapar y desescapar.
- HTTP usa las tres: headers terminados en CRLF, `Content-Length` (prefijo de largo) y
  `Transfer-Encoding: chunked` (bloques con su largo).

## ABNF (RFC 5234)

Es la notación con que los RFC definen la sintaxis.

```abnf
regla      =  definición               ; comentario
a b        ; concatenación
a / b      ; alternativa
*a  1*a  2*4a  3a                      ; repetición: 0+, 1+, entre 2 y 4, exactamente 3
[a]        ; opcional (= *1a)
( a b )    ; agrupación
"abc"      ; literal, CASE-INSENSITIVE
%x41  %x30-39  %d13.10                 ; valor exacto, rango, secuencia (CR LF)
; reglas core: ALPHA DIGIT HEXDIG SP HTAB CR LF CRLF DQUOTE OCTET VCHAR WSP
```

Ejemplo real (HTTP/1.1, RFC 9112): `start-line = request-line / status-line` y
`request-line = method SP request-target SP HTTP-version CRLF`.

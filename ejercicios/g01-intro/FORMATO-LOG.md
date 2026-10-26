# Guía 1 - E11: formato de archivo de mensajes de log

Formato para guardar los mensajes de la interfaz `Log` (nivel, fecha y texto) y leerlos
en orden. Tiene que poder implementarse igual en cualquier arquitectura y en cualquier
lenguaje.

## Decisiones de diseño

| Tema | Decisión | Por qué |
|---|---|---|
| Texto o binario | **Texto ASCII** en la cabecera de cada registro | No hay problema de *endianness* ni de tamaño de `int`/`time_t` entre arquitecturas, y se puede leer con `cat`. |
| Fecha | Milisegundos desde 1970-01-01 UTC, en decimal | `java.util.Date` usa exactamente eso (`getTime()`). Es UTC, así que no depende de la zona horaria. |
| Nivel | Palabra (`WARNING` / `INFO`) | Es legible y se puede extender sin romper nada (un lector viejo rechaza un nivel que no conoce). |
| Mensaje | **Chunked**: primero la longitud en *bytes*, después los bytes | El mensaje puede contener cualquier carácter (`\n`, `\0`, espacios), no hay que escapar nada y el lector sabe cuánto leer. Con *null-terminated* no se podría usar `\0`, y con fin de línea habría que escapar los `\n`. |
| Juego de caracteres del mensaje | **UTF-8** | Representa todo Unicode y es compatible con ASCII. La longitud es en **bytes**, no en caracteres (`"ñ"` ocupa 2 bytes). |
| Tamaño máximo | 65535 bytes por mensaje | Acota la memoria que necesita el lector y el campo de longitud (5 dígitos como máximo). |

## Gramática (ABNF, RFC 5234)

```abnf
log-file  = *record
record    = when SP level SP length ":" message LF
when      = 1*15DIGIT            ; ms desde epoch, UTC
level     = "WARNING" / "INFO"   ; case-sensitive (en ABNF los "..." son case-insensitive,
                                 ; acá se acuerda que se escriben en MAYÚSCULAS)
length    = 1*5DIGIT             ; 0..65535, cantidad de OCTETOS de message
message   = *OCTET               ; exactamente <length> octetos, UTF-8 válido
SP        = %x20
LF        = %x0A
DIGIT     = %x30-39
OCTET     = %x00-FF
```

Ejemplo (el segundo mensaje tiene un salto de línea adentro: 3 + 1 + 8 = 12 bytes):

```
1761497580123 INFO 10:hola mundo
1761497580124 WARNING 12:dos
lineas!!
```

## Validaciones que hace el lector

- `when` sólo tiene dígitos y no desborda 64 bits.
- `level` es uno de los valores conocidos. Si no, el archivo es inválido (o el registro se ignora, según la política).
- `length` está entre 0 y 65535.
- Hay `length` bytes disponibles y después viene un `LF`. Si no, el archivo está truncado o corrupto.
- Opcionalmente, que `message` sea UTF-8 válido.

## Programas

- `logwrite.c`: agrega registros a `mensajes.log` y termina.
- `logread.c`: lee `mensajes.log` en orden, valida cada registro y lo imprime.

```bash
make logwrite logread
./logwrite mensajes.log
./logread mensajes.log
```

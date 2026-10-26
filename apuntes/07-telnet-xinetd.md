# 07: telnet y xinetd (Guía 5, y echo/daytime de la Guía 6)

## Super-server (inetd / xinetd)

- En lugar de que cada servicio esté corriendo todo el tiempo, **un solo proceso (xinetd)
  escucha todos los puertos** configurados. Cuando llega una conexión, lanza el programa
  del servicio y le pasa el **socket conectado como stdin/stdout**. El programa no necesita
  saber nada de sockets: lee y escribe por stdin/stdout.
- Ventajas: menos memoria si el servicio se usa poco, control de acceso centralizado
  (`only_from`, `no_access`, TCP wrappers), límites (`instances`, `per_source`) y logs.
  Contra: lanzar un proceso por conexión es lento si hay mucha carga. Hoy lo reemplaza la
  **activación por socket de systemd** (por ejemplo `ssh.socket`).
- Servicios **INTERNAL**: echo, discard, daytime, chargen y time los implementa el propio
  xinetd.

## Configuración: `/etc/xinetd.d/<servicio>`

```
service telnet                 # nombre: tiene que estar en /etc/services (de ahí sale el puerto 23/tcp)
{
	disable     = no           # "no" = habilitado
	id          = telnet       # id único (dos bloques con el mismo nombre de servicio necesitan ids distintos: echo-stream / echo-dgram)
	socket_type = stream       # stream = TCP, dgram = UDP
	protocol    = tcp
	wait        = no           # no: un proceso por conexión (multihilo). yes: un solo proceso maneja el socket (lo típico en UDP)
	user        = root
	server      = /usr/sbin/telnetd     # el DEMONIO (in.telnetd en otras distros), NO el cliente /usr/bin/telnet
	server_args = ...          # opcional
	type        = INTERNAL     # para echo/daytime/... (sin "server")
	port        = 2323         # obligatorio si el nombre no está en /etc/services (type = UNLISTED)
	only_from   = 127.0.0.1    # control de acceso
}
```

- **No se permiten comentarios al final de una línea**: sólo líneas enteras con `#`.
- Se aplica con `sudo systemctl restart xinetd`, y los errores salen en
  `journalctl -u xinetd`.
- Para ver quién escucha: `sudo ss -tulpn | grep xinetd`. El proceso dueño del puerto es
  **xinetd**, no telnetd.

## Telnet (RFC 854)

- Es una **terminal remota sobre TCP 23**, todo en **texto plano**, incluida la contraseña.
- **NVT** (*Network Virtual Terminal*): una terminal "estándar" de 7 bits con CR LF. Cada
  lado traduce de y a su terminal real.
- **Comandos IAC** (*Interpret As Command*, byte **0xFF**), seguidos de un verbo y de una
  opción:

  | Byte | Verbo | Significado |
  |---|---|---|
  | 251 (0xFB) | WILL | "quiero activar la opción" |
  | 252 (0xFC) | WONT | "no la voy a usar" |
  | 253 (0xFD) | DO | "activala vos" |
  | 254 (0xFE) | DONT | "no la uses" |
  | 250 / 240 | SB ... SE | subnegociación (por ejemplo, mandar el tipo de terminal) |

  Opciones típicas: **ECHO (1)**, **SUPPRESS-GO-AHEAD (3)**, TERMINAL-TYPE (24), NAWS
  (31, tamaño de la ventana), LINEMODE (34).
- **Negociación** (E71): al conectarse se intercambian `DO TERMINAL-TYPE`, `WILL ECHO`,
  `DO SUPPRESS-GO-AHEAD`, etc. Si una opción no se negocia, vale su default.
- **Eco**: después de `WILL ECHO` (del server) y `DO ECHO` (del cliente), **el server hace
  el eco**. El cliente manda cada tecla y el server la devuelve, por eso en el Follow Stream
  el usuario aparece duplicado. **La contraseña no se ve** porque mientras se pide el server
  **deja de devolver** los caracteres. Pero los caracteres **viajan igual en texto plano**
  hacia el server, así que cualquiera que capture los ve.
- `telnet host puerto` también sirve como cliente TCP genérico (como nc). Escape: `Ctrl-]`
  y después `quit`.

## Errores comunes

| Síntoma | Causa |
|---|---|
| `Connection closed by foreign host` enseguida | `server` apunta a un ejecutable equivocado (pasó en clase: `/usr/bin/telnet`, el cliente) o el demonio falla |
| `Connection refused` | xinetd no está corriendo, o `disable = yes`, o el bloque tiene un error de sintaxis (mirar journalctl) |
| el servicio no aparece | el nombre no está en `/etc/services` y falta `port =` |
| echo UDP no responde | `disable = yes` en el bloque dgram, o no hay `wait = yes` |

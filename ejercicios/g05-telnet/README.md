# Guía 5: telnet con xinetd (E71)

Teoría (super-server, opciones de telnet, eco): `../../apuntes/07-telnet-xinetd.md`

## Estado

Estaba armado en clase, pero **no andaba**. `/etc/xinetd.d/telnetd` decía
`server = /usr/bin/telnet`, que es el **cliente**, así que la conexión se cerraba
enseguida ("Connection closed by foreign host"). Ahora apunta a `/usr/sbin/telnetd`
(paquete `inetutils-telnetd`). El original quedó en `~/Protos/backups-originales/`.

```
service telnet
{
	disable     = no
	id          = telnet
	socket_type = stream
	protocol    = tcp
	user        = root
	wait        = no
	server      = /usr/sbin/telnetd
	log_on_failure += USERID
}
```

- El nombre del bloque (`service telnet`) tiene que existir en `/etc/services`. De ahí
  xinetd saca el puerto (23/tcp). Si el nombre no está ahí, hay que poner `port = N`.
- xinetd **no** admite comentarios al final de una línea, sólo líneas enteras con `#`.

## Probar

```bash
sudo systemctl restart xinetd
journalctl -u xinetd -n 20            # "Started working: N available services". Si hay error de sintaxis, aparece acá
sudo ss -tlnp | grep ':23 '           # quien escucha es xinetd, no telnetd
telnet localhost                      # login: sgiambelluca / tu contraseña
```

## Con Wireshark

Interfaz **lo** (Loopback), filtro `telnet`. Después: clic derecho → Follow → TCP Stream.

- **Negociación**: al principio hay bytes `IAC (0xFF) DO/DONT/WILL/WONT <opción>`. Wireshark
  los decodifica como, por ejemplo, `Do Terminal Type`, `Will Echo`,
  `Do Suppress Go Ahead`, `Do Negotiate About Window Size`.
- **Eco remoto**: el server manda `WILL ECHO` y el cliente lo acepta (`DO ECHO`). Desde ahí
  el cliente **no** muestra lo que tipeás: cada tecla viaja al server y el server la
  devuelve. En el Follow Stream el usuario aparece "duplicado" (rojo = cliente, azul =
  server).
- **La contraseña no se ve en la terminal** porque mientras la pedís el server **deja de
  hacer eco** (no devuelve esas teclas). Pero **sí viaja en texto plano** y en la captura se
  lee letra por letra. Por eso telnet se reemplazó por SSH.

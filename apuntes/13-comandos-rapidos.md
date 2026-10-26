# 13: comandos rápidos y checklist

## Servicios (systemd)

```bash
systemctl status X        # estado + últimas líneas del log
sudo systemctl start|stop|restart|reload X
sudo systemctl enable --now X        # que arranque al bootear, y arrancarlo ya
journalctl -u X -f        # log en vivo   (-n 50: últimas 50, -b: desde el boot)
sudo ss -tulpn            # quién escucha en qué puerto (t=tcp u=udp l=listen p=proceso n=numérico)
```

| Servicio en la VM | Unidad | Puertos | Validar config |
|---|---|---|---|
| nginx | `nginx` | 80, 443 | `sudo nginx -t` |
| bind9 | `named` | 53 udp/tcp, 953 (rndc) | `sudo named-checkconf -z` |
| postfix | `postfix` | 25 | `sudo postfix check` |
| dovecot | `dovecot` | 110 | `sudo doveconf -n` |
| xinetd | `xinetd` | 7, 9, 13, 19, 23, 37 | `journalctl -u xinetd` |
| ssh | `ssh` (+ `ssh.socket`) | 22 | `sudo sshd -t` |
| backend E39 | `protos-python-http` | 127.0.0.1:8080 | — |
| DNS local | `systemd-resolved` | 127.0.0.53 | `resolvectl status` |

## Una línea por tema

```bash
# HTTP
printf 'GET / HTTP/1.1\r\nHost: foo\r\n\r\n' | nc localhost 80
curl -v -H 'Host: bar' http://127.0.0.1/
curl -sI -H 'Accept-Encoding: gzip' http://foo/grande.html
curl -I -H 'If-None-Match: "ETAG"' http://foo/grande.html          # 304
nc -l 9090                                                        # "servidor" HTTP a mano

# DNS
dig @127.0.0.1 foo.pdc.lab ANY ; dig -x 10.0.2.15 @127.0.0.1 ; dig +trace itba.edu.ar ; dig MX itba.edu.ar +short
host -t NS itba.edu.ar ; nslookup -type=SOA itba.edu.ar ; whois itba.edu.ar ; resolvectl query foo.pdc.lab

# Mail
nc -C localhost 25 ; nc -C localhost 110 ; mailq ; sudo tail -f /var/log/mail.log ; mutt

# Base64 / encodings
echo -n 'HO LA' | base64 ; echo Y2hhdQ== | base64 -d ; xxd archivo | head ; file archivo ; iconv -f latin1 -t utf8

# Transporte
nc -zv localhost 1-100 ; nc -u localhost 7 ; ss -tan ; sudo nmap -sS -sU -p 7,13,37 localhost

# IP
ip a ; ip route ; ip route get 8.8.8.8 ; ip neigh ; traceroute -n -I host ; ping -M do -s 1472 host

# SSH
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub ; ssh-copy-id host ; ssh -L 8080:localhost:80 host ; ssh -D 1080 host ; ssh -R 9090:localhost:9090 host

# Captura
sudo tcpdump -ni lo port 25 -A ; tshark -i lo -Y dns
```

## Checklist "no anda"

| Problema | Revisar |
|---|---|
| Un sitio de nginx muestra otro | ¿el `Host` coincide con `server_name`? ¿está el symlink en sites-enabled? ¿hay un `default_server`? `curl -v -H 'Host: x'` |
| nginx no recarga | `sudo nginx -t` y leer la línea del error (casi siempre falta un `;`) |
| El navegador no abre http://foo | HSTS de `.foo`: usar https o curl |
| 502 | el backend está caído o el puerto está mal → `error.log`, `ss -tlnp` |
| DNS responde lo viejo | serial, `rndc reload`, cache (`rndc flush`, TTL) |
| La zona no carga | `named-checkconf -z`: path, punto final, CNAME |
| dig responde pero no es mi zona | falta el flag `aa`: la zona no cargó y respondió Internet |
| No llega un mail | `mailq`, `/var/log/mail.log` (deferred, bounced, relay denied), `mydestination`, MX |
| POP3 no ve los mails | ¿Maildir o mbox? `home_mailbox` vs `mail_path` de dovecot |
| xinetd: el servicio no responde | `disable = no`, la ruta de `server`, `journalctl -u xinetd`, `/etc/services` |
| SSH pide password teniendo clave | permisos de `~/.ssh` (700) y `authorized_keys` (600), `ssh -v` |
| ssh se cuelga (timeout) pero `nc host 22` conecta | DSCP: `ssh -o IPQoS=none` (pasó en la red del laboratorio, ver apunte 10) |
| ssh ignora la clave que le pasás con `-i` | permisos: `chmod 600 clave` ("UNPROTECTED PRIVATE KEY FILE") |
| No captura nada | ¿interfaz `lo` o `enp0s8`? ¿filtro de captura demasiado estricto? ¿grupo wireshark? |

## Checklist antes de entregar (por tipo de ejercicio)

Basada en la del simulacro (`17-simulacro.md`), con agregados de los parciales resueltos (14).

| Ejercicio | Revisar |
|---|---|
| **DNS / zona** | ¿`named-checkzone` da OK? ¿subiste el **serial**? ¿el mail del SOA va con `.` y no con `@`? ¿el MNAME es uno de los NS? ¿cada NS y MX tiene su A (y el MX no apunta a un CNAME)? ¿ningún A apunta a un nombre? ¿los nombres absolutos terminan en `.`? ¿refresh y negative TTL bajos, y expire > refresh + retry? ¿`rndc reload` y `dig` con flag `aa`? |
| **nginx proxy reverso** | ¿es `proxy_pass` y no un redirect (la URL no cambia)? ¿`nginx -t` da OK? ¿el upstream resuelve ("host not found in upstream")? ¿si el upstream es HTTPS, pusiste `proxy_ssl_server_name on`? ¿está el symlink en `sites-enabled`? ¿probaste con curl **sin flags**? |
| **HTTPS / certificado** | ¿tiene **SAN**? ¿está en el almacén del sistema (`update-ca-certificates`) para que curl ande sin `-k`? ¿y en el del navegador, si lo piden (mkcert)? |
| **curl + SOCKS** | ¿`socks5h` (con h)? ¿pediste `Accept` y `Accept-Language` con un solo idioma? ¿decodificaste las credenciales (`base64 -d`) o pasaste el header tal cual? |
| **DHCP** | ¿la IP fija está **fuera** del range? ¿los DNS van separados por **coma**? ¿`;` en cada línea? ¿`INTERFACESv4` en `/etc/default/isc-dhcp-server`? ¿la interfaz tiene una IP de esa red? ¿copiaste bien la MAC (primer byte par)? ¿`dhcpd -t` da OK? |
| **Túnel SSH** | ¿el `nc -l` arrancó **antes** que el `nc` del otro lado? ¿el puerto remoto es el legajo (≤ 65535)? ¿`-R` (el puerto se abre en el remoto) o `-L` (en el tuyo)? Sin túnel es la mitad del puntaje |
| **Rutas + escaneo** | ¿agregaste la ruta (`ip route add RED via GW`)? ¿`-Pn` por si bloquean ICMP? ¿la VM está en **Bridge**? ¿`traceroute` muestra el gateway como primer salto? |
| **Mail** | ¿cuerpo en **base64** (nada de quoted-printable si lo piden)? ¿Subject con tildes como encoded-word? ¿`X-Parcial` exacto? ¿From con nombre, apellido y cuenta ITBA? ¿`Date`, `MIME-Version` y `Content-Type` con charset? ¿`RCPT TO` a la casilla del legajo? ¿`nc -C`? ¿línea vacía antes del cuerpo y `.` al final? |
| **Siempre** | probar con **curl**, no con el navegador (HSTS de `.foo`). Usar el DNS que corresponde: desde el ITBA, un DNS externo (8.8.8.8) te puede dar la IP pública de pampero, y el firewall te rechaza (split-horizon) |

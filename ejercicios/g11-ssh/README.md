# Guía 11: SSH

Teoría (host keys vs claves de usuario, known_hosts, túneles -L/-R/-D): `../../apuntes/10-ssh.md`

**Fuera del alcance acordado**: E99 desde otro host, E101 a E104 (pampero). Igual los
comandos de túneles están abajo y en el apunte, porque son preguntas típicas de teoría.

## Estado

- `openssh-server` instalado. El servicio arranca por socket (`ssh.socket`), por eso
  `systemctl is-enabled ssh` dice *disabled* aunque escuche en el puerto 22.
- **E100 hecho ahora**: se generó `~/.ssh/id_ed25519` (sin passphrase) y su `.pub` se agregó
  a `~/.ssh/authorized_keys`. `ssh localhost` entra sin contraseña.
- En `authorized_keys` también está la clave `claude-ubuntua` (la de la Mac, que usé para
  configurar la VM). Si querés, borrá esa línea al terminar.

## Comandos

```bash
# E99: fingerprint de las claves del SERVIDOR (host keys)
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub   # la que ofrece primero un cliente moderno
ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub       # la RSA que pide el enunciado
ssh -o HostKeyAlgorithms=rsa-sha2-512 localhost    # forzar que el server muestre la RSA
mv ~/.ssh/known_hosts ~/.ssh/known_hosts.bak       # "olvidar" los servers conocidos
ssh localhost                                      # pregunta "Are you sure...?" y muestra el fingerprint -> compararlo
ssh-keygen -F localhost                            # buscar en known_hosts
#   Si el nombre pasa a apuntar a OTRA máquina (E99 e):
#   "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!" -> posible man-in-the-middle, no conecta
ssh-keygen -R localhost                            # borrar la entrada vieja de known_hosts

# E100: login sin contraseña (clave pública del USUARIO)
ssh-keygen -t ed25519                              # genera ~/.ssh/id_ed25519 (privada) y .pub (pública)
ssh-copy-id localhost                              # agrega la .pub al ~/.ssh/authorized_keys del server
ssh -v localhost 2>&1 | grep -i "authenticated using"   # "Authenticated ... using publickey"
#   permisos: ~/.ssh 700, authorized_keys 600 (si están abiertos, sshd ignora la clave)

# copiar archivos (E101 era contra pampero; acá contra localhost)
scp /etc/hostname localhost:/tmp/
scp localhost:/etc/passwd /tmp/passwd-copia

# Túneles (E102-E104, teoría)
ssh -D 1080 usuario@server          # E102: proxy SOCKS5 dinámico -> curl --socks5-hostname 127.0.0.1:1080 https://api.ipify.org
ssh -R 9090:127.0.0.1:9090 usuario@server   # E103: el SERVER escucha en 9090 y lo trae a mi 127.0.0.1:9090
ssh -L 8080:127.0.0.1:80 usuario@server     # E104: YO escucho en 8080 y lo llevo al puerto 80 del server
# Probado en la VM contra sí misma:
ssh -fN -L 8081:127.0.0.1:80 localhost && curl -s -H 'Host: bar' http://127.0.0.1:8081/ ; pkill -f '^ssh -fN -L 8081'
```

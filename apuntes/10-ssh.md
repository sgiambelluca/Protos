# 10: SSH (Guía 11)

## Arquitectura (RFC 4251 a 4254)

1. **Capa de transporte**: el server se autentica con su **host key**, se negocian los
   algoritmos, se hace un intercambio de claves Diffie-Hellman (ECDH, *forward secrecy*) y
   desde ahí todo va **cifrado** y con integridad.
2. **Autenticación del usuario**: con *password*, *publickey* o *keyboard-interactive*.
3. **Capa de conexión**: **canales** multiplexados: shell, exec, sftp, port forwarding
   (túneles), X11.

## Dos pares de claves distintos

| | Host key (del SERVIDOR) | Clave de USUARIO |
|---|---|---|
| Dónde está la privada | `/etc/ssh/ssh_host_{ed25519,rsa,ecdsa}_key` | `~/.ssh/id_ed25519` en el cliente |
| Dónde está la pública | `/etc/ssh/ssh_host_*_key.pub` | `~/.ssh/id_ed25519.pub` |
| Quién guarda la pública ajena | el **cliente**, en `~/.ssh/known_hosts` | el **servidor**, en `~/.ssh/authorized_keys` del usuario |
| Qué prueba | que me conecto al servidor correcto (no a un MITM) | que yo soy el usuario (sin password) |

### known_hosts y fingerprint (E99)

- La primera vez que te conectás: *"The authenticity of host 'foo' can't be established.
  ED25519 key fingerprint is SHA256:..."*. Eso es **TOFU** (*Trust On First Use*): habría
  que comparar el fingerprint por otro canal, con `ssh-keygen -lf
  /etc/ssh/ssh_host_ed25519_key.pub` en el server. Cuando se acepta, se agrega a
  `known_hosts`.
- Si después **el mismo nombre** presenta **otra** clave (porque reinstalaron el server,
  porque el nombre apunta a otro host como en E99e, o porque hay un **man-in-the-middle**):
  `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` y **no se conecta**. Si es legítimo, se
  borra la entrada vieja con `ssh-keygen -R foo`.
- Un cliente moderno prefiere la clave **ed25519**, no la RSA. Por eso el fingerprint que
  muestra puede no coincidir con el de `ssh_host_rsa_key.pub` que pide el enunciado. Para
  pedir la RSA: `ssh -o HostKeyAlgorithms=rsa-sha2-512 foo`.
- `known_hosts` puede tener los nombres **hasheados** (`|1|...`, `HashKnownHosts yes`).

### Login sin contraseña (E100)

```bash
ssh-keygen -t ed25519          # par de claves (passphrase opcional: protege la privada si te la roban)
ssh-copy-id usuario@server     # agrega la .pub a ~/.ssh/authorized_keys del server (pide el password una vez)
ssh usuario@server             # ya no pide password
ssh-agent / ssh-add            # guardar la passphrase en memoria
```

Permisos (si están mal, sshd **ignora la clave** sin avisar al cliente; el motivo aparece
en `/var/log/auth.log` o en `journalctl -u ssh`): `~` sin escritura para otros, `~/.ssh`
**700**, `authorized_keys` **600**, la clave privada **600**.

## sshd_config (`/etc/ssh/sshd_config` y `/etc/ssh/sshd_config.d/*.conf`)

```
Port 22
PermitRootLogin prohibit-password    # no (recomendado) / yes / prohibit-password (sólo con clave)
PasswordAuthentication no            # sólo claves
PubkeyAuthentication yes
AllowTcpForwarding yes               # túneles -L/-R
GatewayPorts no                      # los -R escuchan sólo en 127.0.0.1 del server (yes = en todas las interfaces)
X11Forwarding yes
```

`sudo sshd -t` (chequea la sintaxis) y `sudo systemctl reload ssh`. En Ubuntu el servicio
es `ssh` y arranca por socket (`ssh.socket`). La guía del ex alumno dice
`/etc/sshd_config` y `apt install ssh-server`: lo correcto es `/etc/ssh/sshd_config` y
`openssh-server`.

## Copiar archivos (E101)

```bash
scp usuario@pampero.itba.edu.ar:/etc/passwd .        # remoto -> local
scp archivo usuario@host:/tmp/                        # local -> remoto  (-r para directorios)
sftp usuario@host                                     # interactivo (get / put / ls)
rsync -av dir/ usuario@host:dir/                      # sincroniza (sólo lo que cambió)
```

## Túneles (E102 a E104)

| Opción | Quién escucha | A dónde va | Ejemplo |
|---|---|---|---|
| **`-L` local** `-L [bind:]puerto_local:destino:puerto` | **mi** máquina, en `puerto_local` | el **server SSH** se conecta a `destino:puerto` | E104: `ssh -L 8080:localhost:80 u@pampero` → `curl localhost:8080` llega al puerto 80 **de pampero** |
| **`-R` remoto** `-R [bind:]puerto_remoto:destino:puerto` | el **server SSH**, en `puerto_remoto` | **mi** máquina se conecta a `destino:puerto` | E103: `ssh -R 9090:127.0.0.1:9090 u@pampero` → en pampero `curl localhost:9090` llega a **mi** 127.0.0.1:9090 |
| **`-D` dinámico** `-D [bind:]puerto` | **mi** máquina: un **proxy SOCKS5** | a donde pida cada aplicación, saliendo **desde el server** | E102: `ssh -D 1080 u@pampero` y el navegador con proxy SOCKS 127.0.0.1:1080 |

- Opciones útiles: `-N` (no abrir shell, sólo el túnel), `-f` (pasar a segundo plano),
  `-J salto` (ProxyJump, pasar por un bastión).
- **`socks5://` vs `socks5h://`** en curl (o `--socks5` vs `--socks5-hostname`): con `h`,
  el **DNS lo resuelve el proxy** (el server SSH). Sin `h`, lo resuelve tu máquina.
- **E103 no anda desde otra máquina**: por defecto `-R` escucha en 127.0.0.1 **del server**.
  Para que lo usen otros hosts hace falta `GatewayPorts yes` (o `clientspecified`) en el
  sshd_config del server.

## ~/.ssh/config (cliente)

```
Host ubuntua
    HostName 127.0.0.1
    Port 2222
    User sgiambelluca
    IdentityFile ~/.ssh/ubuntua_ed25519
```

Con esto alcanza con `ssh ubuntua` (así está armado el acceso a esta VM desde la Mac).

---

## En parciales anteriores (salió 2 veces)

La resolución completa, paso a paso, está en `14-resoluciones-parciales.md`.

**Simulacro** (`17-simulacro.md`): el Ej 5 es el túnel + `tail -f` con el puerto 6402. En la VM se practica con localhost haciendo de pampero, pero con **otro puerto local**: en una sola máquina, con el mismo puerto en las dos puntas el `nc` puede no pasar por el túnel.

**2022 2C Ej 2 y 2026 1C Ej 4**: que `tail -f archivo.log` en **tu** máquina muestre en vivo
un archivo de **pampero** (`/tmp/pdc` o `/tmp/parcial-20261`), **usando túneles** (si no,
tenés la mitad del puntaje), con el legajo como puerto.

```bash
nc -l 127.0.0.1 8099 > archivo.log                                     # mi máquina (puerto libre)
ssh -R LEGAJO:localhost:8099 user@pampero 'tail -f /tmp/pdc | nc localhost LEGAJO'
tail -f archivo.log                                                    # mi máquina
```

- **`-R`**: el puerto **LEGAJO se abre en pampero**. Lo que entra ahí sale por **mi**
  `localhost:8099`.
- Se usa `-R` porque los datos **salen de pampero hacia mí**, y pampero no puede conectarse
  directo a mi máquina (NAT).
- Variante con `-L`: en pampero `tail -f /tmp/pdc | nc -l LEGAJO`, y en mi máquina
  `ssh -N -L 8099:localhost:LEGAJO user@pampero` + `nc localhost 8099 > archivo.log`.
- Sin túnel (mitad del puntaje): `ssh user@pampero 'tail -f /tmp/pdc' > archivo.log`.

Probado en la VM con `localhost` en lugar de pampero.

**El proxy SOCKS de `ssh -D`** sirve para practicar los ejercicios de curl con
`-x socks5h://` (2024 Ej II, 2026 Ej 3).

---

## Más práctica (material del repo Protos-ITBA)

```bash
ssh -p 2222 usuario@host            # otro puerto (así entra la Mac a esta VM)
ssh -i ./clave usuario@host         # otra clave privada. Si es descargada:  chmod 600 ./clave  (si no, ssh la rechaza)
ssh -v usuario@host                 # debug: qué método de autenticación usó, qué host key, etc.
eval "$(ssh-agent)" && ssh-add      # ssh-agent guarda la clave desencriptada en memoria: la passphrase se pide 1 sola vez
ssh-add -l                          # claves cargadas en el agente
```

- **El destino de `-L`/`-R` lo resuelve el lado que hace la conexión final.** Con
  `ssh -R 9090:luces:80 user@pampero`, quien se conecta a `luces:80` es **mi** máquina (y
  "luces" puede ser otro equipo de mi red, no sólo localhost). Con `-L 8080:google.com:80`,
  quien se conecta a google es **pampero**.
- **Firefox por el túnel `-D`**: Ajustes → Configuración de red → Manual → SOCKS Host
  `127.0.0.1`, puerto (el del `-D`), SOCKS v5, y tildar "DNS por el proxy" (equivale a
  `socks5h`).
- **Copiar un archivo "a la cavernícola"** (el patrón de los parciales): en mi máquina
  `nc -l 1234 > copia.txt`, después `ssh -R 9999:localhost:1234 user@pampero`, y en pampero
  `cat /etc/passwd | nc localhost 9999`. Con **pipe**: el repo escribe `>`, que está mal. La
  manera normal es `scp`.
- **Emular `-L` con `-R`** (Ej 6) y **túnel en loop** `ssh localhost -L1234:127.0.0.1:1234`
  (Ej 7, probado: termina con `channel 1014: open failed`): ver `15-ejercicios-extra.md`.

---

## Del integrador (CTF Protolab, `~/Protos/recu/`)

- **Entrar con una clave que bajaste**: `curl -s http://192.168.0.238:49681/supersecretkey -o ~/vaultkey`,
  `chmod 600 ~/vaultkey` y `ssh -i ~/vaultkey -p 12222 bububu@192.168.0.238`. Sin el `chmod`
  ssh la ignora. Probado en la VM con una clave en 644: `WARNING: UNPROTECTED PRIVATE KEY
  FILE! ... This private key will be ignored.`
- **Passphrase no es lo mismo que contraseña de login**: la passphrase descifra la clave
  privada **en tu máquina** (ssh la pide al cargarla) y el server nunca la ve. En el CTF era
  `string_equals`.
- **Trampa de la red del laboratorio: ssh "da timeout" pero `nc host 22` conecta.** OpenSSH 10
  marca los paquetes con DSCP (opción `IPQoS`; en esta VM `ssh -G localhost | grep ipqos` da
  `ipqos ef cs0`) y algún equipo de la red los descarta. Solución: `ssh -o IPQoS=none ...`, o
  en `~/.ssh/config`:

  ```
  Host *
      IPQoS none
  ```

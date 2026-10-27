# 18: DHCP paso a paso (parcial 2025 2C, Ej I)

El ejercicio de DHCP explicado desde cero, con las pruebas hechas en la VM. La resolución
corta está en `14-resoluciones-parciales.md` (2025 2C, Ej I) y la teoría en
`12-temas-multi-host.md`. El simulacro (`17-simulacro.md`, Ej 4) es el mismo ejercicio con
otros datos.

## Qué es DHCP

Cuando una computadora se conecta a una red, no sabe qué IP usar. Le pregunta a toda la red a
la vez (broadcast) "¿alguien me da una IP?", y el **servidor DHCP** le contesta con una oferta:
"usá esta IP, esta máscara, este gateway y estos DNS". Es lo que hace el router de tu casa
cuando conectás el celular.

### La secuencia DORA

```
cliente (sin IP)                                       servidor (192.168.100.1)
   │── DISCOVER (broadcast): "¿alguien me da una IP?" ──────►│
   │◄─ OFFER: "te ofrezco la .10, gateway .1, DNS 8.8.8.8" ──│
   │── REQUEST (broadcast): "quiero la .10 que me ofreció .1"►│
   │◄─ ACK: "listo, es tuya por 10 minutos" ─────────────────│
```

- **D**iscover: el cliente busca servidores.
- **O**ffer: el servidor ofrece una IP y los datos de la red.
- **R**equest: el cliente pide la IP que eligió. Va por broadcast para que los otros servidores
  DHCP de la red se enteren de que su oferta no fue elegida.
- **A**ck: el servidor confirma, y la IP queda prestada por el tiempo del lease.

El nmap del enunciado (`broadcast-dhcp-discover`) hace **sólo las dos primeras**: manda el
DISCOVER y muestra la OFFER, por eso la salida dice "IP **Offered**". No se queda con la IP.
Así lo registró dhcpd en la VM:

```
DHCPDISCOVER from aa:bb:cc:dd:ee:ff via veth-srv
DHCPOFFER on 192.168.100.10 to aa:bb:cc:dd:ee:ff via veth-srv
DHCPDISCOVER from 08:00:27:ae:c8:6a via veth-srv
DHCPOFFER on 192.168.100.8 to 08:00:27:ae:c8:6a via veth-srv
```

Un cliente de verdad (otra VM conectada a esa red interna) sí hace los cuatro pasos.

## Qué pide el ejercicio

Sos el admin de una oficina con la red `192.168.100.0/24`, y tenés que armar ese servidor para
que:

1. a cualquier compu le dé una IP entre la `.10` y la `.200`;
2. a todos les diga que usen los DNS de Google (`8.8.8.8` y `8.8.4.4`);
3. a la impresora (MAC `08:00:27:AE:C8:6A`) le dé **siempre** la `.8`, para que todos la
   encuentren en la misma IP.

Se verifica con
`sudo nmap --script broadcast-dhcp-discover --script-args "broadcast-dhcp-discover.mac=AA:BB:CC:DD:EE:FF"`.

## El dibujo

```
            VirtualBox: "Red interna" (un cable virtual que sólo conecta VMs)
  ┌─────────────────────────┐                           ┌────────────────────────┐
  │ Tu VM (servidor DHCP)   │                           │ Clientes (otra VM, o   │
  │ enp0s9: 192.168.100.1   │◄──── 192.168.100.0/24 ───►│ el nmap que la simula) │
  │ enp0s8: NAT / red lab   │                           └────────────────────────┘
  └─────────────────────────┘
          │
          └── por acá NO se reparte nada (es la red del lab o internet)
```

## Por qué no en la interfaz del WiFi del lab (el "DHCP trucho")

1. La red del laboratorio **ya tiene** su servidor DHCP: el de la facultad.
2. Si tu dhcpd también contestara por la interfaz que está en esa red, cuando un compañero se
   conecta y pregunta "¿alguien me da una IP?", le contestan **dos**: el de la facultad y el tuyo.
3. Su compu se queda con la primera oferta que le llega. Si es la tuya, recibe una
   `192.168.100.x` con gateway `192.168.100.1`, una red que en el laboratorio no existe, y se
   queda sin internet.
4. Por eso la consigna pide hacerlo en una **red interna** (un cable virtual de VirtualBox donde
   sólo están tus VMs) y que dhcpd escuche **sólo** ahí: `INTERFACESv4="enp0s9"`.
5. La VM puede tener **además** otro adaptador conectado al laboratorio, para tener internet. Eso
   no molesta: lo único que importa es que dhcpd no conteste por ese.

## La solución, paso a paso

### Paso 0: la red interna, en VirtualBox

Con la VM apagada: Configuración → Red → Adaptador 2 → "Red interna". Al prender la VM aparece
una interfaz nueva. Para ver cómo se llama:

```
$ ip -br link
lo       UNKNOWN  00:00:00:00:00:00
enp0s8   UP       08:00:27:c2:62:e3      <- el adaptador 1 (NAT o la red del lab)
enp0s9   DOWN     08:00:27:...           <- el adaptador 2: la red interna (ejemplo)
```

`ip -br link` no crea nada: sólo lista las interfaces.

### Paso 1: darle IP al servidor

```bash
sudo ip addr add 192.168.100.1/24 dev enp0s9    # la IP fija del servidor en esa red
sudo ip link set enp0s9 up                      # prender la interfaz (si está DOWN, no manda ni recibe)
```

El servidor necesita **su propia** dirección en la red que reparte, y no puede pedírsela a nadie
porque él es el que reparte. Por eso se la das a mano. Esa IP sirve para tres cosas:

- **Para que dhcpd sepa qué repartir por esa interfaz**: busca en el `.conf` el bloque `subnet`
  que contenga esa IP. Probado en la VM con la config del parcial:

  ```
  interfaz sin IP:                 No subnet declaration for veth-x (no IPv4 addresses).
  interfaz con 192.168.50.1/24:    No subnet declaration for veth-x (192.168.50.1).    <- IP de otra red
  interfaz con 192.168.100.1/24:   Listening on LPF/veth-x/.../192.168.100.0/24        <- ahora sí arranca
  ```

- **Es la dirección desde la que contesta**: los clientes la ven como
  `Server Identifier: 192.168.100.1`, y a esa dirección le piden después renovar su IP.
- **En este ejercicio también es el gateway** (`option routers 192.168.100.1`). El `.1` es
  costumbre: podría ser otra, siempre que esté en la red y fuera del rango `.10`–`.200`.

No es una entrada de la tabla de ruteo: es la dirección de la interfaz. Al ponerla, el kernel
agrega solo la ruta a esa red (`192.168.100.0/24 dev enp0s9 proto kernel scope link src 192.168.100.1`).

### Paso 2: instalar el servidor y decirle dónde escuchar

```bash
sudo apt install isc-dhcp-server                # en la VM ya está (4.4.3-P1-4ubuntu2)
sudo nano /etc/default/isc-dhcp-server          # INTERFACESv4="enp0s9"
```

Si `INTERFACESv4` queda vacío, dhcpd intenta atender en **todas** las interfaces: justo lo que
hay que evitar en el laboratorio.

### Paso 3: la configuración

`/etc/dhcp/dhcpd.conf` (copia en `~/Protos/ejercicios/parciales/2025-2c-ej1-dhcpd.conf`), con
el requisito que cumple cada línea:

```
ddns-update-style none;
authoritative;                                    # es EL servidor de esta red
default-lease-time 600;                           # 10 minutos
max-lease-time 7200;

subnet 192.168.100.0 netmask 255.255.255.0 {      # la red de la oficina
    range 192.168.100.10 192.168.100.200;         # req. 1: las IPs que reparte
    option routers 192.168.100.1;                 # el gateway que les informa a los clientes
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.100.255;
    option domain-name-servers 8.8.8.8, 8.8.4.4;  # req. 2: los DNS de Google (separados por COMA)
}

host impresora {                                  # req. 3: una reserva para una MAC
    hardware ethernet 08:00:27:AE:C8:6A;
    fixed-address 192.168.100.8;                  # FUERA del range: nadie más la puede recibir
}
```

### Paso 4: validar y arrancar

```bash
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf          # chequeo de sintaxis (como nginx -t)
sudo systemctl restart isc-dhcp-server
journalctl -u isc-dhcp-server -n 20             # si dice "No subnet declaration", volvé al paso 1
```

### Paso 5: verificar con nmap

El script de nmap hace de cliente: manda el DISCOVER haciéndose pasar por la MAC que le indiques
y muestra la oferta. Así salió en la VM, con esta misma config:

```
DHCPDISCOVER desde la MAC AA:BB:CC:DD:EE:FF      <- una compu cualquiera
    IP Offered: 192.168.100.10                   <- la primera del range (req. 1)
    Server Identifier: 192.168.100.1             <- tu servidor: la IP del paso 1
    IP Address Lease Time: 10m00s
    Subnet Mask: 255.255.255.0
    Router: 192.168.100.1
    Domain Name Server: 8.8.8.8, 8.8.4.4         <- req. 2

DHCPDISCOVER desde la MAC 08:00:27:AE:C8:6A      <- la impresora
    IP Offered: 192.168.100.8                    <- req. 3: siempre la .8
```

## Errores típicos

| Error | Qué pasa | Cómo se nota |
|---|---|---|
| la interfaz no tiene una IP de la `subnet` | dhcpd no arranca | `No subnet declaration for enp0s9` |
| `INTERFACESv4` vacío | atiende en todas las interfaces (DHCP trucho en el lab) | — |
| IP fija **dentro** del `range` | esa IP se la puede dar también a otra compu | — |
| DNS separados por espacio en vez de coma | error de sintaxis | `dhcpd -t` lo marca |
| falta un `;` | error de sintaxis | `semicolon expected` |
| la MAC mal copiada (primer byte impar, como `0B`) | es una MAC multicast: ninguna placa la tiene | la impresora no recibe la `.8` |
| probar un `.conf` que está en tu home | AppArmor sólo deja a dhcpd leer `/etc/dhcp/` | `dhcpd -t` termina con "exiting" |

## Practicarlo en la VM

```bash
~/Protos/scripts/practicar-dhcp.sh                    # con la config del parcial 2025
~/Protos/scripts/practicar-dhcp.sh mi-dhcpd.conf      # con tu config
~/Protos/scripts/practicar-dhcp.sh ~/Protos/ejercicios/simulacro/ej4-dhcpd.conf   # simulacro
```

El script arma una red virtual (veth), le pone a la interfaz del servidor la IP de
`option routers`, levanta dhcpd sólo ahí, corre el nmap con una MAC cualquiera y con cada MAC de
los `hardware ethernet`, y al final borra todo. No toca la red real.

### Ejercicio extra: tu config de clase

`/etc/dhcp/dhcpd.conf` de la VM es la de la clase práctica (del 22/09), y tiene errores. Por eso
el servicio `isc-dhcp-server` figura como fallido. Esto dice `sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf`:

| Línea | Dice | Error de dhcpd | Corrección |
|---|---|---|---|
| 22 | `netmask 255.2555.255.0` | `2555 exceeds max (255)` | `255.255.255.0` |
| 26 | `option subset-mask` | `unknown option` | `option subnet-mask` |
| 28 | `option broadcast-adress` | `unknown option` | `option broadcast-address` |
| 30 | `default-release-time 180;` | `semicolon expected` | `default-lease-time 180;` |

Además, dhcpd no los rechaza, pero conviene corregir:

- **Línea 33**: el `host printer1` está adentro del `subnet`. dhcpd avisa "Host declarations are
  global": funciona igual, pero es más claro ponerlo afuera.
- **Línea 35**: `fixed-address 192.168.154.20` está **dentro** del range `.10`–`.200`.
- **Línea 36**: `host-name "office printer"` tiene un espacio, y un nombre de host no puede tenerlo.

Para practicar, copiala, arreglala hasta que `dhcpd -t` no dé errores, y probala:

```bash
cp /etc/dhcp/dhcpd.conf ~/clase-dhcpd.conf
~/Protos/scripts/practicar-dhcp.sh ~/clase-dhcpd.conf
```

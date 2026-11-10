# Simulacro 2

Segundo simulacro de parcial práctico de **Protocolos de Comunicación (ITBA 72.07)**, inventado
pero calcado del estilo de los parciales viejos. 4 ejercicios, todo en una sola VM por loopback.

A diferencia del [primer paquete](../practica-simulacro-parcial/), los escenarios son **más
cerrados**: te dan **pistas** (muchas en los **headers** de la respuesta, así que vas a usar
`curl -v` seguido), pero **no** el comando hecho — lo armás vos. Y los proxies son **SOCKS**, no HTTP.

## Contenido

| Archivo | Qué es |
|---|---|
| `consigna.pdf` | Las 4 consignas, para hacer a ciegas |
| `solucion.pdf` | La resolución completa paso a paso |
| `simulacro-2.sh` | El corrector: levanta, da pistas, corrige y limpia |

## Uso

```bash
S=~/Protos/practica-simulacro-2/simulacro-2.sh

$S montar    ej1      # levanta los servidores (o ej2/ej3/ej4, o 'todo')
$S verificar ej1      # corrige: OK / FALLA por requisito
$S pista     ej1      # una pista corta si estás trabado (NO te da el comando)
$S solucion  ej1      # la resolución completa (último recurso)
$S limpiar   ej1      # saca TODO lo del ejercicio
```

## Los 4 ejercicios

| Ej | Tema | Referencia (parcial viejo) |
|---|---|---|
| 1 | Túnel **SOCKS** (`socks5h`) a la intranet + **negociación de contenido** (`Accept-Language`) + Basic auth | 2024 Ej II |
| 2 | **Reverse proxy**: mandás un header → el dato vuelve en un **header de respuesta** | 2024 Ej I |
| 3 | **DNS**: corregir una zona rota (SOA, CNAME+otros datos, punto final) | 2025 Ej III |
| 4 | **Mail a mano**: Subject en **encoded-words** + header `X-Parcial` + cuerpo base64 + POP3 | 2024 Ej IV |

## Notas

- **Corre sólo en la VM** (Ubuntu). Usa `ssh -D` (el túnel SOCKS del Ej1), nginx, bind9, postfix y
  dovecot, que ya estaban.
- **No toca** tus zonas (`cachito.com`, `cachito.parcial`, `foo.pdc.lab`, …) ni tu `/var/www`: usa
  `/srv/simulacro-2`, usuarios propios (`topo`), marcadores en los configs, y `limpiar` deja todo
  como estaba (baseline `verificar-todo.sh` = 45 OK).
- Las credenciales que aparecen (`agente/topo`, `topo/topo`) son de práctica, deliberadamente
  conocidas.
- Mientras tengas montado el Ej3 (zona rota a propósito), `verificar-todo.sh` va a dar FALLA en
  `named-checkconf -z` hasta que la arregles: es lo esperable.

# 16: Editar configuraciones en la VM: vim y nano

En el parcial se editan archivos de `/etc` adentro de la VM. Hay que usar `sudo vim archivo`
o `sudo nano archivo`, o hacer `sudo -i` y después editar. Esto está basado en
`practica/Vim.md` del repo Protos-ITBA, con agregados.

## nano (el más simple)

| Tecla | Qué hace |
|---|---|
| `Ctrl+O`, `Enter` | guardar |
| `Ctrl+X` | salir (si hay cambios pregunta: `Y` / `N`) |
| `Ctrl+W` | buscar |
| `Ctrl+\` | buscar y reemplazar |
| `Ctrl+K` / `Ctrl+U` | cortar / pegar la línea |
| `Ctrl+_` | ir a la línea N (sirve cuando nginx dice "error en la línea 12") |
| `Alt+U` | deshacer |

## vim (modal)

**Supervivencia**: `i` (escribir) → editar → `Esc` → `:wq` + `Enter`. Para salir sin
guardar: `Esc` y después `:q!`. Si no sabés en qué modo estás, apretá `Esc` dos veces.

| Modo normal | Qué hace |
|---|---|
| `i` / `a` / `o` / `O` | insertar antes del cursor / después / línea nueva abajo / línea nueva arriba |
| `I` / `A` | insertar al principio / al final de la línea |
| `h j k l` (o las flechas) | moverse |
| `w` / `b` | palabra siguiente / anterior |
| `0` / `$` | principio / fin de la línea |
| `gg` / `G` / `:45` | principio / fin del archivo / línea 45 |
| `x` / `dd` / `dw` / `D` | borrar carácter / línea / palabra / hasta el fin de la línea |
| `yy` / `p` / `P` | copiar la línea / pegar abajo / pegar arriba |
| `u` / `Ctrl+r` | deshacer / rehacer |
| `/texto` + `n` / `N` | buscar / siguiente / anterior |
| `:%s/viejo/nuevo/g` | reemplazar en todo el archivo |
| `:w` / `:q` / `:wq` (= `:x`) / `:q!` | guardar / salir / guardar y salir / salir sin guardar |
| `:set number` | mostrar los números de línea |
| `:set paste` | pegar sin que se desarme la indentación (útil para pegar configs) |

## Trucos para el parcial

```bash
sudoedit /etc/nginx/sites-available/foo      # edita con tu editor y guarda como root
echo "127.0.0.1 foo" | sudo tee -a /etc/hosts    # agregar una línea sin abrir editor
#   OJO: "sudo echo ... >> /etc/hosts" NO funciona: la redirección la hace TU shell, sin sudo
sudo tee /etc/nginx/sites-available/x <<'EOF'
server { ... }
EOF
#   escribir un archivo entero desde la terminal (la heredoc con 'EOF' entre comillas no expande $variables)
```

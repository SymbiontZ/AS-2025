#!/bin/bash
set -e

echo "==> [entrypoint] Configurando servidor de correo empresa.local..."

# ─── 1. Crear usuarios del sistema ───────────────────────────────────────────
declare -A USUARIOS=(
  ["alice"]="Alice123!"
  ["bob"]="Bob123!"
  ["carlos"]="Carlos123!"
)

for usuario in "${!USUARIOS[@]}"; do
  if ! id "$usuario" &>/dev/null; then
    echo "  -> Creando usuario: $usuario"
    useradd -m -s /bin/bash "$usuario"
    echo "${usuario}:${USUARIOS[$usuario]}" | chpasswd
    # Crear estructura Maildir
    mkdir -p /home/${usuario}/Maildir/{new,cur,tmp}
    chown -R ${usuario}:${usuario} /home/${usuario}/Maildir
  else
    echo "  -> Usuario $usuario ya existe"
  fi
done

# ─── 2. Configurar Postfix ────────────────────────────────────────────────────
echo "==> [entrypoint] Iniciando Postfix..."

# Asegurar que la base de aliases existe y esta sincronizada.
newaliases

# Asegurar que /var/spool/postfix tiene la estructura correcta
postfix check 2>/dev/null || true

# Iniciar postfix en foreground via wrapper
service postfix start
echo "  -> Postfix iniciado"

# ─── 3. Configurar y arrancar Dovecot ────────────────────────────────────────
echo "==> [entrypoint] Iniciando Dovecot..."

# Asegurar permisos en el socket de auth para postfix
mkdir -p /var/spool/postfix/private

dovecot -F &
DOVECOT_PID=$!
echo "  -> Dovecot PID: $DOVECOT_PID"

# ─── 4. Banner informativo ───────────────────────────────────────────────────
echo ""
echo "========================================================="
echo "  Servidor de correo empresa.local listo"
echo "  SMTP : puerto 25  (solo red interna)"
echo "  IMAP : puerto 143"
echo ""
echo "  Usuarios creados:"
for u in "${!USUARIOS[@]}"; do
  echo "    - ${u}@empresa.local  /  pass: ${USUARIOS[$u]}"
done
echo "========================================================="
echo ""

# ─── 5. Tail logs para que el contenedor quede vivo ──────────────────────────
tail -F /var/log/mail.log 2>/dev/null &

# Esperar a que Dovecot termine (mantiene el contenedor activo)
wait $DOVECOT_PID

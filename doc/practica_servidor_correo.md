# Práctica: Servidor de Correo Interno (Postfix + Dovecot)

## Información general

| Parámetro | Valor |
|-----------|-------|
| Dominio de correo | `empresa.local` |
| IP del servidor de correo | `172.20.0.20` |
| Protocolo envío | SMTP — puerto **25** |
| Protocolo recepción | IMAP — puerto **143** |
| Usuarios de prueba | `alice`, `bob`, `carlos` |

> [!IMPORTANT]
> Antes de empezar, asegúrate de que la red `services_net` ya existe:
> `docker network ls | grep services_net`
> Si no existe: `docker network create --subnet 172.20.0.0/24 services_net`

---

## Parte 0 — Despliegue del servicio

### 0.1 Construir e iniciar el stack

```bash
cd ~/AS-2025/stacks/services
docker compose up -d --build mail_server
```

### 0.2 Verificar que el contenedor arranca correctamente

```bash
docker ps | grep mail_server
docker logs -f mail_server
```

Espera ver el banner:
```
=========================================================
  Servidor de correo empresa.local listo
  SMTP : puerto 25  (solo red interna)
  IMAP : puerto 143
=========================================================
```

---

## Parte 1 — Verificación DNS

El servidor DNS interno debe resolver tanto el nombre del servidor como el registro MX.

### 1.1 Resolver el registro A del servidor de correo

```bash
dig @172.20.0.10 mail.empresa.local A
```

**Resultado esperado:** `mail.empresa.local. 86400 IN A 172.20.0.20`

### 1.2 Resolver el registro MX del dominio

```bash
dig @172.20.0.10 empresa.local MX
```

**Resultado esperado:** `empresa.local. 86400 IN MX 10 mail.empresa.local.`

### 1.3 Resolución inversa (PTR)

```bash
dig @172.20.0.10 -x 172.20.0.20
```

**Resultado esperado:** `20.0.20.172.in-addr.arpa. 86400 IN PTR mail.empresa.local.`

> [!NOTE]
> Si el DNS server no está corriendo, reinícialo primero:
> `docker compose up -d dns_server`
> Y recarga las zonas sin reiniciar: `docker exec dns_server rndc reload`

---

## Parte 2 — Creación y verificación de usuarios

Los usuarios `alice`, `bob` y `carlos` se crean automáticamente al arrancar el contenedor.

```bash
docker exec mail_server getent passwd alice bob carlos
```

Comprueba que cada usuario tiene su directorio `Maildir` creado:

```bash
docker exec mail_server ls -la /home/alice/Maildir/
docker exec mail_server ls -la /home/bob/Maildir/
docker exec mail_server ls -la /home/carlos/Maildir/
```

Para crear usuarios adicionales manualmente dentro del contenedor:

```bash
docker exec -it mail_server bash

# Dentro del contenedor:
useradd -m -s /bin/bash diana
echo "diana:Diana123!" | chpasswd
mkdir -p /home/diana/Maildir/{new,cur,tmp}
chown -R diana:diana /home/diana/Maildir
exit
```

---

## Parte 3 — Envío de correo (SMTP)

### 3.1 Enviar correo con `mail` desde dentro del contenedor

```bash
docker exec -it mail_server bash

# Enviar un correo de alice a bob
echo "Hola Bob, soy Alice. Esto es una prueba." \
  | mail -s "Prueba desde Alice" \
         -r "alice@empresa.local" \
         bob@empresa.local

# Enviar correo de bob a carlos
echo "Hola Carlos, mensaje de Bob." \
  | mail -s "Saludo de Bob" \
         -r "bob@empresa.local" \
         carlos@empresa.local
```

### 3.2 Enviar correo con `swaks` (SMTP explícito)

`swaks` muestra toda la conversación SMTP protocolar.

```bash
docker exec -it mail_server bash

swaks \
  --to bob@empresa.local \
  --from alice@empresa.local \
  --server 172.20.0.20 \
  --port 25 \
  --header "Subject: Test SMTP con swaks" \
  --body "Mensaje de prueba enviado con swaks."
```

**Resultado esperado:** `=== Transaction completed successfully`

### 3.3 Envío manual con `telnet` (diálogo SMTP a mano)

```bash
docker exec -it mail_server bash
telnet 172.20.0.20 25
```

Diálogo SMTP completo:

```
EHLO mail.empresa.local
MAIL FROM:<carlos@empresa.local>
RCPT TO:<alice@empresa.local>
DATA
Subject: Correo manual via telnet
From: carlos@empresa.local
To: alice@empresa.local

Hola Alice. Este mensaje fue enviado manualmente con telnet.
.
QUIT
```

> [!TIP]
> El punto `.` solo en una línea indica el fin del cuerpo del mensaje (fin de DATA).

---

## Parte 4 — Consulta de buzones (IMAP)

### 4.1 Verificar correos en el sistema de archivos

```bash
# Ver correos nuevos de bob (carpeta new/)
docker exec mail_server ls -la /home/bob/Maildir/new/

# Leer un correo específico
docker exec mail_server cat /home/bob/Maildir/new/<nombre_fichero>
```

### 4.2 Acceder al buzón via IMAP con `telnet`

El protocolo IMAP requiere un **tag** al inicio de cada comando (`a1`, `a2`, …).

```bash
telnet 172.20.0.20 143
```

Sesión IMAP completa:

```
# El servidor responde: * OK Dovecot ready
a1 LOGIN bob Bob123!
a2 LIST "" "*"
a3 SELECT INBOX
a4 STATUS INBOX (MESSAGES UNSEEN RECENT)
a5 FETCH 1 (BODY[HEADER])
a6 FETCH 1 (BODY[TEXT])
a7 LOGOUT
```

**Comandos clave:**

| Comando IMAP | Descripción |
|---|---|
| `LOGIN user pass` | Autenticación |
| `LIST "" "*"` | Listar buzones disponibles |
| `SELECT INBOX` | Abrir la bandeja de entrada |
| `STATUS INBOX (MESSAGES UNSEEN)` | Contar mensajes y no leídos |
| `FETCH N (BODY[HEADER])` | Leer cabeceras del mensaje N |
| `FETCH N (BODY[TEXT])` | Leer cuerpo del mensaje N |
| `LOGOUT` | Cerrar sesión |

---

## Parte 5 — Revisión de logs del sistema

### 5.1 Ver logs en tiempo real del contenedor

```bash
docker logs -f mail_server
```

### 5.2 Ver log de correo del sistema (dentro del contenedor)

```bash
docker exec -it mail_server bash

# Últimas 50 líneas del log
tail -n 50 /var/log/mail.log

# Solo entregas exitosas
grep "status=sent" /var/log/mail.log

# Solo errores y rechazos
grep "status=bounced\|reject\|error" /var/log/mail.log
```

### 5.3 Seguir el log mientras se envía un correo

Abre dos terminales simultáneamente:

**Terminal 1** — Monitoriza el log:
```bash
docker exec mail_server tail -F /var/log/mail.log
```

**Terminal 2** — Envía un correo:
```bash
docker exec mail_server bash -c \
  "echo 'Prueba log' | mail -s 'Log test' -r alice@empresa.local bob@empresa.local"
```

Observa las líneas de log de cada componente de Postfix:

| Componente | Qué registra |
|---|---|
| `postfix/smtpd` | Conexión SMTP entrante |
| `postfix/cleanup` | Limpieza y normalización de cabeceras |
| `postfix/qmgr` | Gestión de la cola de mensajes |
| `postfix/local` | Entrega local al buzón del usuario |

---

## Parte 6 — Auditoría de seguridad: Anti-relay abierto

Un **relay abierto** es un servidor SMTP que reenvía correo de cualquier origen a cualquier destino sin restricciones — un grave fallo de seguridad que convierte el servidor en fuente de spam.

### 6.1 Verificar la configuración anti-relay

```bash
docker exec mail_server postconf mynetworks
docker exec mail_server postconf smtpd_relay_restrictions
```

**Resultado esperado:**
```
mynetworks = 127.0.0.0/8, 172.20.0.0/24
smtpd_relay_restrictions = permit_mynetworks, reject_unauth_destination
```

### 6.2 Prueba desde la red interna (debe funcionar) ✅

```bash
docker exec -it mail_server bash

swaks \
  --to alice@empresa.local \
  --from bob@empresa.local \
  --server 172.20.0.20 \
  --port 25
```

**Resultado esperado:** `250 2.0.0 Ok: queued`

### 6.3 Prueba de relay hacia dominio externo (debe ser rechazado) ✅

```bash
docker exec -it mail_server bash

swaks \
  --to test@gmail.com \
  --from alice@empresa.local \
  --server 172.20.0.20 \
  --port 25
```

**Resultado esperado:** `554 5.7.1 Relay access denied`

### 6.4 Prueba de relay desde IP externa (debe ser rechazado) ✅

Desde el **host** (fuera de la red `172.20.0.0/24`), con el puerto 25 expuesto:

```bash
swaks \
  --to bob@empresa.local \
  --from hacker@externo.com \
  --server localhost \
  --port 25
```

**Resultado esperado:** `554 5.7.1 Relay access denied`

> [!CAUTION]
> Si el servidor responde `250 Ok` a las pruebas 6.3 o 6.4, el servidor ES un relay abierto. Debe corregirse revisando `mynetworks` y `smtpd_relay_restrictions` en `/etc/postfix/main.cf`.

---

## Parte 7 — Tabla resumen de verificaciones

| # | Verificación | Comando clave | Resultado esperado |
|---|---|---|---|
| 1 | DNS — Registro A | `dig @172.20.0.10 mail.empresa.local A` | `172.20.0.20` |
| 2 | DNS — Registro MX | `dig @172.20.0.10 empresa.local MX` | `10 mail.empresa.local.` |
| 3 | DNS — Registro PTR | `dig @172.20.0.10 -x 172.20.0.20` | `mail.empresa.local.` |
| 4 | Usuarios creados | `docker exec mail_server getent passwd alice` | Línea con datos del usuario |
| 5 | SMTP interno OK | `swaks --to bob@empresa.local --server 172.20.0.20` | `250 Ok: queued` |
| 6 | IMAP login OK | Telnet 143 → `LOGIN alice Alice123!` | `a1 OK Logged in` |
| 7 | Mensaje recibido | `ls /home/bob/Maildir/new/` | Fichero con el correo |
| 8 | Log entrega | `grep "status=sent" /var/log/mail.log` | Línea con la entrega |
| 9 | Anti-relay externo | `swaks --to test@gmail.com --server 172.20.0.20` | `554 Relay access denied` |
| 10 | Anti-relay origen | `swaks --from hacker@externo.com --server localhost` | `554 Relay access denied` |

---

## Apéndice — Estructura de ficheros del servicio

```
stacks/services/
├── compose.yml                   ← Añadido: servicio mail_server (172.20.0.20)
└── mail/
    ├── Dockerfile                ← Ubuntu 22.04 + Postfix + Dovecot
    ├── entrypoint.sh             ← Crea usuarios, inicia servicios
    ├── postfix/
    │   ├── main.cf               ← Configuración principal de Postfix
    │   └── master.cf             ← Servicios Postfix (SMTP, local...)
    └── dovecot/
        ├── dovecot.conf          ← Configuración principal de Dovecot
        ├── 10-auth.conf          ← Autenticación PAM (usuarios del sistema)
        ├── 10-mail.conf          ← Ubicación buzones: ~/Maildir
        ├── 10-master.conf        ← Listeners IMAP (143) y socket auth
        └── 15-mailboxes.conf     ← Carpetas estándar (INBOX, Sent, Trash...)
```

## Apéndice — Credenciales de usuarios

| Usuario | Contraseña | Email |
|---------|-----------|-------|
| alice | `Alice123!` | alice@empresa.local |
| bob | `Bob123!` | bob@empresa.local |
| carlos | `Carlos123!` | carlos@empresa.local |

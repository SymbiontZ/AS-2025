# Informe de Auditoría y Seguridad: Anti Open Relay (Bonus 2)

## 1. Contexto y Problema Detectado

La empresa detectó que la configuración del servidor SMTP (Postfix) era demasiado permisiva, posibilitando su uso como un "Open Relay". Esto ocurre cuando un servidor de correo acepta y reenvía mensajes hacia dominios externos enviados por usuarios o direcciones IP no confiables ni autenticadas. El principal riesgo de un Open Relay es que el servidor termine en listas negras (blacklists) al ser explotado para el envío masivo de spam.

## 2. Decisiones de Diseño y Configuración

Para solucionar este problema de seguridad y cumplir con los requisitos de la empresa (permitir envío interno, bloquear externos no autenticados, y permitir externos autenticados), se optó por implementar **Autenticación SASL** integrada con **Dovecot**. 

Dado que Dovecot ya estaba configurado para servir un socket de autenticación en `/var/spool/postfix/private/auth`, la decisión técnica fue indicarle a Postfix que delegara la validación de credenciales a Dovecot y ajustara las restricciones de relay de acuerdo a esto.

### Modificaciones en `/etc/postfix/main.cf`

Se añadieron las directivas necesarias para habilitar SASL y se ajustó la regla de relay (`smtpd_relay_restrictions`) para permitir el acceso a los usuarios que se validan correctamente:

```ini
# Autenticación SASL mediante Dovecot
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous

# Rechazar relay para orígenes externos, pero permitir autenticados
smtpd_relay_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination
```

1. **`permit_mynetworks`**: Permite a cualquier equipo dentro de la subred interna (`172.20.0.0/24`) hacer relay libremente, tal y como se requería.
2. **`permit_sasl_authenticated`**: Permite hacer relay hacia el exterior a cualquier usuario que demuestre conocer las credenciales (por ejemplo, los trabajadores teletrabajando fuera de la red local).
3. **`reject_unauth_destination`**: Bloquea todo intento de relay que no cumpla las condiciones anteriores (bloqueando a los spammers).

## 3. Pruebas y Evidencias de Ejecución

Para validar la configuración, se utilizaron comandos SMTP explícitos (`swaks`) simulando las diferentes casuísticas. Dado que las pruebas desde IPs externas se dificultan por el proxy/gateway de Docker (el cual enmascara la IP origen como si fuese interna), se utilizó la herramienta `postconf` para remover temporalmente la red local (`172.20.0.0/24`) de las redes de confianza (`mynetworks`), forzando a Postfix a tratar las conexiones como totalmente externas.

### Prueba 1: Relay externo no autenticado (Rechazado)

Se intentó enviar un correo hacia un dominio externo (`test@gmail.com`) sin aportar credenciales. Como se esperaba, el servidor lo bloqueó proactivamente al no pertenecer la IP a `mynetworks` ni tener sesión iniciada.

**Comando:**
```bash
swaks --to test@gmail.com --from alice@empresa.local --server 172.20.0.50 --port 25
```

**Respuesta del servidor (Evidencia):**
```text
=== Connected to 172.20.0.50.
<-  220 mail.empresa.local ESMTP Postfix
 -> EHLO mail.empresa.local
[...]
 -> MAIL FROM:<alice@empresa.local>
<-  250 2.1.0 Ok
 -> RCPT TO:<test@gmail.com>
<** 554 5.7.1 <test@gmail.com>: Relay access denied
 -> QUIT
```
*Conclusión: Intento bloqueado con código de error 554. El servidor ya no es un Open Relay.*

### Prueba 2: Relay externo autenticado con SASL (Aceptado)

Se repitió la prueba externa hacia `test@gmail.com`, pero esta vez inyectando las credenciales válidas del usuario `alice` (`Alice123!`).

**Comando:**
```bash
swaks --to test@gmail.com --from alice@empresa.local \
      --server 172.20.0.50 --port 25 \
      --auth LOGIN --auth-user alice --auth-password "Alice123!"
```

**Respuesta del servidor (Evidencia):**
```text
=== Connected to 172.20.0.50.
[...]
 -> AUTH LOGIN
<-  334 VXNlcm5hbWU6
 -> YWxpY2U=
<-  334 UGFzc3dvcmQ6
 -> QWxpY2UxMjMh
<-  235 2.7.0 Authentication successful
 -> MAIL FROM:<alice@empresa.local>
<-  250 2.1.0 Ok
 -> RCPT TO:<test@gmail.com>
<-  250 2.1.5 Ok
 -> DATA
[...]
<-  250 2.0.0 Ok: queued as BE1BE8278
 -> QUIT
```
*Conclusión: La validación delegada a Dovecot (Authentication successful) autoriza el relay correctamente.*

## 4. Conclusión

El entorno de correo está correctamente securizado. Los usuarios locales pueden operar transparentemente dentro de la intranet, los spammers y atacantes externos son bloqueados (previniendo listas negras) y los teletrabajadores pueden enviar correos legítimamente previa autenticación segura (SASL).

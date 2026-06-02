# AS-2025

Repositorio de prácticas para el despliegue de una infraestructura de servicios con Docker. El proyecto está organizado por bloques funcionales para poder levantar cada parte por separado según el entorno: red, servicios compartidos, desarrollo, producción y VPN.

La propuesta reproduce una pequeña red de empresa con DNS, correo, SSH, copias de seguridad, servidores web, acceso remoto y reglas de encaminamiento entre subredes. Cada bloque mantiene su propia configuración para facilitar las pruebas y el mantenimiento.

## Estructura del proyecto

- `stacks/network/`: red base, reglas de iptables, DHCP y arranque del gateway.
- `stacks/services/`: DNS, correo, servidor SSH y tareas de backup.
- `stacks/development/`: entorno de pruebas con MySQL, Apache, FTP y SSH con 2FA.
- `stacks/production/`: entorno publicado con PostgreSQL, Nginx y proxy FTP.
- `stacks/vpn/`: servidor WireGuard y plantillas para perfiles de cliente.
- `scripts/`: utilidades para crear redes, usuarios, pares VPN, claves y comprobaciones.
- `doc/`: memoria y documentación del trabajo.

## Requisitos

Antes de desplegar el entorno es necesario contar con:

- Docker y Docker Compose.
- Permisos para crear redes y ejecutar contenedores.
- Un entorno compatible con Bash para los scripts del repositorio.
- Ficheros `.env` configurados en `stacks/development/`, `stacks/production/` y `stacks/vpn/` cuando el stack lo requiera.

## Despliegue básico

Primero se crean las redes necesarias. El resto de servicios depende de esas subredes para comunicarse correctamente.

```bash
chmod +x scripts/create-networks.sh
./scripts/create-networks.sh
```

Después se puede iniciar los stacks de docker:

```bash
chmod +x scripts/exec-containers.sh
./scripts/exec-containers.sh
```

No es necesario desplegar todo a la vez. Lo habitual es levantar primero red y servicios compartidos, y después añadir desarrollo, producción o VPN según la práctica que se esté revisando.

## Servicios incluidos

### Red

El stack de red concentra el enrutamiento entre subredes y la configuración DHCP. Es la base sobre la que se apoyan el resto de contenedores.

### Servicios

Este bloque agrupa los servicios compartidos de la empresa:

- DNS con BIND9.
- Correo con Postfix y Dovecot.
- SSH centralizado para administración.
- Backups periódicos de bases de datos.

### Desarrollo

El entorno de desarrollo incluye servicios útiles para pruebas internas:

- MySQL.
- Apache HTTP Server.
- Samba y FTP.
- SSH con autenticación en dos factores.

### Producción

El entorno de producción separa los servicios publicados:

- PostgreSQL.
- Nginx como servidor frontal.
- Proxy FTP.

### VPN

La VPN está implementada con WireGuard y se apoya en plantillas para generar perfiles de cliente. El objetivo es permitir acceso remoto a la red interna de forma controlada.

## Scripts útiles

Los scripts de `scripts/` automatizan tareas repetitivas del proyecto. Los más relevantes son:

- `create-networks.sh`: crea las redes Docker del laboratorio.
- `create-ssh-2fa-user.sh`: añade usuarios para el servicio SSH con 2FA.
- `create-vpn-peer.sh`: genera un nuevo cliente WireGuard.
- `generate-share-ssh-key.sh`: prepara claves SSH compartidas.
- `recreate-ssh-secrets.sh`: regenera secretos del servicio SSH.
- `recreate-vpn-clients.sh`: vuelve a crear perfiles de cliente VPN.
- `recrerate-rndc-key.sh`: regenera la clave RNDC de BIND.
- `verify-dhcp.sh`: comprueba la configuración DHCP.
- `verify-dns-zones.sh`: valida las zonas DNS.

## Notas de uso

- Algunos contenedores dependen de rutas IP concretas, así que conviene revisar la configuración antes de modificar puertos o subredes.
- Los ficheros de configuración están separados por stack para facilitar el mantenimiento.
- Si se cambia un fichero `.env`, normalmente hay que recrear los contenedores afectados para que tomen los nuevos valores.

## Documentación

La memoria y los informes del trabajo están en la carpeta `doc/`. Si se necesita contexto sobre una práctica concreta, ese es el primer sitio donde revisar decisiones, pruebas y resultados.

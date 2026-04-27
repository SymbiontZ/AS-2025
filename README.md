# AS-2025

## Setup rápido en Ubuntu Server (Docker + Compose)

1) Clona el repo en la VM:

```bash
git clone <TU_URL_DEL_REPO>
cd AS-2025
```

2) Ejecuta el script de instalación:

```bash
chmod +x scripts/setup-docker-ubuntu.sh
./scripts/setup-docker-ubuntu.sh
```

## Crear redes Docker + (opcional) arrancar pfSense

Si tu Ubuntu Server es el host donde corre Docker y además ejecuta pfSense como VM (KVM/libvirt), puedes usar:

```bash
chmod +x scripts/provision-docker-networks-and-pfsense.sh
sudo ./scripts/provision-docker-networks-and-pfsense.sh
```

Variables útiles:
- `PFSENSE_MODE=libvirt|none` (por defecto `libvirt`)
- `PFSENSE_DOMAIN=pfsense` (nombre del dominio en `virsh`)

Notas:
- Compose crea redes automáticamente salvo que uses `external: true`.
- Si pfSense está en otro hypervisor (Proxmox/ESXi/VirtualBox) o es hardware, no se “inicia” desde Ubuntu: en ese caso usa su herramienta (`qm start`, API, etc.) y deja `PFSENSE_MODE=none`.

3) Abre una nueva sesión (o cierra y reabre SSH) para aplicar el grupo `docker`.

4) Levanta un stack (cuando tengas el `compose.yml` definido):

```bash
docker compose -f stacks/development/compose.yml up -d
```

## Bootstrap de configuracion SSH (antes de levantar servicios)

El servicio `ssh_manager` espera que exista `stacks/services/ssh/config/.ssh/authorized_keys`.
Si no existe, inicializalo con:

```bash
chmod +x scripts/init-ssh-config.sh
./scripts/init-ssh-config.sh
```

Despues agrega tu clave publica en:

```text
stacks/services/ssh/config/.ssh/authorized_keys
```

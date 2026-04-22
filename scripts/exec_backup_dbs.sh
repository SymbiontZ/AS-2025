#!/bin/bash
# exec-backup-dbs.sh
# Intended to be run from inside the NAS container.

# Configuracion
BACKUP_DEST_DIR="/backups/daily"
TMP_DUMP_DIR="/tmp/db_dumps"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$BACKUP_DEST_DIR/backup.log"
STATUS_LOG="/var/log/backup_status.log"

# IPs Base de datos
PG_HOST="${PG_HOST:-172.20.0.21}"
PG_USER="${PG_USER:-${POSTGRES_USER:-as2025}}"
PG_DB="${PG_DB:-${POSTGRES_DATABASE:-as2025}}"

MY_HOST="${MY_HOST:-172.20.0.20}"
MY_USER="${MY_USER:-${MYSQL_USER:-as2025}}"
MY_DB="${MY_DB:-${MYSQL_DATABASE:-as2025}}"

# Existen los directorios
mkdir -p "$BACKUP_DEST_DIR"
mkdir -p "$TMP_DUMP_DIR"

echo "[$TIMESTAMP] START: Database backups" >> "$LOG_FILE"

# Cron can run with a stripped environment. If key vars are missing,
# import the container runtime environment from PID 1.
if [ -z "${POSTGRES_PASSWORD:-}" ] || [ -z "${MYSQL_PASSWORD:-}" ]; then
    if [ -r /proc/1/environ ]; then
        while IFS= read -r -d '' kv; do
            case "$kv" in
                *=*) export "$kv" ;;
            esac
        done < /proc/1/environ
    fi
fi

# Credenciales: preferimos variables ya exportadas y hacemos fallback a variables de compose
if [ -z "${PGPASSWORD:-}" ]; then
    if [ -n "${POSTGRES_PASSWORD:-}" ]; then
        export PGPASSWORD="$POSTGRES_PASSWORD"
    else
        echo "[$TIMESTAMP] ERROR: PGPASSWORD/POSTGRES_PASSWORD no definida." >> "$LOG_FILE"
        echo "[$TIMESTAMP] FAILED - Missing PostgreSQL password env var." >> "$STATUS_LOG"
        exit 1
    fi
fi

if [ -z "${MYSQL_PWD:-}" ]; then
    if [ "$MY_USER" = "root" ] && [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
        export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
    elif [ "$MY_USER" != "root" ] && [ -n "${MYSQL_PASSWORD:-}" ]; then
        export MYSQL_PWD="$MYSQL_PASSWORD"
    elif [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
        # Last resort when only root password is available in environment.
        export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
    else
        echo "[$TIMESTAMP] ERROR: MYSQL_PWD/MYSQL_ROOT_PASSWORD no definida para usuario $MY_USER." >> "$LOG_FILE"
        echo "[$TIMESTAMP] FAILED - Missing MySQL password env var." >> "$STATUS_LOG"
        exit 1
    fi
fi

# 1. PostgreSQL Backup
PG_FILE="$TMP_DUMP_DIR/pg_backup_$TIMESTAMP.sql"
echo "[$TIMESTAMP] Running pg_dump..." >> "$LOG_FILE"
pg_dump -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" > "$PG_FILE"
if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] SUCCESS: PostgreSQL backup completed." >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] ERROR: PostgreSQL backup failed." >> "$LOG_FILE"
fi

# 2. MySQL Backup
MY_FILE="$TMP_DUMP_DIR/mysql_backup_$TIMESTAMP.sql"
echo "[$TIMESTAMP] Running mysqldump..." >> "$LOG_FILE"
mysqldump -h "$MY_HOST" -u "$MY_USER" --databases "$MY_DB" --no-tablespaces > "$MY_FILE"
if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] SUCCESS: MySQL backup completed." >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] ERROR: MySQL backup failed." >> "$LOG_FILE"
fi

# 3. Rsync al destino
echo "[$TIMESTAMP] Running rsync to move dumps to $BACKUP_DEST_DIR..." >> "$LOG_FILE"
# Sync from tmp to persistent volume, --remove-source-files deletes them from tmp after success
rsync -av --remove-source-files "$TMP_DUMP_DIR/" "$BACKUP_DEST_DIR/" >> "$LOG_FILE" 2>&1
RSYNC_EXIT_CODE=$?

# ==========================================
# 4. VERIFICACION
# ==========================================
PG_TARGET="$BACKUP_DEST_DIR/pg_backup_$TIMESTAMP.sql"
MY_TARGET="$BACKUP_DEST_DIR/mysql_backup_$TIMESTAMP.sql"

# 1. Verificar salida
if [ ${RSYNC_EXIT_CODE} -ne 0 ]; then
    echo "[$TIMESTAMP] FAILED - Rsync exit code: ${RSYNC_EXIT_CODE}" >> "$STATUS_LOG"
    echo "[$TIMESTAMP] ERROR: Rsync encountered an error." >> "$LOG_FILE"
    exit 1
fi

# 2. Verificar que existen los archivos
if [ ! -f "${PG_TARGET}" ] || [ ! -f "${MY_TARGET}" ]; then
    echo "[$TIMESTAMP] FAILED - One or more backup files not found in destination." >> "$STATUS_LOG"
    exit 1
fi

# 3. Verificar tamaño
PG_SIZE=$(stat -c%s "${PG_TARGET}" 2>/dev/null || stat -f%z "${PG_TARGET}" 2>/dev/null)
MY_SIZE=$(stat -c%s "${MY_TARGET}" 2>/dev/null || stat -f%z "${MY_TARGET}" 2>/dev/null)

if [ -z "${PG_SIZE}" ] || [ "${PG_SIZE}" -eq 0 ] || [ -z "${MY_SIZE}" ] || [ "${MY_SIZE}" -eq 0 ]; then
    echo "[$TIMESTAMP] FAILED - One or more backup files are empty (Size: 0 bytes)." >> "$STATUS_LOG"
    exit 1
fi

echo "[$TIMESTAMP] SUCCESS - Backups verified successfully." >> "$STATUS_LOG"
echo "[$TIMESTAMP] SUCCESS: Rsync and verification completed successfully." >> "$LOG_FILE"

echo "[$TIMESTAMP] END: Database backups" >> "$LOG_FILE"
echo "--------------------------------------------------------" >> "$LOG_FILE"

#!/bin/bash
# backup_dbs.sh
# Intended to be run from inside the NAS container.

# Configuracion
BACKUP_DEST_DIR="/backups/daily"
TMP_DUMP_DIR="/tmp/db_dumps"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$BACKUP_DEST_DIR/backup.log"
STATUS_LOG="/var/log/backup_status.log"

# IPs Base de datos
PG_HOST="172.20.0.30"
PG_USER="postgres"
PG_DB="postgres"

MY_HOST="172.20.0.40"
MY_USER="root"

# Existen los directorios
mkdir -p "$BACKUP_DEST_DIR"
mkdir -p "$TMP_DUMP_DIR"

echo "[$TIMESTAMP] START: Database backups" >> "$LOG_FILE"

# 1. PostgreSQL Backup
PG_FILE="$TMP_DUMP_DIR/pg_backup_$TIMESTAMP.sql"
echo "[$TIMESTAMP] Running pg_dump..." >> "$LOG_FILE"
# Contraseñas en el .env
PGPASSWORD="${PGPASSWORD:-your_pg_password}" pg_dump -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" > "$PG_FILE"
if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] SUCCESS: PostgreSQL backup completed." >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] ERROR: PostgreSQL backup failed." >> "$LOG_FILE"
fi

# 2. MySQL Backup
MY_FILE="$TMP_DUMP_DIR/mysql_backup_$TIMESTAMP.sql"
echo "[$TIMESTAMP] Running mysqldump..." >> "$LOG_FILE"
# Contraseñas en el .env
MYSQL_PWD="${MYSQL_PWD:-your_mysql_password}" mysqldump -h "$MY_HOST" -u "$MY_USER" --all-databases > "$MY_FILE"
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

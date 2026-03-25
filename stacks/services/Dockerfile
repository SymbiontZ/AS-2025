FROM ubuntu:22.04

# Assuming a Debian/Ubuntu base image - installing required DB clients for the dump commands to work
RUN apt-get update && apt-get install -y cron rsync postgresql-client default-mysql-client

# Copy your backup script and the crontab definition, relative to the root project context
COPY scripts/backup_dbs.sh /usr/local/bin/backup_dbs.sh
COPY stacks/services/crontab /etc/cron.d/backup-cron

# Apply execution permissions and register the crontab
RUN chmod +x /usr/local/bin/backup_dbs.sh && \
    chmod 0644 /etc/cron.d/backup-cron && \
    crontab /etc/cron.d/backup-cron

# CRITICAL: Start cron in the foreground so the container doesn't exit
CMD ["cron", "-f"]

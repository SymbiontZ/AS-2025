FROM ubuntu:22.04

# Install required tools and PostgreSQL official apt repo to get pg_dump 16.
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    cron \
    rsync \
    default-mysql-client && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && apt-get install -y postgresql-client-16 && \
    rm -rf /var/lib/apt/lists/*

# Copy your backup script and the crontab definition, relative to the root project context
COPY scripts/backup_dbs.sh /usr/local/bin/backup_dbs.sh
COPY stacks/services/crontab /etc/cron.d/backup-cron

# Normalize line endings in case files were edited on Windows (CRLF -> LF)
RUN sed -i 's/\r$//' /usr/local/bin/backup_dbs.sh /etc/cron.d/backup-cron && \
    printf '\n' >> /etc/cron.d/backup-cron

# Apply execution permissions and register the crontab
RUN chmod +x /usr/local/bin/backup_dbs.sh && \
    chmod 0644 /etc/cron.d/backup-cron && \
    crontab /etc/cron.d/backup-cron

# CRITICAL: Start cron in the foreground so the container doesn't exit
CMD ["cron", "-f"]

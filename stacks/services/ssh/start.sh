#!/bin/bash
# Copy authorized_keys, stripping any Windows CRLF line endings that would break SSH parsing
if [ -f "/tmp/authorized_keys" ]; then
    tr -d '\r' < /tmp/authorized_keys > /home/admin_user/.ssh/authorized_keys
    chown admin_user:root /home/admin_user/.ssh/authorized_keys
    chmod 600 /home/admin_user/.ssh/authorized_keys
fi

# Start ssh daemon in foreground and echo logs to stderr so docker logs can capture them
exec /usr/sbin/sshd -D -e

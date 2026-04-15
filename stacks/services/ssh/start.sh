#!/bin/bash
# Copy authorized_keys from the mounted read-only volume to the actual .ssh directory
if [ -f "/tmp/authorized_keys" ]; then
    cp /tmp/authorized_keys /home/admin_user/.ssh/authorized_keys
    chown admin_user:root /home/admin_user/.ssh/authorized_keys
    chmod 600 /home/admin_user/.ssh/authorized_keys
fi

# Start ssh daemon in foreground
exec /usr/sbin/sshd -D

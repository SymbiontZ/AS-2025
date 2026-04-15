#!/bin/bash
# Ensure strict permissions on authorized_keys before starting SSH daemon
if [ -f "/home/admin_user/.ssh/authorized_keys" ]; then
    chmod 600 /home/admin_user/.ssh/authorized_keys
    chown admin_user:root /home/admin_user/.ssh/authorized_keys
fi

# Start ssh daemon in foreground
exec /usr/sbin/sshd -D

#!/bin/bash
echo "--- Starting SSH Container Initializations ---"

if [ -f "/tmp/authorized_keys" ]; then
    echo "Found /tmp/authorized_keys. Processing..."
    tr -d '\r' < /tmp/authorized_keys > /home/admin_user/.ssh/authorized_keys
    chown admin_user:root /home/admin_user/.ssh/authorized_keys
    chmod 600 /home/admin_user/.ssh/authorized_keys
elif [ -d "/tmp/authorized_keys" ]; then
    echo "ERROR: /tmp/authorized_keys is mounted as a DIRECTORY, not a file! Check your host machine."
else
    echo "ERROR: /tmp/authorized_keys not found at all."
fi

echo "Checking permissions of /home/admin_user/.ssh :"
ls -la /home/admin_user/.ssh/

echo "Checking authorized_keys existence and content:"
if [ -f "/home/admin_user/.ssh/authorized_keys" ]; then
    cat /home/admin_user/.ssh/authorized_keys
else
    echo "NO AUTHORIZED KEYS FILE EXISTS."
fi

echo "--- Starting SSHD ---"
exec /usr/sbin/sshd -D -e

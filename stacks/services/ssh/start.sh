#!/bin/bash
echo "--- Starting SSH Container Initializations ---"

# The user invariably mounts to /home/admin_user/.ssh/authorized_keys:ro
# We read from there, strip the Windows carriage returns, and save to /etc/ssh/admin_keys (where sshd_config now looks)
if [ -f "/home/admin_user/.ssh/authorized_keys" ]; then
    tr -d '\r' < /home/admin_user/.ssh/authorized_keys > /etc/ssh/admin_keys
    chown admin_user:root /etc/ssh/admin_keys
    chmod 600 /etc/ssh/admin_keys
    echo "Keys processed and secured successfully."
else
    echo "ERROR: /home/admin_user/.ssh/authorized_keys not found."
fi

exec /usr/sbin/sshd -D -e

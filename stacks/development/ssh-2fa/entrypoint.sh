#!/bin/bash
set -e

echo "--- Initializing SSH Server with 2FA ---"

if [ -f "/etc/ssh-2fa/users.conf" ]; then
    echo "Reading users from /etc/ssh-2fa/users.conf..."
    # Format: username:password
    while IFS=':' read -r username password; do
        # Ignore comments and empty lines
        [[ "$username" =~ ^#.*$ ]] && continue
        [[ -z "$username" ]] && continue
        
        # Check if user exists
        if ! id "$username" >/dev/null 2>&1; then
            echo "Creating user $username..."
            useradd -m -s /bin/bash "$username"
            echo "$username:$password" | chpasswd
        fi

        # Setup Google Authenticator if not already setup
        if [ ! -f "/home/$username/.google_authenticator" ]; then
            echo "Generating Google Authenticator config for $username..."
            # Generate config: time-based, rate-limit 3 logins/30s, window size 3
            # Disallow reuse of tokens, force secret to be written to file.
            su - "$username" -c "google-authenticator -t -d -f -r 3 -R 30 -w 3 -q"
            echo "========================================================="
            echo "   GOOGLE AUTHENTICATOR SECRET FOR USER: $username       "
            echo "========================================================="
            cat "/home/$username/.google_authenticator" | head -n 1
            echo "========================================================="
        fi
    done < /etc/ssh-2fa/users.conf
else
    echo "WARNING: /etc/ssh-2fa/users.conf not found. No users will be created."
fi

echo "Starting SSH Daemon..."
exec /usr/sbin/sshd -D -e

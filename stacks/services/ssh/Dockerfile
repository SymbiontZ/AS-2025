FROM ubuntu:22.04

# Avoid prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Update system and install OpenSSH server
RUN apt-get update && \
    apt-get install -y openssh-server sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create privilege separation directory
RUN mkdir -p /run/sshd

# Ensure the admin user exists
RUN useradd -rm -d /home/admin_user -s /bin/bash -g root -G sudo -u 1000 admin_user

# Create .ssh directory and ensure correct permissions
RUN mkdir -p /home/admin_user/.ssh && \
    chown admin_user:root /home/admin_user/.ssh && \
    chmod 700 /home/admin_user/.ssh

# Copy the custom hardened sshd_config
COPY sshd_config /etc/ssh/sshd_config
# We use an entrypoint script to ensure the authorized_keys mounts with correct permissions
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 22

CMD ["/start.sh"]

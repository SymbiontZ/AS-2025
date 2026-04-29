#!/bin/bash
set -x

# Create ftp group and user if they don't exist
groupadd -f ftp
id -u ftp &>/dev/null || useradd -d /data/publico -s /usr/sbin/nologin -g ftp ftp

# Create revisor user
id -u revisor &>/dev/null || useradd -M -s /usr/sbin/nologin revisor
echo "revisor:revisor" | chpasswd
(echo "revisor"; echo "revisor") | smbpasswd -s -a revisor

# Create empleado users
for i in {1..5}; do
    id -u empleado$i &>/dev/null || useradd -M -s /usr/sbin/nologin empleado$i
    echo "empleado$i:empleado$i" | chpasswd
    (echo "empleado$i"; echo "empleado$i") | smbpasswd -s -a empleado$i
done

# Create directories and set permissions
mkdir -p /data/desarrollo /data/revision /data/publico

for i in {1..5}; do
    # Desarrollo
    mkdir -p /data/desarrollo/SW$i
    chown empleado$i:empleado$i /data/desarrollo/SW$i
    chmod 700 /data/desarrollo/SW$i

    # Revision
    mkdir -p /data/revision/SW$i
    chown empleado$i:revisor /data/revision/SW$i
    chmod 770 /data/revision/SW$i
    chmod g+s /data/revision/SW$i

    # Publico
    mkdir -p /data/publico/SW$i
    chown revisor:ftp /data/publico/SW$i
    chmod 755 /data/publico/SW$i
done

# Prepare vsftpd
mkdir -p /var/run/vsftpd/empty
chown root:root /var/run/vsftpd/empty

# Start vsftpd in background
/usr/sbin/vsftpd /etc/vsftpd.conf &

# Start samba
smbd -F

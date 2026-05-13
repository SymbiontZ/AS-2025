FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Postfix, Dovecot and utilities
RUN apt-get update && apt-get install -y \
    postfix \
    dovecot-core \
    dovecot-imapd \
    mailutils \
    telnet \
    swaks \
    net-tools \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY postfix/main.cf       /etc/postfix/main.cf
COPY postfix/master.cf     /etc/postfix/master.cf
COPY dovecot/dovecot.conf  /etc/dovecot/dovecot.conf
COPY dovecot/10-auth.conf  /etc/dovecot/conf.d/10-auth.conf
COPY dovecot/10-mail.conf  /etc/dovecot/conf.d/10-mail.conf
COPY dovecot/10-master.conf /etc/dovecot/conf.d/10-master.conf
COPY dovecot/15-mailboxes.conf /etc/dovecot/conf.d/15-mailboxes.conf

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 25 143

ENTRYPOINT ["/entrypoint.sh"]

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y proftpd proftpd-mod-crypto proftpd-mod-proxy openssl && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/proftpd/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/proftpd/ssl/proftpd.key -out /etc/proftpd/ssl/proftpd.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=Empresa/OU=IT/CN=ftp.empresa.local"

RUN mkdir -p /var/proftpd/proxy && chown proftpd:nogroup /var/proftpd/proxy

COPY proftpd.conf /etc/proftpd/proftpd.conf
RUN chmod 644 /etc/proftpd/proftpd.conf

EXPOSE 2121 2122-2130

CMD ["proftpd", "--nodaemon"]

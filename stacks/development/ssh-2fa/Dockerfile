FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y openssh-server libpam-google-authenticator sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd

COPY sshd_config /etc/ssh/sshd_config
COPY pam_sshd /etc/pam.d/sshd
COPY entrypoint.sh /entrypoint.sh

# Normalize line endings in case files were edited on Windows with CRLF.
RUN sed -i 's/\r$//' /etc/ssh/sshd_config /etc/pam.d/sshd /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 2222

CMD ["/entrypoint.sh"]

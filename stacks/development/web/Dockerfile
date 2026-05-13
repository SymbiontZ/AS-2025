FROM httpd:2.4

# Install iproute2 for static route setup at container start
RUN apt-get update && apt-get install -y iproute2 && rm -rf /var/lib/apt/lists/*

# Enable necessary modules
RUN sed -i '/#LoadModule vhost_alias_module/s/^#//g' /usr/local/apache2/conf/httpd.conf
RUN sed -i '/#Include conf\/extra\/httpd-vhosts.conf/s/^#//g' /usr/local/apache2/conf/httpd.conf
RUN sed -i '/#LoadModule rewrite_module/s/^#//g' /usr/local/apache2/conf/httpd.conf

# We expose 80 by default in httpd:2.4
EXPOSE 80

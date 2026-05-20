FROM httpd:2.4

# Enable necessary modules
RUN sed -i '/#LoadModule vhost_alias_module/s/^#//g' /usr/local/apache2/conf/httpd.conf
RUN sed -i '/#Include conf\/extra\/httpd-vhosts.conf/s/^#//g' /usr/local/apache2/conf/httpd.conf
RUN sed -i '/#LoadModule rewrite_module/s/^#//g' /usr/local/apache2/conf/httpd.conf
RUN sed -i '/#LoadModule usertrack_module/s/^#//g' /usr/local/apache2/conf/httpd.conf \
	&& (grep -q '^LoadModule usertrack_module' /usr/local/apache2/conf/httpd.conf \
		|| echo 'LoadModule usertrack_module modules/mod_usertrack.so' >> /usr/local/apache2/conf/httpd.conf)

# We expose 80 by default in httpd:2.4
EXPOSE 80

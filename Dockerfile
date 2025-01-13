# For testing
# DOCKER_BUILDKIT=0 && docker buildx build --load . -t intermesh/groupoffice-mailserver:latest

FROM debian:bookworm-slim

ENV MYSQL_USER groupoffice
ENV MYSQL_PASSWORD groupoffice
ENV MYSQL_DATABASE groupoffice
ENV MYSQL_HOST db
ENV POSTMASTER_EMAIL postmaster@example.com

RUN apt-get update
RUN apt-get install -y postfix postfix-mysql dovecot-imapd dovecot-mysql dovecot-lmtpd dovecot-sieve \
 dovecot-managesieved supervisor bash rsyslog nano dovecot-fts-xapian opendkim \
    libopendbx1-mysql

#Add user for mail handling
RUN useradd -r -u 150 -g mail -d /var/mail/vhosts -m -s /sbin/nologin -c "Virtual Mailbox" vmail

# Dovecot config
COPY ./etc/dovecot/conf.d/99-groupoffice.conf /etc/dovecot/conf.d/99-groupoffice.conf.tpl
COPY ./etc/dovecot/groupoffice-sql.conf.ext /etc/dovecot/groupoffice-sql.conf.ext.tpl
COPY ./etc/dovecot/groupoffice-dict-sql.conf.ext /etc/dovecot/groupoffice-dict-sql.conf.ext.tpl
COPY ./etc/dovecot/groupoffice-domain-owner-sql.conf.ext /etc/dovecot/groupoffice-domain-owner-sql.conf.ext.tpl
COPY ./etc/dovecot/virtual/All/dovecot-virtual /etc/dovecot/virtual/All/dovecot-virtual

COPY ./usr/bin/quota-warning.sh /usr/bin/quota-warning.sh

RUN mkdir -p /var/mail/vhosts && chown vmail:mail /var/mail/vhosts
COPY ./var/mail/vhosts/default.sieve /var/mail/vhosts/default.sieve

# Opendkim
COPY ./etc/opendkim.conf.tpl /etc/opendkim.conf.tpl

#disable default system auth because it slows down the login
RUN sed -i 's/!include auth-system.conf.ext/#!include auth-system.conf.ext/' /etc/dovecot/conf.d/10-auth.conf

#IMAP Acl
RUN mkdir -p /var/lib/dovecot/db && \
  touch /var/lib/dovecot/db/shared-mailboxes.db && \
  chown -R vmail:mail /var/lib/dovecot/db

# Postfix config
RUN cp /etc/hostname /etc/mailname

COPY ./etc/postfix/submission_header_checks /etc/postfix/submission_header_checks

# SASL settings
# This will make Postfix authenticate users via Dovecot. Users mail clients will 
# connect directly to Postfix for sending mail and we need them to authenticate.

# About submission_header_checks:
# https://askubuntu.com/questions/78163/when-sending-email-with-postfix-how-can-i-hide-the-sender-s-ip-and-username-in

RUN postconf -e 'smtpd_sasl_auth_enable = no' && \
postconf -e 'smtpd_sasl_type = dovecot' && \
postconf -e 'smtpd_sasl_path = private/auth' && \
postconf -e 'smtpd_sasl_authenticated_header = no' && \
postconf -e 'smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_non_fqdn_recipient, reject_unauth_destination, reject_unauth_pipelining, reject_invalid_hostname, reject_unknown_sender_domain permit' && \
postconf -e 'smtpd_data_restrictions = reject_unauth_pipelining, reject_multi_recipient_bounce, permit' && \
postconf -e 'smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination' && \
postconf -e 'smtpd_sasl_path = private/auth' && \
postconf -e 'smtp_tls_security_level = may' && \
postconf -e 'broken_sasl_auth_clients = yes' && \
postconf -e 'virtual_minimum_uid = 150' && \
postconf -e 'virtual_uid_maps = static:150' && \
postconf -e 'virtual_gid_maps = static:8' && \
postconf -e 'virtual_mailbox_base = /var/mail/vhosts' && \
postconf -e 'virtual_alias_domains =' && \
postconf -e 'virtual_alias_maps = proxy:mysql:$config_directory/mysql_virtual_alias_maps.cf' && \
postconf -e 'virtual_mailbox_domains = proxy:mysql:$config_directory/mysql_virtual_mailbox_domains.cf' && \
postconf -e 'virtual_mailbox_maps = proxy:mysql:$config_directory/mysql_virtual_mailbox_maps.cf' && \
postconf -e 'virtual_transport = lmtp:unix:private/dovecot-lmtp' && \
postconf -e 'default_destination_concurrency_limit = 5' && \
postconf -e 'relay_destination_concurrency_limit = 1' && \
postconf -e 'message_size_limit = 20480000' && \
postconf -e 'smtpd_milters = unix:opendkim/opendkim.sock' && \
postconf -M submission/inet="submission   inet   n   -   n   -   -   smtpd" && \
postconf -P "submission/inet/syslog_name=postfix/submission" && \
postconf -P "submission/inet/smtpd_tls_security_level=encrypt" && \
postconf -P "submission/inet/smtpd_etrn_restrictions=reject" && \
postconf -P "submission/inet/smtpd_sasl_type=dovecot" && \
postconf -P "submission/inet/smtpd_sasl_path=private/auth" && \
postconf -P "submission/inet/smtpd_sasl_security_options=noanonymous" && \
postconf -P "submission/inet/smtpd_sasl_local_domain=$myhostname" && \
postconf -P "submission/inet/smtpd_sasl_auth_enable=yes" && \
postconf -P "submission/inet/milter_macro_daemon_name=ORIGINATING" && \
postconf -P "submission/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject" && \
postconf -P "submission/inet/smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject" && \
postconf -M subcleanup/unix="subcleanup   unix n    -       -       -       0       cleanup" && \
postconf -P "subcleanup/unix/header_checks=regexp:/etc/postfix/submission_header_checks" && \
postconf -P "submission/inet/smtpd_client_message_rate_limit=10" && \
postconf -P "submission/inet/anvil_rate_time_unit=60s" && \
postconf -P "submission/inet/cleanup_service_name=subcleanup"

#header checks above will hide client IP and domain from outgoing mails

# Use supervisor to run multiple services in docker
COPY ./etc/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 25
EXPOSE 143
EXPOSE 587
EXPOSE 993
EXPOSE 4190





# for accessing socket local:/run/opendkim/opendkim.sock
RUN usermod -a -G opendkim postfix

# run dir must exist
RUN mkdir /var/spool/postfix/opendkim
RUN chown opendkim:opendkim /var/spool/postfix/opendkim

VOLUME /var/mail/vhosts

#&& ln -sf /dev/stderr /var/log/mail.err

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
#CMD /bin/bash

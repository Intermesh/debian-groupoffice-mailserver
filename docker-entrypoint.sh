#!/bin/sh
set -e

cp /etc/dovecot/conf.d/99-groupoffice.conf.tpl /etc/dovecot/conf.d/99-groupoffice.conf
sed -i 's/postmaster_address = postmaster@localhost.localdomain/postmaster_address = '$POSTMASTER_EMAIL'/' /etc/dovecot/conf.d/99-groupoffice.conf
sed -i 's/{dbHost}/'$MYSQL_HOST'/' /etc/dovecot/conf.d/99-groupoffice.conf && \
sed -i 's/{dbName}/'$MYSQL_DATABASE'/' /etc/dovecot/conf.d/99-groupoffice.conf && \
sed -i 's/{dbUser}/'$MYSQL_USER'/' /etc/dovecot/conf.d/99-groupoffice.conf && \
sed -i 's/{dbPass}/'$MYSQL_PASSWORD'/' /etc/dovecot/conf.d/99-groupoffice.conf && \
sed -i 's/{authAllowClearText}/'$DOVECOT_AUTH_ALLOW_CLEAR_TEXT'/' /etc/dovecot/conf.d/99-groupoffice.conf

echo "user = ${MYSQL_USER}\n\
password = ${MYSQL_PASSWORD}\n\
hosts = ${MYSQL_HOST}\n\
dbname = ${MYSQL_DATABASE}\n\
table = community_maildomains_alias\n\
select_field = goto\n\
where_field = address\n\
additional_conditions = and active = '1'" > /etc/postfix/mysql_virtual_alias_maps.cf && \

echo "user = ${MYSQL_USER}\n\
password = ${MYSQL_PASSWORD}\n\
hosts = ${MYSQL_HOST}\n\
dbname = ${MYSQL_DATABASE}\n\
table = community_maildomains_domain\n\
select_field = domain\n\
where_field = domain\n\
additional_conditions = and backupmx = '0' and active = '1'" > /etc/postfix/mysql_virtual_mailbox_domains.cf && \

echo "user = ${MYSQL_USER}\n\
password = ${MYSQL_PASSWORD}\n\
hosts = ${MYSQL_HOST}\n\
dbname = ${MYSQL_DATABASE}\n\
table = community_maildomains_mailbox\n\
select_field = maildir\n\
where_field = username\n\
additional_conditions = and active = '1'" > /etc/postfix/mysql_virtual_mailbox_maps.cf


cp /etc/opendkim.conf.tpl /etc/opendkim.conf
sed -i 's/{dbHost}/'$MYSQL_HOST'/' /etc/opendkim.conf && \
sed -i 's/{dbName}/'$MYSQL_DATABASE'/' /etc/opendkim.conf && \
sed -i 's/{dbUser}/'$MYSQL_USER'/' /etc/opendkim.conf && \
sed -i 's/{dbPass}/'$MYSQL_PASSWORD'/' /etc/opendkim.conf


/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

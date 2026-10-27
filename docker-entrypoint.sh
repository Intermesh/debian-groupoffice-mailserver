#!/bin/sh
set -e

# Escape a value for use in the replacement of a sed s|||  command
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'
}

# Escape a value for use in a double-quoted dovecot setting and then for sed
dovecot_escape() {
  sed_escape "$(printf '%s' "$1" | sed -e 's/[\\"]/\\&/g')"
}

DOVECOT_CONF=/etc/dovecot/conf.d/99-groupoffice.conf
cp /etc/dovecot/conf.d/99-groupoffice.conf.tpl "$DOVECOT_CONF"
sed -i "s|postmaster_address = postmaster@localhost.localdomain|postmaster_address = $(sed_escape "$POSTMASTER_EMAIL")|" "$DOVECOT_CONF"
sed -i "s|{dbHost}|$(sed_escape "$MYSQL_HOST")|" "$DOVECOT_CONF"
sed -i "s|{dbName}|$(dovecot_escape "$MYSQL_DATABASE")|" "$DOVECOT_CONF"
sed -i "s|{dbUser}|$(dovecot_escape "$MYSQL_USER")|" "$DOVECOT_CONF"
sed -i "s|{dbPass}|$(dovecot_escape "$MYSQL_PASSWORD")|" "$DOVECOT_CONF"
sed -i "s|{authAllowClearText}|$(sed_escape "$DOVECOT_AUTH_ALLOW_CLEAR_TEXT")|" "$DOVECOT_CONF"

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
additional_conditions = and active = '1'" > /etc/postfix/mysql_virtual_mailbox_maps.cf && \

echo "user = ${MYSQL_USER}\n\
password = ${MYSQL_PASSWORD}\n\
hosts = ${MYSQL_HOST}\n\
dbname = ${MYSQL_DATABASE}\n\
query = SELECT username FROM community_maildomains_mailbox WHERE username = '%s' AND active = '1' UNION SELECT goto FROM community_maildomains_alias WHERE address = '%s' AND active = '1'" > /etc/postfix/mysql_sender_login_maps.cf

# The maps contain the database password
chmod 640 /etc/postfix/mysql_*.cf
chgrp postfix /etc/postfix/mysql_*.cf

MAIL_HOSTNAME=${MAIL_HOSTNAME:-$(hostname -f 2>/dev/null || hostname)}
case "$MAIL_HOSTNAME" in
  *.*) ;;
  *) echo "Warning: MAIL_HOSTNAME '$MAIL_HOSTNAME' is not a FQDN. Other mailservers may reject mail from this server." >&2 ;;
esac
postconf -e "myhostname = $MAIL_HOSTNAME"
echo "$MAIL_HOSTNAME" > /etc/mailname

# GROUPOFFICE_NETS is used by dovecot directly. Group-Office sends the mail of all users, so it's also not rate limited.
# Dovecot only accepts a comma separated list without spaces. Dovecot inherits the exported value from supervisord.
GROUPOFFICE_NETS=$(printf '%s' "$GROUPOFFICE_NETS" | tr -s ', ' '\n\n' | sed '/^$/d' | paste -sd, -)
export GROUPOFFICE_NETS
if [ -n "$GROUPOFFICE_NETS" ]; then
  # Postfix needs IPv6 addresses in brackets
  postfix_nets=$(printf '%s' "$GROUPOFFICE_NETS" | tr ',' '\n' | sed -e 's|^\([^/]*:[^/]*\)\(/.*\)\{0,1\}$|[\1]\2|' | paste -sd, -)
  postconf -e "smtpd_client_event_limit_exceptions = \$mynetworks, $postfix_nets"
else
  echo "Warning: GROUPOFFICE_NETS is not set. Mailboxes without \"SMTP allowed\" can't send mail with Group-Office." >&2
fi


cp /etc/opendkim.conf.tpl /etc/opendkim.conf
sed -i "s|{dbHost}|$(sed_escape "$MYSQL_HOST")|" /etc/opendkim.conf
sed -i "s|{dbName}|$(sed_escape "$MYSQL_DATABASE")|" /etc/opendkim.conf
sed -i "s|{dbUser}|$(sed_escape "$MYSQL_USER")|" /etc/opendkim.conf
sed -i "s|{dbPass}|$(sed_escape "$MYSQL_PASSWORD")|" /etc/opendkim.conf


# Clean up stale PID files from previous container run
rm -f /run/rsyslogd.pid
rm -f /var/run/dovecot/master.pid
rm -f /var/spool/postfix/pid/master.pid
rm -f /run/opendkim/opendkim.pid

#containers don't have access to /proc/kmsg (kernel log) by default. You don't need kernel logging in a container anyway.
sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

# make sure run dir exists
mkdir -p /var/run

# The mail-log program tails this file, which rsyslog only creates when the first line is logged
touch /var/log/mail.log

# opendkim exits when it can't connect to the database on startup. The database container may still be starting.
i=0
until bash -c "echo > /dev/tcp/$MYSQL_HOST/3306" 2>/dev/null; do
  i=$((i + 1))
  if [ $i -ge 60 ]; then
    echo "Warning: database $MYSQL_HOST:3306 is not reachable. Starting anyway." >&2
    break
  fi
  echo "Waiting for database $MYSQL_HOST:3306..."
  sleep 1
done

# Creates the missing postfix spool directories and copies the files postfix needs in its chroot, like resolv.conf.
# Supervisor runs the postfix master directly, which skips this.
postfix check

# Hand off to supervisord as PID 1 for docker
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

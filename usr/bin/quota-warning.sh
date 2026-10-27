#!/bin/sh
PERCENT=$1
USER=$2
POSTMASTER=`doveconf -h postmaster_address`;
cat << EOF | /usr/lib/dovecot/dovecot-lda -d "$USER" -o quota_enforce=no
From: $POSTMASTER
Subject: Quota warning
To: $USER

Your mailbox is now $PERCENT% full.
EOF
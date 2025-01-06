#!/bin/sh
PERCENT=$1
USER=$2
POSTMASTER=`doveconf -h postmaster_address`;
cat << EOF | /usr/lib/dovecot/dovecot-lda -d $USER -o "plugin/quota=count:User quota:noenforcing"
From: $POSTMASTER
Subject: Quota warning
To: $USER

Your mailbox is now $PERCENT% full.
EOF
# debian-groupoffice-mailserver
Mailserver that uses virtual mail managed by GroupOffice. More information can be found at https://www.GroupOffice.com.

Make sure you have the tools:

```
apt-get install devscripts build-essential
```

To build:
1. Edit debian/changelog with version and repo ("sixeight", "testing" etc.).
2. run inside directory:
   ```
   debuild --no-lintian -b
   ```
3. run:
   ```
	reprepro -b /var/www/build/groupoffice/build/deploy/reprepro/ include twentyfiveone ../groupoffice-mailserver_25.0.3_amd64.changes
   ```
   or for testing:
   ```
    reprepro -b /var/www/build/groupoffice/build/deploy/reprepro/ include testing ../groupoffice-mailserver_25.1.0_amd64.changes
   ```

Build with docker (Replace /Volumes/Projects with your output dir):

```
docker run --rm -v /Volumes/Projects:/build -w /build/debian-groupoffice-mailserver debian:trixie bash -c 'apt-get update && apt-get install -y devscripts debhelper && debuild --no-lintian -b -us -uc'
```

## Docker
The image is based on debian-slim and uses postfix, dovecot and opendkim.

We use it in our GroupOffice development stack:

https://github.com/Intermesh/docker-groupoffice-development

Run ./push.sh to build and publish or for testing locally:

```
DOCKER_BUILDKIT=0 && docker buildx build --load . -t intermesh/groupoffice-mailserver:latest
```

You can also run it with docker compose by cloning this repo and run:

```
docker compose up -d
```

Afterwards install GroupOffice and the mail domains module. Then restart the mailserver.

Environment variables:

- `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`: The GroupOffice database.
- `POSTMASTER_EMAIL`: Sender of the quota warning mails.
- `MAIL_HOSTNAME`: Public FQDN of the mailserver. Used in the SMTP greeting and HELO. Defaults to the container hostname.
- `GROUPOFFICE_NETS`: IP addresses or networks of the GroupOffice container, comma separated. Mailboxes without
  "SMTP allowed" can only send mail from these, so their users can send with GroupOffice but not with other mail
  clients. These networks are also not rate limited on the submission port (10 messages per minute), because
  GroupOffice sends the mail of all users. When not set only localhost is allowed.

### Debian package
The Debian package sets `GROUPOFFICE_NETS` for dovecot to the loopback and the addresses of the host in
`/etc/systemd/system/dovecot.service.d/groupoffice.conf`. Change it with `systemctl edit dovecot` and restart dovecot.
The networks must be separated by commas without spaces.
- `DOVECOT_AUTH_ALLOW_CLEAR_TEXT`: Set to "yes" to allow IMAP logins without TLS. For development only.


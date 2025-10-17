# debian-groupoffice-mailserver
Mailserver that uses virtual mail managed by Group-Office. More information can be found at https://www.group-office.com.

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
   

## Docker
The image is based on debian-slim and uses postfix, dovecot and opendkim.

We use it in our Group-Office development stack:

https://github.com/Intermesh/docker-groupoffice-development

Run ./push.sh to build and publish or for testing locally:

```
DOCKER_BUILDKIT=0 && docker buildx build --load . -t intermesh/groupoffice-mailserver:latest
```

You can also run it with docker compose by cloning this repo and run:

```
docker compose up -d
```

Afterwards install group-office and the mail domains module. Then restart the mailserver.


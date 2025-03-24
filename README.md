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
	reprepro -b /var/www/build/groupoffice/build/deploy/reprepro/ include twentyfivezero ../groupoffice-mailserver_25.0.3_amd64.changes
   ```
   

## Docker
The image is based on debian-slim and uses postfix, dovecot and opendkim.

We us it in our Group-Office development stack:

https://github.com/Intermesh/docker-groupoffice-development

Run ./push.sh to build and publish or for testing locally:

```
DOCKER_BUILDKIT=0 && docker buildx build --load . -t intermesh/groupoffice-mailserver:latest
```


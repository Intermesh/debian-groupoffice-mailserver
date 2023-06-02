# debian-groupoffice-mailserver
Debian package for Group-Office mailserver configuration.

Make sure you have the tools:

```
apt-get install devscripts build-essential
```

To build:
1. Edit debian/changelog with version and repo 63-php-70.
2. run inside directory:
   ```
   debuild --no-lintian -b
   ```
3. run:
   ```
	reprepro -b /var/www/build/groupoffice/build/deploy/reprepro/ include sixseven ../groupoffice-mailserver_6.7.4_amd64.changes
   ```

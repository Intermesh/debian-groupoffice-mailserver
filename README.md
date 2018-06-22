# debian-groupoffice-mailserver
Debian package for Group-Office mailserver configuration.

To build:
1. Edit debian/changelog with version and repo 63-php70.
2. run inside directory:
   ```
   debuild --no-lintian -b
   ```
3. run:
   ```
   reprepro -b /var/www/build/deploy/reprepro include 63-php-70 ../groupoffice-mailserver_6.3.1-php-71_amd64.changes
   ```
4. Repeat all steps with 63-php-71 in debian/changelog and command

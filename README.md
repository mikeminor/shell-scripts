Repository for various shell scripts. 

vhostscript.sh --

Usage: vhostscript.sh -c|-d|-e|-r (create or delete or enable or remove) -n domain.com [ -m user@email.com ] [ -u user (set file user owner) ] [ -h ]

Simple test script which adds or removes vhosts based off of a default template as seen below. Unspecified options will inherit defaults. The script will create a sites-enabled/sites-available folder structure if one does not exist and update the main httpd.conf accordingly. It will also restart gracefully restart apache.`

<VirtualHost *:80>
    $webemail
    ServerName www.${webdomain}
    ServerAlias ${webdomain}
    DocumentRoot ${webuserdir}/public_html
    <Directory ${webuserdir}/public_html>
      Options Indexes FollowSymLinks
      AllowOverride All
      Require all granted
    </Directory>

</VirtualHost>


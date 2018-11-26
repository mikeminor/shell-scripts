Repository for various shell scripts. 

vhostscript.sh --

Usage: vhostscript.sh -c|-d|-e|-r (create or delete or enable or remove) -n domain.com [ -m user@email.com ] [ -u user (set file user owner) ] [ -h ]

Simple test script which adds or removes vhosts based off of a default template. Unspecified options will inherit defaults. The script will create a sites-enabled/sites-available folder structure if one does not exist and update the main httpd.conf accordingly. It will also restart gracefully restart apache.`

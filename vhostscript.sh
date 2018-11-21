#!/bin/bash

#set -euo pipefail

#NOTES:
#Needlessly overcomplicated to test out some tools like getopts and some methodology including error handling, including possible usage of set -euo pipefail.

#Options:
# -c create
# -d disable
# -e enable
# -r remove
# -n domainblah.com domain name
#[ -b ] debugging
#[ -e email ] blah@blah.com serveradmin e-mail defaults to nothing; use httpd.conf default
#[ -u user ] defaults to base apache user
# -h help


error_handling() {
   read line file <<<$(caller)
   echo "An error occurred in line $line of file $file:" >&2
   sed "${line}q;d" "$file" >&2
   exit 2
}

trap error_handling ERR

#httpd -S > /dev/null || echo "Error reading information from httpd." && exit 2
apacheroot=$(httpd -S | grep "ServerRoot:" | cut -d\" -f2)
apacheuser=$(httpd -S | grep "User:" | cut -d\" -f2)
webroot="/var/www"
sitesavailable="${apacheroot}/sites-available"
sitesenabled="${apacheroot}/sites-enabled"
httpdconf="${apacheroot}/conf/httpd.conf"
webemail=
webusername=
webdomain=
myaction=
mydebug=

helper()
{
  if [[ -n "$1" ]] ; then
    echo "$1"
  else
    echo "Usage: vhostscript.sh -c|-d|-e|-r (create or delete or enable or remove) -n domain.com [ -m user@email.com ] [ -u user (set file user owner) ]"
  fi
  exit 2
}

apachehandler()
{
  if systemctl is-active httpd > /dev/null ; then
    echo "Restarting apache..."
    apachectl graceful
  else
    echo "Apache not running. Leaving it off."
  fi
  exit 0
}

[[ $EUID -eq 0 ]] || helper "Attempted to run $0 without privileges. Exiting."

while getopts "bcdern:m:u:?h" opt; do
  case $opt in
    b) mydebug=true ;;
    c) myaction="create" ;;
    d) myaction="disable"  ;;
    e) myaction="enable" ;; 
    r) myaction="remove" ;;
    n)
      [[ ! "$OPTARG" =~ ^[a-zA-Z0-9\.]+$ ]] && helper 
      webdomain="${OPTARG#www.*}"
      vhostconf="${sitesavailable}/${webdomain}.conf"
      webuserdir="${webroot}/${webdomain}" ;;
    m) webemail="ServerAdmin $OPTARG" ;; 
    u) webusername="$OPTARG" ;; 
    h|\?) helper ;;
    : ) helper ;;
  esac
done
shift $((OPTIND-1))

echo "dddd"

#Ensure the httpd.conf has been found properly. Possibly should run this check above the getopts?
[[ -f $httpdconf ]] || helper "Could not find httpd.conf at $httpdconf. Exiting."
[[ -z $webusername ]] && webusername=$apacheuser

# Getopts offers tools to deal with errors within arguments passed, but we must still check that the proper arguments were passed.
# Specifically we must check that the action to take (create or delete) and the domain name were passed, otherwise exit.
if [[ -z $webdomain ]] || { [[ $myaction != "create" ]] && [[ $myaction != "remove" ]] && [[ $myaction != "enable" ]] && [[ $myaction != "disable" ]]; }; then
  helper
fi

#Debugging. Not really, just showing some information about variables. Helps us free what might be wrong, if something does go wrong.
if [[ $mydebug ]]; then
  echo "MY ACTION: $myaction"
  echo "DOMAIN: $webdomain"
  echo "WEBEMAIL: $webemail"
  echo "WEBUSERNAME: $webusername"
  echo "VHOSTCONF: $vhostconf"
  echo "SITESAVAIL: $sitesavailable"
  echo "WEBUSERDIR: $webuserdir"
  echo "WEBLINE: $webemail"
  echo "APACHEUSER: $apacheuser"
  exit 0
fi

if [[ "$myaction" == "enable" ]]; then
  [[ ! -L "${sitesenabled}/${webdomain}.conf" ]] || helper "Vhost already enabled in sites-enabled at ${sitesenabled}/${webdomain}.conf. Exiting."
  [[ -f $vhostconf ]] || helper "Cannot enable ${webdomain}. $vhostconf does not exist."
  ln -s $vhostconf "${sitesenabled}/${webdomain}.conf"
  echo "Symlink created successfully. $webdomain enabled."
  apachehandler
elif [[ "$myaction" == "disable" ]]; then
  [[ -L "${sitesenabled}/${webdomain}.conf" ]] || helper "Vhost not enabled in sites-enabled at ${sitesenabled}/${webdomain}.conf. Exiting."
  rm -f "${sitesenabled}/${webdomain}.conf"
  apachehandler
fi

if [[ "$myaction" == "remove" ]]; then
  echo "Beginning removal..."
  [[ -f $vhostconf ]] || helper "Could not delete vhost ${webdomain}: could not find $vhostconf."
  rm -f $vhostconf
  rm -Rf $webuserdir
  rm -f "${sitesenabled}/${webdomain}.conf"
  apachehandler
fi

#####Begin "create"
#Any other options have been exited out by now.

#First we check if sites-available is setup. Vhost conf can be stored many ways but we'll use this. Could be built out to support multiple methods.
#We could use mkdir -p or test the directory then create it, mkdir -p possibly problematic in a scenario where this directory could end up mounted/unmounted?
#mkdir -p /etc/httpd/sites-available
if [[ ! -d $sitesavailable ]]; then
  echo "Sites-available folder does not exist. Creating."
  mkdir $sitesavailable
  restorecon -R $sitesavailable
fi
if [[ ! -d $sitesenabled ]]; then
  echo "Sites-enabled folder does not exist. Creating."
  mkdir $sitesenabled
  restorecon -R $sitesenabled
fi


#This is really just a first time run but realistically we're double checking every time we create a new vhost.
#Check our httpd conf for IncludeOptional sites-enabled/*.conf. Add if it doesn't exist.
#if [[ -z $(cat $httpdconf | grep "IncludeOptional sites-enabled/\*.conf") ]]
if [ $( ! grep -q "IncludeOptional sites-enabled/\*.conf" $httpdconf ) ]
then
  echo "IncludeOptional sites-enabled/*.conf" >> $httpdconf
  echo "Added sites-enabled IncludeOptional to httpd.conf successfully"
else
  echo "sites-enabled IncludeOptional already exists. Good."
fi


#More directories. Create the dir but don't exit if it doesn't exist. Script will exit if folder can't be created.
#Just using mkdir would exit due to errorhandling
[[ ! -d $webuserdir ]] && mkdir ${webuserdir}
[[ ! -d "${webuserdir}/public_html" ]] && mkdir "${webuserdir}/public_html"


#Create the vhost in /etc/httpd/sites-available/
#VirtualHosts will inherit defaults from the httpd.conf. We can add more to this later if we'd like.
#We could run other checks here, such as iterating through the other configs for this domain.
if [[ -f $vhostconf ]]; then
  echo "Virtual host already exists. Please look into this or run the script again with -d to delete existing configuration."
fi

[[ ! -f $vhostconf ]] && echo "<VirtualHost *:80>
    $webemail
    ServerName www.${webdomain}
    ServerAlias ${webdomain}
    DocumentRoot ${webuserdir}/public_html
    <Directory ${webuserdir}/public_html>
      Options Indexes FollowSymLinks
      AllowOverride All
      Require all granted
    </Directory>  
    ErrorLog $webuserdir/error_log
    CustomLog $webuserdir/access_log combined

</VirtualHost>
" > $vhostconf

#Ensure ownership and SELinux contexts are proper.
chown -R ${webusername}:apache ${webuserdir}
chmod -R 755 ${webuserdir}/public_html
restorecon $vhostconf
restorecon -R $webuserdir
echo "SElinux contexts set properly"

[[ ! -L "${sitesenabled}/${webdomain}.conf" ]] && ln -s $vhostconf "${sitesenabled}/${webdomain}.conf"
echo "Symlink created successfully"

apachehandler

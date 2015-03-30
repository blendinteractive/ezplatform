#!/usr/bin/env bash

# Install software
apt-get update
export DEBIAN_FRONTEND=noninteractive

apt-get install -q -y apache2 curl php5 mysql-server-5.5 php5-mysql php5-gd php5-xsl php5-intl php5-curl php-apc imagemagick pwgen
PROJECT_NAME="ezplatform"
SITE_PATH="/Sites/$PROJECT_NAME"
SITE_HTDOCS="$SITE_PATH"
DB_PASS=`pwgen 14`
if [ ! -d "$SITE_PATH" ] ;then
    mkdir -p "$SITE_PATH"
fi

# Configure apache to read our config
# echo "NameVirtualHost *:80" > /etc/apache2/conf-available/ezplatform.conf
echo "ServerName $PROJECT_NAME.local" > /etc/apache2/conf-available/$PROJECT_NAME.conf
echo "Include $SITE_PATH/conf/local.conf" >> /etc/apache2/conf-available/$PROJECT_NAME.conf
a2enconf ezplatform

# Switch apache process to the vagrant user
chown vagrant /var/lock/apache2/
sed -s s/www-data/vagrant/g /etc/apache2/envvars > /etc/apache2/envvars.tmp
rm /etc/apache2/envvars
mv /etc/apache2/envvars.tmp /etc/apache2/envvars

# Enable rewrite and restart apache
a2enmod rewrite status
service apache2 restart

# Set up the eZ Publish app
TABLES=$(mysql -uroot -e "show tables from `$PROJECT_NAME`;")
if [[ $TABLES -eq '' ]]; then
    echo "Creating Database"
    # zcat /Sites/ezplatform/sql/initial.sql.gz | mysql -u root 

    echo "CREATE DATABASE $PROJECT_NAME CHARSET UTF8;"
    echo "CREATE DATABASE $PROJECT_NAME CHARSET UTF8;" | mysql -u root
    echo "GRANT ALL ON $PROJECT_NAME.* to $PROJECT_NAME@localhost IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;"
    echo "GRANT ALL ON $PROJECT_NAME.* to $PROJECT_NAME@localhost IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;" | mysql -u root
else
    echo "Tables already exist, skip db create..."
fi

EZ_CLEAR_CACHE=0
## Symlink to local config files
# cd "$SITE_HTDOCS/settings/override"
# if [[ ! -L site.ini.append.php ]]; then
#     echo "Symlink site.ini"
#     rm site.ini.append.php
#     ln -s site.ini.append.local.php site.ini.append.php
#     EZ_CLEAR_CACHE=1
# fi
# if [[ ! -L file.ini.append.php ]]; then
#     echo "Symlink file.ini"
#     rm file.ini.append.php
#     ln -s file.ini.append.local.php file.ini.append.php
#     EZ_CLEAR_CACHE=1
# fi

cd "$SITE_HTDOCS" 
# if [ -d "$SITE_HTDOCS/autoload" ] && [ -e "$SITE_HTDOCS/autoload/ezp_kernel.php" ]; then
#     echo "Autoloads already regenerated"
# else
#     echo "regenerating initial autoloads"
#     sudo -u vagrant php bin/php/ezpgenerateautoloads.php -k
#     sudo -u vagrant php bin/php/ezpgenerateautoloads.php -e
# fi

# if [ "$EZ_CLEAR_CACHE" -eq 1 ]; then
#    cd "$SITE_HTDOCS"
#    sudo -u vagrant php bin/php/ezcache.php --clear-all --purge
# fi

if [ -e /usr/local/bin/composer ]; then
    echo "Composer already installed"
else
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
fi

sudo -u vagrant composer install

sed -e "s/database_password:/database_password: $DB_PASS/;s/database_user: root/database_user: ezplatform/" ezpublish/config/parameters.yml.dist > ezpublish/config/parameters.yml

echo "Provisioning Complete - Add the following setting to your host machine's /etc/hosts file:"
echo "192.168.33.10 admin.ezplatform.local ezplatform.local www.ezplatform.local touchscreen.ezplatform.local preview.ezplatform.local"
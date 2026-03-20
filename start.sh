#!/bin/bash

echo $MAIL_HOST_NAME > /etc/mailname

### rsyslog
cp /app/templates/logs/10-mail-rsyslog.conf /etc/rsyslog.d
cp /app/templates/logs/external-logrotate /etc/logrotate.d
## /rsyslog

### quota warning
cp /app/templates/quota-warning.sh /usr/local/bin
chmod 770 /usr/local/bin/quota-warning.sh
chown vmail:dovecot /usr/local/bin/quota-warning.sh
## /quota warning

### dovecot
cp -r /app/templates/dovecot/* /etc/dovecot

DOVECOT_SSL="ssl_cert = <\/etc\/letsencrypt\/live\/$MAIN_DOMAIN\/fullchain.pem\r\n\
ssl_key = <\/etc\/letsencrypt\/live\/$MAIN_DOMAIN\/privkey.pem\r\n\r\n"

for DOMAIN in $DOMAINS
do
    DOVECOT_SSL+="local_name $DOMAIN {\r\n\
    ssl_cert = <\/etc\/letsencrypt\/live\/$DOMAIN\/fullchain.pem\r\n\
    ssl_key = <\/etc\/letsencrypt\/live\/$DOMAIN\/privkey.pem\r\n\
}\r\n\r\n"
done

sed -i "s/%%DOMAINS%%/$DOVECOT_SSL/g" /etc/dovecot/conf.d/10-ssl.conf
find /etc/dovecot -type f -exec sed -i "s/%%MAIN_DOMAIN%%/$MAIN_DOMAIN/g" {} \+
find /etc/dovecot -type f -exec sed -i "s/%%MYSQL_USER%%/$MYSQL_USER/g" {} \+
find /etc/dovecot -type f -exec sed -i "s/%%MYSQL_PASSWORD%%/$MYSQL_PASSWORD/g" {} \+
find /etc/dovecot -type f -exec sed -i "s/%%MYSQL_DB%%/$MYSQL_DB/g" {} \+
find /etc/dovecot -type f -exec sed -i "s/%%MYSQL_SERVER%%/$MYSQL_SERVER/g" {} \+

if [[ -e /run/dovecot/master.pid ]]; then
    rm /run/dovecot/master.pid
fi

chown vmail:dovecot -R /etc/dovecot
chmod -R o-rwx /etc/dovecot
### / dovecot

### postfix
cp -r /app/templates/postfix/* /etc/postfix
find /etc/postfix -type f -exec sed -i "s/%%MAIL_HOST_NAME%%/$MAIL_HOST_NAME/g" {} \+
find /etc/postfix -type f -exec sed -i "s/%%MAIN_DOMAIN%%/$MAIN_DOMAIN/g" {} \+
find /etc/postfix -type f -exec sed -i "s/%%MYSQL_USER%%/$MYSQL_USER/g" {} \+
find /etc/postfix -type f -exec sed -i "s/%%MYSQL_PASSWORD%%/$MYSQL_PASSWORD/g" {} \+
find /etc/postfix -type f -exec sed -i "s/%%MYSQL_DB%%/$MYSQL_DB/g" {} \+
find /etc/postfix -type f -exec sed -i "s/%%MYSQL_SERVER%%/$MYSQL_SERVER/g" {} \+

POSTFIX_SSL=""
for DOMAIN in $DOMAINS
do
     POSTFIX_SSL+="$DOMAIN \/etc\/letsencrypt\/live\/$DOMAIN\/privkey.pem \/etc\/letsencrypt\/live\/$DOMAIN\/fullchain.pem\r\n"
done

sed -i "s/%%DOMAINS%%/$POSTFIX_SSL/g" /etc/postfix/vmail_ssl.map

postmap -F hash:/etc/postfix/vmail_ssl.map
postmap hash:/etc/postfix/access

chmod -R o-rwx /etc/postfix

cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf
### / postfix

### opendkim
cp -r /app/templates/opendkim/* /etc/opendkim
mkdir /etc/opendkim/keys
chmod 700 /etc/opendkim/keys
cp /etc/opendkim/mounted_keys/*.private /etc/opendkim/keys
chmod 700 /etc/opendkim/keys/*

for DOMAIN in $DOMAINS
do
	echo "mail._domainkey.$DOMAIN $DOMAIN:mail:/etc/opendkim/keys/$DOMAIN.private" >> /etc/opendkim/KeyTable
	echo "*@$DOMAIN mail._domainkey.$DOMAIN" >> /etc/opendkim/SigningTable
	echo "*.$DOMAIN" >> /etc/opendkim/TrustedHosts
	echo "$DOMAIN" >> /etc/opendkim/TrustedHosts
done

chmod 700 /etc/opendkim
chown -R opendkim:opendkim /etc/opendkim

mv /etc/opendkim/opendkim.conf /etc

if [[ -e /run/opendkim/opendkim.pid ]]; then
  rm /run/opendkim/opendkim.pid
fi
### /opendkim

### cron
cp /etc/crontab /root
env|grep ^MYSQL_ > /etc/crontab
env|grep ^MAILDIR >> /etc/crontab
echo -e "\n\n$CRONTAB" >> /etc/crontab
cp /app/templates/remover.py /usr/local/bin
### /cron

/usr/sbin/rsyslogd
service cron start
service opendkim start
service dovecot start
postfix start-fg

#!/bin/bash

git clone https://github.com/ad5oo2/postfix-dovecot-ms /root

echo $MAIL_HOST_NAME > /etc/mailname

### syslog
echo "SYSLOGNG_OPTS=\"--no-caps\"" >> /etc/default/syslog-ng
if [[ -e /var/run/syslog-ng.pid ]]; then
    rm /var/run/syslog-ng.pid
fi
sed -i -E "s/^@version:\s.+$/@version: 3.35/g" /etc/syslog-ng/syslog-ng.conf
sed -i "s/\/var\/log\/mail/\/var\/log\/external\/mail/g" /etc/syslog-ng/syslog-ng.conf
sed -i -E "s/(mail\..+\")/\1 perm\(0644\)/g" /etc/syslog-ng/syslog-ng.conf
## /syslog

### quota warning
cp /root/templates/quota-warning.sh /usr/local/bin
chmod 770 /usr/local/bin/quota-warning.sh
chown vmail:dovecot /usr/local/bin/quota-warning.sh
## /quota warning

### dovecot
cp -r /root/templates/dovecot/* /etc/dovecot

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
cp -r /root/templates/postfix/* /etc/postfix
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
### / postfix

### opendkim
for DOMAIN in $DOMAINS
do
	echo "mail._domainkey.$DOMAIN $DOMAIN:mail:/etc/opendkim/keys/$DOMAIN.private" >> /etc/opendkim/KeyTable
	echo "*@$DOMAIN mail._domainkey.$DOMAIN" >> /etc/opendkim/SigningTable
	echo "*.$DOMAIN" >> /etc/opendkim/TrustedHosts
	echo "$DOMAIN" >> /etc/opendkim/TrustedHosts
done

chown opendkim:opendkim -R /etc/opendkim
chmod 700 /etc/opendkim
mv /etc/opendkim/opendkim.conf /etc
find /etc/opendkim/keys -type f -name "*private*" -exec chmod 400 {} \+

if [[ -e /run/opendkim/opendkim.pid ]]; then
  rm /run/opendkim/opendkim.pid
fi
### /opendkim

### fail2ban
rm /var/run/fail2ban/*
cp -r /root/templates/fail2ban/* /etc/fail2ban
### /fail2ban

### cron
rm /etc/cron.d/*
rm /etc/cron.daily/*
env > /etc/crontab
cat /root/configmap_cron >> /etc/crontab
cp /root/templates/remover.py /usr/local/bin
### /cron

service cron start
service syslog-ng start
service fail2ban start
chmod 644 /var/log/external/fail2ban.log
service opendkim start
service dovecot start
cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf
postfix start-fg

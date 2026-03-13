#!/bin/sh
PERCENT=$1
USER=$2
DOMAIN=`echo $USER|sed -E 's/(.*\@)(.*)/\2/g'`

cat << EOF | /usr/lib/dovecot/dovecot-lda -d $USER -o "plugin/quota=maildir:User quota:noenforcing"
From: postmaster <postmaster@$DOMAIN>
Subject: Предупреждение: ящик заполнен на $PERCENT%
Content-Transfer-Encoding: 8bit
Content-Type: text/html; charset=utf-8

<pre>
Удалите старые и ненужные сообщения, почистите спам и корзину.
В противном случае скоро вы лишитесь возможности отправлять и получать новые сообщения.

Внимание, я - робот почтового домена $DOMAIN и не умею читать, поэтому и писать мне не стоит.
</pre>

EOF

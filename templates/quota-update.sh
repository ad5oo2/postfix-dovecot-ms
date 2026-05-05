#!/bin/bash

for DOMAIN in $DKIM_DOMAINS
do
  BASE="$MAILDIR_BASE/$DOMAIN/"
  for dir in $BASE*/; do
    EMAIL=`basename "$dir"`@$DOMAIN
    echo "Recalc for $EMAIL in $dir"
    doveadm quota recalc -u $EMAIL
  done
done

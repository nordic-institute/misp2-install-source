#!/bin/bash
# Turvaserveriga HTTPS sidepidamise serdi loomine

cname="./sslproxy"; export cname
IPID=$$; export IPID
cp /dev/null /tmp/index.$IPID.txt
COMMONNAME=proxy; export COMMONNAME
openssl req -new -x509 -days 3000 -config misp2.cnf -nodes -out $cname.cert -keyout $cname.key -batch
rm /tmp/index.$IPID.txt

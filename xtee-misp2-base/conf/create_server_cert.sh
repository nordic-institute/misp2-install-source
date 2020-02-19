#!/bin/bash
apache2=/etc/apache2
cname="$apache2/ssl/httpsd"; export cname
#cd $apache2/ssl
IPID=$$; export IPID
cp /dev/null /tmp/index.$IPID.txt

if [ "x$hostname" = "x" ]
then
    COMMONNAME=`hostname -f`; export COMMONNAME
else
    COMMONNAME=$hostname; export COMMONNAME
fi
openssl req -new -x509 -days 3000 -config misp2.cnf -nodes -out $cname.cert -keyout $cname.key -batch
rm /tmp/index.$IPID.txt

# create DH params and append DH parmas to cerificate(https://weakdh.org/sysadmin.html)
openssl dhparam -out dhparams.pem 2048
cat $cname.cert dhparams.pem > new.cert
mv new.cert $cname.cert
# Limit private key access rights to -r--------
chmod 400 $cname.key



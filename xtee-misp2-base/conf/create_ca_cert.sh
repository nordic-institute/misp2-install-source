#!/bin/bash
# MISPi CA serdi loomine
apache2=/etc/apache2

cd $apache2/ssl
IPID=$$; export IPID
cp /dev/null /tmp/index.$IPID.txt
COMMONNAME=CA; export COMMONNAME
openssl req -new -x509 -days 3000 -config misp2.cnf -nodes -out MISP2_CA_cert.pem -keyout MISP2_CA_key.pem -batch
openssl rsa -in MISP2_CA_key.pem -inform PEM -out MISP2_CA_key.der -outform DER
openssl ca -gencrl -out ca.crl -config misp2.cnf -crldays 3000
rm /tmp/index.$IPID.txt


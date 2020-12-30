#!/bin/bash
# MISP2 test CA & browser client certificate for testing of Cert authentication 
set -e 
#set -x
cert_config=client_auth.cnf
CA_PATH=./client_auth_test_CA_cert
CA=${CA_PATH}/client_auth_test_CA
CA_cert=${CA}_cert
CA_key=${CA}_key
CA_crl=${CA}.crl


CLIENT_ID_PREFIX=client_auth_cert
CLIENT_ID_PATH=./client_auth_test_client_cert
CLIENT_ID=$CLIENT_ID_PATH/$CLIENT_ID_PREFIX


[ -d ${CA_PATH}/ ] || mkdir  ${CA_PATH}/


IPID=$$; export IPID
cp /dev/null /tmp/index.$IPID.txt

openssl genrsa -aes256 -passout pass:secret -out ${CA_key}.pass.pem 4096
openssl rsa -passin pass:secret -in ${CA_key}.pass.pem -out ${CA_key}.pem
rm ${CA_key}.pass.pem 
openssl req -new -x509 -days 3650 -config $cert_config -key ${CA_key}.pem -out ${CA_cert}.pem


openssl ca -gencrl -cert ${CA_cert}.pem -keyfile ${CA_key}.pem -crldays 3000 \
        -out ${CA_crl} \
        -config $cert_config 

echo ""
echo "Now you have temp CA certificate files at: $CA_PATH"
echo "copy them to MISP2 server host, at path /etc/apache2/ssl/ and rehash the apache certificates entering as root:"
echo "/etc/apache2/ssl# c_rehash ./"
echo " and restart apache:"
echo "/etc/apache2/ssl# systemctl restart apache2"
echo ""


#Client key creation

[ -d ${CLIENT_ID_PATH}/ ] || mkdir  ${CLIENT_ID_PATH}/

openssl genrsa -aes256 -passout pass:secret -out ${CLIENT_ID}.pass.key 4096
openssl rsa -passin pass:secret \
        -in ${CLIENT_ID}.pass.key \
        -out ${CLIENT_ID}.key
rm ${CLIENT_ID}.pass.key

openssl req -new -key ${CLIENT_ID}.key \
        -config $cert_config \
        -reqexts auth_ext \
        -out ${CLIENT_ID}.csr

openssl x509 -req -days 3650 \
	-CAcreateserial \
        -in ${CLIENT_ID}.csr \
        -CA ${CA_cert}.pem \
        -CAkey ${CA_key}.pem \
        -out ${CLIENT_ID}.pem

cat ${CLIENT_ID}.pem \
    ${CA_key}.pem > \
    ${CLIENT_ID}.full.pem

openssl pkcs12 -export -password pass:secret \
        -out ${CLIENT_ID}.full.pfx \
        -inkey ${CLIENT_ID}.key \
        -in ${CLIENT_ID}.pem \
        -certfile ${CA_cert}.pem

rm /tmp/index.$IPID.txt
echo "Install Test authentication cert for browser from:${CLIENT_ID}.full.pfx"
echo "the import password is: secret"




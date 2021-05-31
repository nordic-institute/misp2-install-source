#!/bin/bash
# MISPi CA serdi loomine
#    create_ca_cert.sh  -- Create MISP2 CA certificate for self-certification
set -e
misp2_apache_path="$1"
cd "$misp2_apache_path"
[[ -f "$misp2_apache_path/misp2.cnf" ]] || {
    echo "Missing $misp2_apache_path/misp2.cnf"
    exit 1
}

CA_DIR="${misp2_apache_path}"
export CA_DIR
COMMONNAME=CA
export COMMONNAME

TMPINDEX=$(mktemp --tmpdir index.XXXXXX.txt)
export TMPINDEX

openssl req -new -x509 -days 3000 -config misp2.cnf -nodes -out MISP2_CA_cert.pem -keyout MISP2_CA_key.pem -batch

openssl rsa -in MISP2_CA_key.pem -inform PEM -out MISP2_CA_key.der -outform DER

openssl ca -gencrl -out ca.crl -config misp2.cnf -crldays 3000
rm "$TMPINDEX"

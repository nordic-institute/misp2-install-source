#!/bin/bash
# Create an HTTPS certificate for communication with with a security server

# Environment variables for misp2.cnf
CA_DIR="/etc/apache2/ssl"
export CA_DIR
IPID=$$
export IPID
TMPINDEX=$(mktemp --tmpdir index_sslproxy.XXXXXX.txt)
export TMPINDEX
COMMONNAME=proxy
export COMMONNAME

# local  variables
cname="./sslproxy"
yellow=$(tput setaf 3)
no_color=$(tput sgr 0)

echo -n "${yellow}"
openssl req -new -x509 -days 3000 -config misp2.cnf -nodes -out $cname.cert -keyout $cname.key -batch
echo -n "${no_color}"
rm "${TMPINDEX}"

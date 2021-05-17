#!/bin/bash
set -e
misp2_apache_path="$1"
cname="$misp2_apache_path/httpsd"
certfile="$cname.cert"
keyfile="$cname.key"
config_file="$misp2_apache_path/misp2.cnf"

cd "$misp2_apache_path"
[[ -f "$config_file" ]] || {
    echo "Missing $config_file"
    exit 1
}

# exports for config file
CA_DIR="${misp2_apache_path}"
export CA_DIR

COMMONNAME=$(hostname -f)
export COMMONNAME

TMPINDEX=$(mktemp --tmpdir index_server.XXXXXX.txt)
export TMPINDEX

openssl req -new -x509 -days 3000 -config "$config_file" -nodes -out "${certfile}" -keyout "$keyfile" -batch
rm "${TMPINDEX}"

# create DH params and append DH parmas to cerificate(https://weakdh.org/sysadmin.html)
openssl dhparam -out dhparams.pem 2048
cert_temp=$(mktemp cname.XXXXXX.cert)
cat "${certfile}" dhparams.pem > "$cert_temp"
mv "$cert_temp" "${certfile}"
# Limit private key access rights to -r--------
chmod 400 "${keyfile}"

#!/bin/bash
#
# MISP2 application Apache Tomcat and Apache2 configuration
#
# Copyright (c) 2020- Nordic Institute for Interoperability Solutions (NIIS)
# Aktors (c) 2016

set -e

# Source debconf library.
# shellcheck source=/usr/share/debconf/confmodule
. /usr/share/debconf/confmodule
if [ -n "$DEBIAN_SCRIPT_DEBUG" ]; then
    set -v -x
    DEBIAN_SCRIPT_TRACE=1
fi

${DEBIAN_SCRIPT_TRACE:+ echo "#42#DEBUG# RUNNING $0 $*" 1>&2 }

#
# installation locations
#

xrd_prefix=/usr/xtee
tomcat_home=/var/lib/tomcat8
tomcat_defaults=/etc/default/tomcat8
apache2_home=/etc/apache2
mod_jk_home=/etc/libapache2-mod-jk

#
# installation choices (candidates for debconf handling)
#
sk_certs=y
# 'y' to skip estonian portal related prompt questions, 'n' to include them; value could be replaced before package generation
skip_estonian=n
# for CI build we reconfigure ssl.conf anyhow
apache2_overwrite_confirmation=y
# CI detection
ci_setup=n
if [ -a /tmp/ci_installation ]; then
    echo "CI setup noticed" >> /dev/stderr
    ci_setup=y
fi
# apache config already installed ?
apache_ssl_config_exists=n
if [ -f $apache2_home/sites-available/ssl.conf ]; then
    apache_ssl_config_exists=y
else
    # for no MISP2 apache config exists yet, it means we don't need to overwrite it.
    apache2_overwrite_confirmation=n
fi

#
#  functions used by post-install
#

function ci_fails() {
    if [ "$ci_setup" == "y" ]; then
        echo "CI setup fails ... $1"
        exit 1
    fi
}

function ensure_apache2_is_running() {
    while ! /usr/sbin/invoke-rc.d apache2 status > /dev/null 2>&1; do
        /usr/sbin/invoke-rc.d apache2 start > /dev/null
        sleep 1
    done
}

function etc_default_tomcat_java_variables_for_misp2() {
    local tomcat_defaults_file=$1
    #shellcheck disable=SC2016
    grep -q -e 'MaxPermSize' "${tomcat_defaults_file}" || echo 'JAVA_OPTS="${JAVA_OPTS} -Xms1g -Xmx1g -XX:MaxPermSize=256m"' >> "${tomcat_defaults_file}"
    #shellcheck disable=SC2016
    grep -q -e 'Xms1g' "${tomcat_defaults_file}" || echo 'JAVA_OPTS="${JAVA_OPTS} -Xms1g"' >> "${tomcat_defaults_file}"
    #shellcheck disable=SC2016
    grep -q -e 'Xms1g' "${tomcat_defaults_file}" || echo 'JAVA_OPTS="${JAVA_OPTS} -Xmx1g"' >> "${tomcat_defaults_file}"

    # replace JAVA_HOME variable in tomcat8 configuration with environment variable if that exists
    if [ -d "$JAVA_HOME" ] && grep -q '#JAVA_HOME' "${tomcat_defaults_file}"; then
        # regex replace
        #  - separator is ':'
        #  - only replace when JAVA_HOME is commented out like initially (#JAVA_HOME)
        #  - take replacement value from JAVA_HOME env variable and remove comment-out prefix #
        #  - g: replace all instances

        #shellcheck disable=SC2086
        sed -ie 's:#JAVA_HOME=.*:JAVA_HOME="'$JAVA_HOME'":g' "${tomcat_defaults_file}"
    fi
}

function transfer_admin_access_ip_to_apache_setup_template() {
    local ssl_tmp
    ssl_tmp=$(mktemp --tmpdir ssl.allow.XXXXX)
    sed -n '/\/\*\/admin/, /\/Location/p' $apache2_home/sites-available/ssl.conf | grep Allow > "${ssl_tmp}"
    sed -i "/\/\*\/admin/, /\/Location/ { /Allow./{ \
                                                    s/.//g
                                                    r ${ssl_tmp}
                                                   } }" $xrd_prefix/apache2/ssl.conf
    rm "$ssl_tmp"
}

function configure_ajp_local_access_mod_jk_properties() {
    local workers_conf
    workers_conf="$1"
    regex_apache_ajp_host_localhost='(\s*worker[.]ajp13_worker[.]host\s*)=\s*localhost'
    if grep -Eq "$regex_apache_ajp_host_localhost" "$workers_conf"; then
        perl -pi -e 's|'"$regex_apache_ajp_host_localhost"'|$1=127.0.0.1|g' "$workers_conf"
        # echo "Configured Apache server AJP connection host to 127.0.0.1 in '$workers_conf'."
    fi

}

function configure_ajp_local_access_tomcat_server_xml() {
    local tomcat_server_xml
    tomcat_server_xml="$1"
    regex_ajp_connector='(\s*<Connector)(\s+.*protocol\s*=\s*"AJP/1.3".*)'
    str_ajp_connector="$(grep -E "$regex_ajp_connector" "$tomcat_server_xml")"
    if [ "$str_ajp_connector" != "" ]; then
        if ! (echo "$str_ajp_connector" | grep -Eq 'address\s*=\s*'); then
            perl -pi -e 's|'"$regex_ajp_connector"'|$1 address="127.0.0.1"$2|g' "$tomcat_server_xml"
            /usr/sbin/invoke-rc.d tomcat8 restart
        else
            # Message is not shown (directed to sink),
            # but may serve a purpose while debugging with bash -x
            echo "AJP address already configured." >> /dev/null
        fi
    else
        echo "WARNING: AJP connector not found from '$tomcat_server_xml'. Cannot configure local AJP access." >> /dev/stderr
    fi
}

function arrange_apache_setup_utils_from_to() {
    local xrd_prefix_path apache2_misp2_path
    xrd_prefix_path="$1"
    apache2_misp2_path="$2"
    if [ ! -d "$apache2_misp2_path" ]; then
        mkdir "$apache2_misp2_path"
    fi

    cp "$xrd_prefix_path/apache2/updatecrl.sh" "$apache2_misp2_path"
    cp "$xrd_prefix_path/apache2/create_ca_cert.sh" "$apache2_misp2_path"
    cp "$xrd_prefix_path/apache2/create_server_cert.sh" "$apache2_misp2_path"
    cp "$xrd_prefix_path/apache2/misp2.cnf" "$apache2_misp2_path"
    cp "$xrd_prefix_path/apache2/create_sslproxy_cert.sh" "$apache2_misp2_path"

    chmod 755 "$xrd_prefix_path/apache2/cleanXFormsDir.sh"
    pushd "$apache2_misp2_path" > /dev/null
    chmod 755 create_*_cert.sh
    popd > /dev/null
}

#
#   post-install begins
#
ensure_apache2_is_running

if [ -f ${tomcat_defaults} ]; then
    etc_default_tomcat_java_variables_for_misp2 ${tomcat_defaults}
fi

#replace server.xml
cp $xrd_prefix/apache2/server.xml $tomcat_home/conf/
#remove tomcat ROOT app in case it is not webapp itself
if [ ! -f $tomcat_home/webapps/ROOT/WEB-INF/classes/config.cfg ]; then
    rm -rf $tomcat_home/webapps/ROOT
fi
### add mod-jk.conf
cp $xrd_prefix/apache2/jk.conf $apache2_home/mods-available/
### enable mods (if not enabled yet)
a2enmod jk rewrite ssl headers proxy_http

if [ "${apache2_overwrite_confirmation}" == "y" ]; then
    transfer_admin_access_ip_to_apache_setup_template
fi

cp $xrd_prefix/apache2/ssl.conf $apache2_home/sites-available/ssl.conf

if [ "${apache_ssl_config_exists}" != "y" ]; then
    a2ensite ssl.conf
    a2dissite 000-default
fi

## AJP local access
# Only enable AJP protocol access from localhost to mitigate GhostCat vulnerability
configure_ajp_local_access_mod_jk_properties "${mod_jk_home}/workers.properties"
configure_ajp_local_access_tomcat_server_xml "$tomcat_home/conf/server.xml"

#certs
#echo "Updating certificate scripts... "

arrange_apache_setup_utils_from_to $xrd_prefix $apache2_home/ssl

cd $apache2_home/ssl

if [[ ! -f $apache2_home/ssl/ca.crl || ! -f $apache2_home/ssl/MISP2_CA_key.der ]]; then
    #echo "Creating CA certificate... "
    ./create_ca_cert.sh
fi

if [[ ! -f $apache2_home/ssl/httpsd.cert || ! -f $apache2_home/ssl/httpsd.key ]]; then
    #echo "Creating server certificate... "
    ./create_server_cert.sh
fi

key_access_rights="$(ls -l $apache2_home/ssl/httpsd.key | cut -c 1-10)"
if [[ "$key_access_rights" == "-rw-r--r--" ]]; then # compare to default access rights
    #echo "Changing server private key access rights to -r-------- (previously $key_access_rights)."
    chmod 400 $apache2_home/ssl/httpsd.key
fi

# Only prompt when estonian portal related questions are not skipped
# TODO:  db-conf support missing until MISPDEV-19
# db_get xtee-misp2-base/sk_certificate_update_confirm
# sk_certs="${RET}"

[ $ci_setup == "y" ] && sk_certs=n && echo "No Cert download in CI build " >> /dev/stderr
if [ "$skip_estonian" != "y" ] && echo $sk_certs | grep -iq y; then

    function download_pem() {
        local pem_path="$1"
        local pem_url="$2"

        wget -O "$pem_path" "$pem_url"

        local wget_result="$?"
        if [ "$wget_result" != "0" ]; then
            echo "ERROR: Downloading PEM file '$pem_path' from '$pem_url' failed (code: $wget_result)." >> /dev/stderr
            exit 1
        elif ! (head -n 1 "$pem_path" | grep -q "BEGIN CERTIFICATE"); then
            echo "ERROR: PEM file '$pem_path' downloaded from '$pem_url' is not in correct format." >> /dev/stderr
            exit 2
        fi
        return 0
    }

    function setup_client_auth_root_certificates() {
        echo "Updating client root certificates... "
        client_root_ca_path=$apache2_home/ssl/client_ca
        if [ ! -d $client_root_ca_path ]; then
            mkdir $client_root_ca_path
        fi
        for cert in "$@"; do
            downloaded_cert=${cert}_crt.pem
            auth_trusted_cert=${cert}_client_auth_trusted_crt.pem
            cp -v "${downloaded_cert}" $client_root_ca_path
            openssl x509 -addtrust clientAuth -trustout -in "${downloaded_cert}" \
                -out "${auth_trusted_cert}"
            rm -v "${downloaded_cert}"
        done
        c_rehash $client_root_ca_path/
    }

    function remove_client_auth_trust() {
        for root_cert in "$@"; do
            openssl x509 -addreject clientAuth -trustout -in "${root_cert}"_crt.pem \
                -out "${root_cert}"_CA_trusted_crt.pem
            rm "${root_cert}"_crt.pem
        done

    }

    if echo $sk_certs | grep -iq y; then

        echo "Downloading root certificates... "
        download_pem sk_root_2018_crt.pem https://c.sk.ee/EE-GovCA2018.pem.crt
        download_pem sk_root_2011_crt.pem https://www.sk.ee/upload/files/EE_Certification_Centre_Root_CA.pem.crt
        download_pem sk_esteid_2018_crt.pem https://c.sk.ee/esteid2018.pem.crt
        download_pem sk_esteid_2015_crt.pem https://www.sk.ee/upload/files/ESTEID-SK_2015.pem.crt
        download_pem sk_esteid_2011_crt.pem https://www.sk.ee/upload/files/ESTEID-SK_2011.pem.crt

        setup_client_auth_root_certificates sk_esteid_2018 sk_esteid_2015 sk_esteid_2011

        remove_client_auth_trust sk_root_2018 sk_root_2011

        # OCSP refresh
        echo "Downloading OCSP certs... "
        download_pem sk_esteid_ocsp_2011.pem https://www.sk.ee/upload/files/SK_OCSP_RESPONDER_2011.pem.cer

        cat sk_esteid_ocsp_2011.pem > sk_esteid_ocsp.pem
        rm -f sk_esteid_ocsp_2011.pem

        # update crl

        if ! ./updatecrl.sh "norestart"; then
            echo "ERROR: CRL update failed. Exiting installation script." >> /dev/stderr
            exit 3
        fi

    fi
fi
#echo "Rehashing Apache symbolic links at $(pwd)."
c_rehash ./

/etc/init.d/apache2 restart

#echo "Successfully installed xtee-misp2-base package"

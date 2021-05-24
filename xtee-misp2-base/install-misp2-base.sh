#!/bin/bash
#
# MISP2 application Apache Tomcat and Apache2 configuration
#
# Copyright (c) 2020- Nordic Institute for Interoperability Solutions (NIIS)
# Aktors (c) 2016

set -e

#export DEBIAN_SCRIPT_DEBUG=true

if [ -n "$DEBIAN_SCRIPT_DEBUG" ]; then
    set -x
    DEBIAN_SCRIPT_TRACE=1
fi

${DEBIAN_SCRIPT_TRACE:+ echo "#42#DEBUG# RUNNING $0 $*" 1>&2 }

# Source debconf library.
if [[ -e /usr/share/debconf/confmodule ]]; then
    # shellcheck source=/usr/share/debconf/confmodule
    . /usr/share/debconf/confmodule
fi

#
# installation locations
#

xrd_prefix=/usr/xtee
# use value of CATALINA_BASE or CATALINA_HOME or /var/lib/tomcat8 in priority order
catalina_base="${CATALINA_BASE:-${CATALINA_HOME:-/var/lib/tomcat8}}"
tomcat_defaults=/etc/default/tomcat8
apache2_home=/etc/apache2
mod_jk_home=/etc/libapache2-mod-jk
apache2_misp2_home=${apache2_home}/ssl
xrd_apache_home=${xrd_prefix}/apache2

#
# CI detection
#

ci_setup=n
if [ -a /tmp/ci_installation ]; then
    echo "CI setup noticed" >> /dev/stderr
    ci_setup=y
fi

#
# installation choices
#
#  - before package creation
skip_estonian=n

#
#  functions used by post-install
#

function show_template() {
    local template_name
    template_name="$1"
    db_input medium "${template_name}" || true
    # shellcheck disable=SC2119
    db_go  || true
}
function ci_fails() {
    if [ "$ci_setup" == "y" ]; then
        echo "CI setup fails ... $1" >> /dev/stderr
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
    grep -q -e 'Xmx1g' "${tomcat_defaults_file}" || echo 'JAVA_OPTS="${JAVA_OPTS} -Xmx1g"' >> "${tomcat_defaults_file}"

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
                                                   } }" $xrd_apache_home/ssl.conf
    rm "$ssl_tmp"
}

function configure_ajp_local_access_mod_jk_properties() {
    local workers_conf
    workers_conf="$1"
    regex_apache_ajp_host_localhost='(\s*worker[.]ajp13_worker[.]host\s*)=\s*localhost'
    if grep -Eq "$regex_apache_ajp_host_localhost" "$workers_conf"; then
        perl -pi -e 's|'"$regex_apache_ajp_host_localhost"'|$1=127.0.0.1|g' "$workers_conf"
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
        fi
    else
        echo "WARNING: AJP connector not found from '$tomcat_server_xml'. Cannot configure local AJP access." >> /dev/stderr
    fi
}

function arrange_apache_setup_utils_from_to() {
    local xrd_apache_path apache2_misp2_path apache_util_files
    xrd_apache_path="$1"
    apache2_misp2_path="$2"
    apache_util_files="updatecrl.sh create_ca_cert.sh create_server_cert.sh create_sslproxy_cert.sh misp2.cnf"

    [[ ! -d "$apache2_misp2_path" ]] && mkdir -p "$apache2_misp2_path"

    for file in ${apache_util_files}; do
        cp "$xrd_apache_path/$file" "$apache2_misp2_path"
        [[ "$file" == *.sh ]] && chmod 755 "$apache2_misp2_path/$file"
    done

    chmod 755 "$xrd_apache_path/cleanXFormsDir.sh"
}

function download_pem() {
    local pem_path="$1"
    local pem_url="$2"

    if ! wget -O "$pem_path" "$pem_url"; then
        code=$?
        db_subst xtee-misp2-base/text_error_pem_download_fail pem_path "${pem_path}"
        db_subst xtee-misp2-base/text_error_pem_download_fail pem_url "${pem_url}"
        db_subst xtee-misp2-base/text_error_pem_download_fail code "${code}"
        show_template xtee-misp2-base/text_error_pem_download_fail
        exit 1
    fi
    if ! (head -n 1 "$pem_path" | grep -q "BEGIN CERTIFICATE"); then
        db_subst xtee-misp2-base/text_error_pem_format_fail pem_path "${pem_path}"
        db_subst xtee-misp2-base/text_error_pem_format_fail pem_url "${pem_url}"
        show_template
        exit 2
    fi
    return 0
}

function setup_client_auth_root_certificates() {
    echo "Updating client root certificates... " >> /dev/stderr
    client_root_ca_path=$apache2_misp2_home/client_ca
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

function comment_out_SSLCADNRequestPath_apache_config() {
    apache_misp2_conf="$apache2_home/sites-available/ssl.conf"
    sed --in-place --regexp-extended --expression="s/^([ \t]*SSLCADNRequestPath.*)/#&1/" $apache_misp2_conf
}

function assert_tomcat_apache_installed() {
    if [ ! -d "$catalina_base" ]; then

        db_subst xtee-misp2-base/text_error_tomcat_instance_not_found catalina_base_var "$catalina_base"
        db_subst xtee-misp2-base/text_error_tomcat_instance_not_found CATALINA_BASE "${CATALINA_BASE}"
        db_subst xtee-misp2-base/text_error_tomcat_instance_not_found CATALINA_HOME "${CATALINA_HOME}"
        show_template xtee-misp2-base/text_error_tomcat_instance_not_found
        exit 1
    fi
    if [ ! -d $apache2_home ]; then
        db_subst xtee-misp2-base/text_error_apache2_home_not_found apache2_home ${apache2_home}
        show_template xtee-misp2-base/text_error_apache2_home_not_found
        exit 1
    fi
}

#
#   post-install begins
#

assert_tomcat_apache_installed

#
# user installation  choices from debconf
#

# has user allowed sk certificate update?
db_get shared/xtee-misp2/international_installation_requested
if [ "$RET" == "true" ]; then
    sk_certs=n
else
    sk_certs=y
fi
# apache config already installed ?
apache_ssl_config_exists=n
db_get xtee-misp2-base/apache_ssl_config_exists
if [ "$RET" == "true" ]; then
    apache_ssl_config_exists=y
fi

# can we overwrite the old config?
apache2_overwrite_confirmation=n
db_get xtee-misp2-base/apache2_overwrite_confirmation
if [ "$RET" == "true" ]; then
    apache2_overwrite_confirmation=y
fi

ensure_apache2_is_running

if [ -f ${tomcat_defaults} ]; then
    etc_default_tomcat_java_variables_for_misp2 ${tomcat_defaults}
fi

#replace server.xml
cp $xrd_apache_home/server.xml "$catalina_base/conf/"
#remove tomcat ROOT app in case it is not webapp itself
if [ ! -f "$catalina_base"/webapps/ROOT/WEB-INF/classes/config.cfg ]; then
    rm -rf "$catalina_base"/webapps/ROOT
fi
### add mod-jk.conf
cp $xrd_apache_home/jk.conf $apache2_home/mods-available/
### enable mods (if not enabled yet)
a2enmod jk rewrite ssl headers proxy_http

if [ "${apache2_overwrite_confirmation}" == "y" ]; then
    transfer_admin_access_ip_to_apache_setup_template
fi

cp $xrd_apache_home/ssl.conf $apache2_home/sites-available/ssl.conf

if [ "${apache_ssl_config_exists}" != "y" ]; then
    a2ensite ssl.conf
    a2dissite 000-default
fi

## AJP local access
# Only enable AJP protocol access from localhost to mitigate GhostCat vulnerability
configure_ajp_local_access_mod_jk_properties "${mod_jk_home}/workers.properties"
configure_ajp_local_access_tomcat_server_xml "$catalina_base/conf/server.xml"


arrange_apache_setup_utils_from_to $xrd_apache_home $apache2_misp2_home

cd $apache2_misp2_home

if [[ ! -f $apache2_misp2_home/ca.crl || ! -f $apache2_misp2_home/MISP2_CA_key.der ]]; then
    ./create_ca_cert.sh $apache2_misp2_home
fi

if [[ ! -f $apache2_misp2_home/httpsd.cert || ! -f $apache2_misp2_home/httpsd.key ]]; then
    ./create_server_cert.sh $apache2_misp2_home
fi
#   Changing server private key access rights to -r-------- if any rights are given to group or others
find $apache2_misp2_home -type f -name httpsd.key -perm /077 -exec chmod --verbose 400 \{\} \;

[[ $ci_setup == "y" ]] && sk_certs=n && echo "No Cert download in CI build " >> /dev/stderr
if [ "$skip_estonian" != "y" ] && [[ "${sk_certs}" == "y" ]]; then
    echo "Downloading Estonian root certificates... " >> /dev/stderr
    download_pem sk_root_2018_crt.pem https://c.sk.ee/EE-GovCA2018.pem.crt
    download_pem sk_root_2011_crt.pem https://www.sk.ee/upload/files/EE_Certification_Centre_Root_CA.pem.crt
    download_pem sk_esteid_2018_crt.pem https://c.sk.ee/esteid2018.pem.crt
    download_pem sk_esteid_2015_crt.pem https://www.sk.ee/upload/files/ESTEID-SK_2015.pem.crt
    download_pem sk_esteid_2011_crt.pem https://www.sk.ee/upload/files/ESTEID-SK_2011.pem.crt

    setup_client_auth_root_certificates sk_esteid_2018 sk_esteid_2015 sk_esteid_2011

    remove_client_auth_trust sk_root_2018 sk_root_2011

    # OCSP refresh
    echo "Downloading OCSP certs... " >> /dev/stderr
    download_pem sk_esteid_ocsp_2011.pem https://www.sk.ee/upload/files/SK_OCSP_RESPONDER_2011.pem.cer

    mv sk_esteid_ocsp_2011.pem sk_esteid_ocsp.pem

    # update crl

    if ! ./updatecrl.sh "norestart"; then
        show_template xtee-misp2-base/text_error_crl_update_failed
        exit 3
    fi
else
    echo "No estonian MObiili-ID auth" >> /dev/stderr
    comment_out_SSLCADNRequestPath_apache_config
fi

# Rehashing Apache symbolic links at $(pwd).
c_rehash ./

/usr/sbin/invoke-rc.d apache2 restart


#!/bin/bash
#
# MISP2 application Apache Tomcat and Apache2 configuration
#
# Copyright (c) 2020- Nordic Institute for Interoperability Solutions (NIIS)
# Aktors (c) 2016


set -e

# Source debconf library.
. /usr/share/debconf/confmodule
if [ -n "$DEBIAN_SCRIPT_DEBUG" ]; then set -v -x; DEBIAN_SCRIPT_TRACE=1; fi

${DEBIAN_SCRIPT_TRACE:+ echo "#42#DEBUG# RUNNING $0 $*" 1>&2 }

ci_setup=n
if [ -a /tmp/ci_installation ]
then
	echo "CI setup noticed" >> /dev/stderr
	ci_setup=y

fi

function ci_fails {
	if [ "$ci_setup" == "y" ]
	then
		echo "CI setup fails ... $1"
		exit 1 
	fi
}

xrd_prefix=/usr/xtee
tomcat_home=/var/lib/tomcat8
tomcat_share_home=/usr/share/tomcat8
apache2_home=/etc/apache2
# 'y' to skip estonian portal related prompt questions, 'n' to include them; value could be replaced before package generation
skip_estonian=n

# Check if Apache 2 server is running. If it's not, attempt to start.
status_adverb=
while ! /etc/init.d/apache2 status > /dev/null; do # do not show output, too verbose
    #echo "Apache2 service is not running, attempting to start it."
    /etc/init.d/apache2 start
    status_adverb=" now"
    sleep 1
done
#echo "Apache2 service is$status_adverb running."

if [ -f /etc/default/tomcat8 ]; then
    grep -q -e 'MaxPermSize' /etc/default/tomcat8 || echo 'JAVA_OPTS="${JAVA_OPTS} -Xms1g -Xmx1g -XX:MaxPermSize=256m"' >> /etc/default/tomcat8
    grep -q -e 'Xms1g' /etc/default/tomcat8 || echo 'JAVA_OPTS="${JAVA_OPTS} -Xms1g"' >> /etc/default/tomcat8
    grep -q -e 'Xms1g' /etc/default/tomcat8 || echo 'JAVA_OPTS="${JAVA_OPTS} -Xmx1g"' >> /etc/default/tomcat8

    # replace JAVA_HOME variable in tomcat8 configuration with environment variable if that exists
    if [ -d "$JAVA_HOME" ] && grep -q '#JAVA_HOME' /etc/default/tomcat8; then
        # regex replace
        #  - separator is ':'
        #  - only replace when JAVA_HOME is commented out like initially (#JAVA_HOME)
        #  - take replacement value from JAVA_HOME env variable and remove comment-out prefix #
        #  - g: replace all instances
        sed -ie 's:#JAVA_HOME=.*:JAVA_HOME="'$JAVA_HOME'":g' /etc/default/tomcat8
    fi
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

# TODO:  db-conf support missing until MISPDEV-19
#db_get xtee-misp2-base/apache2_overwrite_confirmation
# apache2_overwrite_confirmation="${RET}"
# for CI build we reconfigure ssl.conf anyhow
apache2_overwrite_confirmation=y
if [ -f $apache2_home/sites-available/ssl.conf ]; then

    if [ $(echo $apache2_overwrite_confirmation | grep -iq true) ]; then
        sed -n '/\/\*\/admin/, /\/Location/p' $apache2_home/sites-available/ssl.conf | grep Allow > /tmp/ssl.allowed.tmp
        sed -i '/\/\*\/admin/, /\/Location/p {
		 /Allow./{
		 s/.//g
		 r /tmp/ssl.allowed.tmp
		 }
		}' $xrd_prefix/apache2/ssl.conf
        cp $xrd_prefix/apache2/ssl.conf $apache2_home/sites-available/ssl.conf
    fi

else
    # echo "Copying Apache2 server conf to $apache2_home/sites-available/ssl.conf..."
    cp $xrd_prefix/apache2/ssl.conf $apache2_home/sites-available/ssl.conf
    a2ensite ssl.conf
    a2dissite 000-default
fi

## AJP local access
# Only enable AJP protocol access from localhost to mitigate GhostCat vulnerability
workers_conf="/etc/libapache2-mod-jk/workers.properties"
tomcat_server_xml="$tomcat_home/conf/server.xml"
if [ -f $workers_conf ]; then
    regex_apache_ajp_host_localhost='(\s*worker[.]ajp13_worker[.]host\s*)=\s*localhost'
    if grep -Eq "$regex_apache_ajp_host_localhost" $workers_conf; then
        perl -pi -e 's|'"$regex_apache_ajp_host_localhost"'|$1=127.0.0.1|g' $workers_conf
        # echo "Configured Apache server AJP connection host to 127.0.0.1 in '$workers_conf'."
    fi
else
    echo "ERROR: Could not find '$workers_conf' file. Cannot configure AJP local access." >> /dev/stderr
    exit 1
fi
if [ -f $tomcat_server_xml ]; then
    regex_ajp_connector='(\s*<Connector)(\s+.*protocol\s*=\s*"AJP/1.3".*)'
    str_ajp_connector="$(grep -E "$regex_ajp_connector" $tomcat_server_xml)"
    if [ "$str_ajp_connector" != "" ]; then
        if ! (echo "$str_ajp_connector" | grep -Eq 'address\s*=\s*'); then
            perl -pi -e 's|'"$regex_ajp_connector"'|$1 address="127.0.0.1"$2|g' $tomcat_server_xml
            #echo "Configured Tomcat server AJP connector address to 127.0.0.1 in '$tomcat_server_xml'."
            #echo "Restarting Tomcat server."
            service tomcat8 restart
        else
            # Message is not shown (directed to sink),
            # but may serve a purpose while debugging with bash -x
            echo "AJP address already configured." >> /dev/null
        fi
    else
        echo "WARNING: AJP connector not found from '$tomcat_server_xml'. Cannot configure local AJP access."  >> /dev/stderr
    fi
else
    echo "ERROR: Could not find '$tomcat_server_xml' file. Cannot configure AJP local access." >> /dev/stderr
    exit 1
fi
## AJP local access ends

#certs
#echo "Updating certificate scripts... "
if [ ! -d $apache2_home/ssl ]; then
    mkdir $apache2_home/ssl
fi

cd $apache2_home/ssl

cp $xrd_prefix/apache2/updatecrl.sh $apache2_home/ssl
cp $xrd_prefix/apache2/create_ca_cert.sh $apache2_home/ssl
cp $xrd_prefix/apache2/create_server_cert.sh $apache2_home/ssl
cp $xrd_prefix/apache2/misp2.cnf $apache2_home/ssl
cp $xrd_prefix/apache2/create_sslproxy_cert.sh $apache2_home/ssl

chmod 755 $xrd_prefix/apache2/cleanXFormsDir.sh
chmod 755 create_*_cert.sh

if [[ ! -f $apache2_home/ssl/ca.crl || ! -f $apache2_home/ssl/MISP2_CA_key.der ]]; then
    #echo "Creating CA certificate... "
    ./create_ca_cert.sh
else
    echo "CA certificate already created... " >> /dev/null
fi

if [[ ! -f $apache2_home/ssl/httpsd.cert || ! -f $apache2_home/ssl/httpsd.key ]]; then
    #echo "Creating server certificate... "
    ./create_server_cert.sh
else
    echo "Server certificate already created... " >> /dev/null
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

sk_certs=y
[ $ci_setup == "y" ] && sk_certs=n && echo "No Cert download in CI build " >> /dev/stderr
if [ "$skip_estonian" != "y" ] &&  $(echo $sk_certs | grep -iq y ) ; then
    
	function download_pem {
		local pem_path="$1"
		local pem_url="$2"

		wget -O "$pem_path" "$pem_url"

		local wget_result="$?"
		if [ "$wget_result" != "0" ]
		then
			echo "ERROR: Downloading PEM file '$pem_path' from '$pem_url' failed (code: $wget_result)." >> /dev/stderr
			exit 1
		elif ! (head -n 1 "$pem_path" | grep -q "BEGIN CERTIFICATE")
		then
			echo "ERROR: PEM file '$pem_path' downloaded from '$pem_url' is not in correct format." >> /dev/stderr
			exit 2
		fi
		return 0
	}

	function setup_client_auth_root_certificates {
		echo "Updating client root certificates... "
		client_root_ca_path=$apache2_home/ssl/client_ca
		if [ ! -d $client_root_ca_path ]
		then 
			mkdir $client_root_ca_path
		fi
		for cert in "$@"
		do
			downloaded_cert=${cert}_crt.pem
			auth_trusted_cert=${cert}_client_auth_trusted_crt.pem
			cp -v  ${downloaded_cert} $client_root_ca_path
			openssl x509 -addtrust clientAuth -trustout -in ${downloaded_cert} \
			              -out ${auth_trusted_cert}
			rm -v ${downloaded_cert}
		done
		c_rehash  $client_root_ca_path/
	}

	function  remove_client_auth_trust {
		for root_cert in "$@"
		do
			openssl x509 -addreject clientAuth -trustout -in ${root_cert}_crt.pem \
			              -out ${root_cert}_CA_trusted_crt.pem
			rm ${root_cert}_crt.pem
		done

	}

	
	if [ `echo $sk_certs | grep -i y ` ]
	then

		echo "Downloading root certificates... "
		download_pem  sk_root_2018_crt.pem    https://c.sk.ee/EE-GovCA2018.pem.crt
		download_pem  sk_root_2011_crt.pem    https://www.sk.ee/upload/files/EE_Certification_Centre_Root_CA.pem.crt
		download_pem  sk_esteid_2018_crt.pem  https://c.sk.ee/esteid2018.pem.crt
		download_pem  sk_esteid_2015_crt.pem  https://www.sk.ee/upload/files/ESTEID-SK_2015.pem.crt
		download_pem  sk_esteid_2011_crt.pem  https://www.sk.ee/upload/files/ESTEID-SK_2011.pem.crt

		setup_client_auth_root_certificates sk_esteid_2018 sk_esteid_2015 sk_esteid_2011 ; 

		remove_client_auth_trust sk_root_2018 sk_root_2011 ;

		# OCSP refresh
		echo "Downloading OCSP certs... "
		download_pem  sk_esteid_ocsp_2011.pem https://www.sk.ee/upload/files/SK_OCSP_RESPONDER_2011.pem.cer

		cat sk_esteid_ocsp_2011.pem > sk_esteid_ocsp.pem
		rm -f sk_esteid_ocsp_2011.pem

		# update crl 
		./updatecrl.sh "norestart"
		if [ "$?" != "0" ]
		then
			echo "ERROR: CRL update failed. Exiting installation script." >> /dev/stderr
			exit 3
		fi

	fi
fi
#echo "Rehashing Apache symbolic links at $(pwd)."
c_rehash ./

/etc/init.d/apache2 restart

#echo "Successfully installed xtee-misp2-base package"

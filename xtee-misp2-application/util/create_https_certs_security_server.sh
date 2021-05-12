#!/bin/bash

set -e
#must be at least 6 characters
truststore_path=/usr/xtee/apache2/misp2truststore.jks
keystore_path=/usr/xtee/apache2/misp2keystore.jks
tomcat_path=/etc/default/tomcat8
tomcat_restart=$1
tomcat_home=/var/lib/tomcat8
tomcat_init=/etc/init.d/tomcat8
conf_dir=/usr/xtee/apache2
create_sslproxy_cert=/etc/apache2/ssl/create_sslproxy_cert.sh

#
#   functions
#

function fix_dir_permissions_to_755_owner_root() {
    local dir
    dir="$1"
    if [ "$(id -u)" == "0" ] \
        && (stat -c %A "$dir" | grep -xq "drwx------") \
        && ! (stat -c %U "$dir" | grep -xq "tomcat8"); then
        # Change ownership of $conf_dir to root if it is not already
        if ! (stat -c %U "$dir" | grep -xq "root"); then
            echo "Changing '$dir' ownership to root."
            chown root:root "$dir"
        fi
        # Change access rights to 755 so that Tomcat ca access keystore and truststore
        echo "Changing '$dir' permissions to 755."
        chmod 755 "$dir"
    fi
}

function wait_ss_cert_file() {
    # Loop until user has copied cert archive to current dir
    local first_loop add_sec_cert
    first_loop=true
    add_sec_cert=n
    while [ ! -f certs.tar.gz ] && [ ! -f proxycert.tar.gz ] || [ $first_loop == true ]; do
        if [ $first_loop == true ]; then
            first_loop=false
        else # first_loop=false
            echo "File $conf_dir/certs.tar.gz does not exist."
        fi
        echo "Please add Security Server certificate archive 'certs.tar.gz' to the MISP2 server directory '$conf_dir/'."
        echo -n "Proceed with HTTPS configuration? (Answering 'no' means that HTTPS configuration will not be done this time) [y/n] [default: n] "
        read -r add_sec_cert < /dev/tty
        if [ "$add_sec_cert" == "" ]; then
            add_sec_cert="n"
        fi
        if (echo $add_sec_cert | grep -q -i y); then
            continue
        else
            exit 0
        fi
    done

}

function read_password {
    local target=$1
    local min_len=6
    password_value="" # global return value
    while [ "$password_value" == "" ]; do
        read -r -s -p "Enter $target password: " password_value
        echo
        # Since passwords are inserted to a bash script that concats Java command line arguments to string,
        # limit allowed characters to avoid problems caused by command line processing
        # (e.g. whitespaces as argument separators) and sed backslash separator during replacement.
        if (echo "$password_value" | grep -Eq -- '[^A-Za-z0-9_-]'); then
            echo "Only alphanumeric characters, '_' and '-' are allowed in $target password."
            password_value=""
        elif [ ${#password_value} -lt $min_len ]; then
            echo "Password has to be at least $min_len characters long."
            password_value=""
        fi
    done
}

function add_java_opt {
    local file_path="$1"
    local key="$2"
    local val="$3"
    local line="JAVA_OPTS=\"\${JAVA_OPTS} -D$key=$val\""

    if grep -Fq -- "-D$key=" "$file_path"; then # if key already exists in configuration
        # Only replace if $line is not already in conf, meaning new value is different
        if ! grep -Fxq "$line" "$file_path"; then
            sed -i "/-D$key=.*/c\\$line" "$file_path"
            echo "Changed $key value in $file_path."
        fi
    else # if key is missing from configuration
        echo "$line" >> "$file_path"
        echo "Added $key parameter to $file_path."
    fi
}

function get_cert_cer_from_archive() {
	local archive sec_server_cert_file

	# global var: cert name that needs to be created then at the end 
	out_cert_name=""

    # Extract cert archive name from existing files in current directory
    archive=$(find ./ -maxdepth 1 -type f \
        \( -name "certs.tar.gz" -o -name "proxycert.tar.gz" \) -printf "%f\n" | sort | head -n 1)

    # Avoid extracting random files from archive; only extract cert.cer or cert.der
    sec_server_cert_file=$(tar tf "$archive" 2> /dev/null | grep -Ex "(\\./)?cert\\.[cd]er" | head -n 1)

    # Extract security server certificate from archive
    if [ "$sec_server_cert_file" != "" ]; then
        echo "Extracting '$sec_server_cert_file' from '$archive'."
        tar xzvf "$archive" "$sec_server_cert_file"
    else
        echo "Archive '$archive' does not contain 'cert.cer' or 'cert.der'."
        echo "Cannot continue HTTPS configuration."
        exit 1
    fi
    # If extracted file is cert.der, rename it to cert.cer
    if (find "$sec_server_cert_file" -maxdepth 1 -printf "%f\n" | grep -Fxq "cert.der"); then
        echo "Renaming '$sec_server_cert_file' to 'cert.cer'."
        mv "$sec_server_cert_file" cert.cer
        out_cert_name=cert.der
    else
        out_cert_name=cert.cer
    fi

}

#
#  action begins
#
echo "Creating ssl certificate"

fix_dir_permissions_to_755_owner_root "$conf_dir"

# Change current dir to conf_dir
cd "$conf_dir"

wait_ss_cert_file

# Remove existing certificate files, truststore and keystore
rm -f cert.der cert.cer misp2truststore.jks misp2keystore.jks

get_cert_cer_from_archive

if [ -f cert.cer ]; then

    read_password "truststore"
    truststore_password="$password_value"
    read_password "keystore"
    keystore_password="$password_value"

    echo "Adding Security Server certificate to truststore."
    keytool -import -keystore misp2truststore.jks -file cert.cer -storepass "$truststore_password"

	

    echo "Adding webapp private key to keystore "
	# this creates files sslproxy.cert and sslproxy.key
    sh "${create_sslproxy_cert}"
	sslproxy_cert_basename="sslproxy"

    openssl pkcs12 -export -in ${sslproxy_cert_basename}.cert -inkey ${sslproxy_cert_basename}.key -out misp2.p12 -passout "pass:$keystore_password"

    keytool -importkeystore -srcstoretype PKCS12 -srckeystore misp2.p12 -destkeystore misp2keystore.jks \
        -keypass "$keystore_password" -deststorepass "$keystore_password" -srcstorepass "$keystore_password"
    echo "Keystore and truststore ready."

    echo "Writing changes to Tomcat configuration."
    add_java_opt "$tomcat_path" "javax.net.ssl.trustStore" "$truststore_path"
    add_java_opt "$tomcat_path" "javax.net.ssl.trustStorePassword" "$truststore_password"
    add_java_opt "$tomcat_path" "javax.net.ssl.keyStore" "$keystore_path"
    add_java_opt "$tomcat_path" "javax.net.ssl.keyStorePassword" "$keystore_password"
    echo "Configuration changes done."

    if ! (echo "$tomcat_restart" | grep -iq omitrestart); then
        echo "Restarting Tomcat..."
        if [ ! -f $tomcat_init ]; then
            echo "Shutdown Tomcat..."
            $tomcat_home/bin/shutdown.sh
            echo "Tomcat starting up..."
            $tomcat_home/bin/startup.sh
        else
            "$tomcat_init" restart
        fi
    fi
    out_cert_path="$conf_dir/$out_cert_name"
    # Copy preserving original access rights and owner of sslproxy.cert
    cp -p ${sslproxy_cert_basename}.cert "$out_cert_path"
    echo
    echo "Get '$out_cert_path' and add it to your Security Server."
    echo
else
    echo "Security Server certificate 'cert.cer' not found from '$conf_dir/' directory."
fi

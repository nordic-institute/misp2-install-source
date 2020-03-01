#!/bin/bash

set -e
if [ "$DEBUG" == "1" ]
then
	set -x
fi
cacerts_path=/etc/ssl/certs/java/cacerts
#must be at least 6 characters
keystore_path=/usr/xtee/apache2/misp2keystore.jks
tomcat_path=/etc/default/tomcat8
add_sec_cert=n
script_args="$*"
tomcat_home=/var/lib/tomcat8
tomcat_init=/etc/init.d/tomcat8
conf_dir=/usr/xtee/apache2
out_cert_name=cert.cer

# Functions

##
# Find command line argument with given text
# @arg arg_name search string for command line arguments
# @return 0 if #arg_name was found from command line arguments, 1 if not
##
function has_arg {
	local arg_name="$1"
	for script_arg in $script_args
	do
		if [ "$script_arg" == "$arg_name" ]
		then
			return 0
		fi
	done
	return 1
}

##
# Find an entry from script command line arguments matching #arg_name and echo
# the next command line argument to stdout.
# @arg arg_name command line argument from which the next argument value is sent to stdout.
# @return next command line argument to stdout
##
function get_arg_after {
	local arg_name="$1"
	echo "$script_args" | awk -v "argName=$arg_name" '{
		for(i = 1; i < NF; i++) {
			if ($i == argName) {
				print $(i + 1);
			}
		}
	}'
}

##
# Matches lines from standard input with #prefix.
# In case string matches, removes #prefix and echoes the remaining part to stdout.
# @param prefix string prefix to which all the strings from standard input are compared.
#       String matches #prefix if the strings starts with #prefix.
# @return filtered text to standard output
##
function remove_match_prefix {
	local prefix="$1"
	awk -v "prefix=$prefix" '
		index($0, prefix) == 1 {
			lp = length(prefix);
			l0 = length($0);
			print substr($0, lp + 1, l0 - lp);
		}' < /dev/stdin
}

##
# Print Java option value in Tomcat configuration file declaration to stdout.
# @param file_path path to Tomcat configuration file where JAVA_OPT-s are declared 
# @param key Java option key 
# @return option value to stdout
##
function get_java_opt {
	local file_path="$1"
	local key="$2"
	for java_opt in $(source "$file_path"; echo "$JAVA_OPTS")
	do
		echo "$java_opt" | remove_match_prefix "-D$key="
	done
}

##
# Remove Java option declaration with a given key from Tomcat configuration file.
# (also removes commented out declaration).
# @param file_path path to Tomcat configuration file where JAVA_OPT-s are declared 
# @param key Java option key 
##
function remove_java_opt {
	local file_path="$1"
	local key="$2"
	echo "Commenting out Java option '$key' in '$file_path'."
	perl -pi -e 's|^(\s*JAVA_OPTS=.*\s-D'"$key"'=.*)|# No longer used (can be removed): $1|g' "$file_path"
	#delete entirely: perl -pi -e 's|^\s*[#]?\s*JAVA_OPTS=.*\s-D'"$key"'=.*\n?||g' "$file_path"
}

##
# Add Java option declaration with a given key and value to Tomcat configuration file
# or change it, if the line already exists.
# @param file_path path to Tomcat configuration file where JAVA_OPT-s are declared 
# @param key Java option key 
# @param val Java option value
##
function add_java_opt {
	local file_path="$1"
	local key="$2"
	local val="$3"
	local line="JAVA_OPTS=\"\${JAVA_OPTS} -D$key=$val\""

	if grep -Fq -- "-D$key=" "$file_path" # if key already exists in configuration
	then
		# Only replace if $line is not already in conf, meaning new value is different
		if ! grep -Fxq "$line" "$file_path"
		then
			sed -i "/-D$key=.*/c\\$line" "$file_path"
			echo "Changed $key value in $file_path."
		fi
	else # if key is missing from configuration	
		echo "$line" >> "$file_path"
		echo "Added $key parameter to $file_path."
	fi
}

##
# Prompt password from user and store it in $password_value global variable.
# @param target password target text (used in prompt message)
##
function read_password {
	local target="$1"
	local min_len=6
	password_value=""; # global return value
	while [ "$password_value" == "" ] ; do
		read -s -p "Enter $target password: " password_value
		echo
		# Since passwords are inserted to a bash script that concats Java command line arguments to string,
		# limit allowed characters to avoid problems caused by command line processing 
		# (e.g. whitespaces as argument separators) and sed backslash separator during replacement.
		if (echo "$password_value" | grep -Eq -- '[^A-Za-z0-9_-]')
		then
			echo "Only alphanumeric characters, '_' and '-' are allowed in $target password."
			password_value=""
		elif [ ${#password_value} -lt $min_len ]
		then
			echo "Password has to be at least $min_len characters long."
			password_value=""
		fi
	done
}

##
# Check if a given password is valid for given keystore.
# @param path path to keystore file
# @param password keystore password to be tested
# @return 0 if keystore password is valid
#         1 or greater otherwise
##
function check_keystore_password {
	local path="$1"
	local password="$2"
	keytool -list -keystore "$path" -storepass "$password" >> /dev/null
	return $?
}

##
# Get cacerts password and set the value to global variable $cacerts_password.
# If default password does not give access the cacerts store, then prompt the password
# from user. Otherwise use default.
# The function expects global variables $cacerts_path and $cacerts_password.
# The function changes the value in global variable $cacerts_password.
##
function set_cacerts_password {
	cacerts_password="changeit"
	# If default password does not work for cacerts, prompt the password from user.
	if ! check_keystore_password "$cacerts_path" "$cacerts_password"
	then
		read_password "cacerts"
		cacerts_password="$password_value"
	fi
}

##
# Restart Tomcat web server if --omit-restart script argument is not given.
##
function restart_tomcat_if_needed {
	if ! has_arg '--omit-restart'
	then
		echo "Restarting Tomcat..."
		if [ -f $tomcat_init ]
		then
			"$tomcat_init" restart
		else
			echo "ERROR: Cannot restart Tomcat, '$tomcat_init' missing." >> /dev/stderr
			exit 1
		fi
	fi
}

##
# Get alias name from command line input of current script
# or use default value if command line argument is not given.
# @return echo the result to stdout
##
function get_alias {
	# Get alias for the cert from command line arguments
	alias_name="$(get_arg_after "--alias")"
	# If alias is missing from command line, use default
	if [ "$alias_name" == "" ]
	then
		alias_name="xroad_security_server"
	fi
	echo "$alias_name"

}

##
# List cert alias names contained in a keystore.
# @return echo the result to stdout, each alias on new line.
##
function get_keystore_aliases {
	local path="$1"
	local password="$2"
	keytool -list -keystore  "$path" -storepass  "$password" -rfc |\
		remove_match_prefix "Alias name: " |\
		sort -u
}

##
# @return 0 if script needs to add a certificate to trusted certs, 1 if not
##
function is_adding_trusted_cert_needed {
	if ! has_arg "--omit-trust-cert"
	then
		echo "Adding certificate to trusted certs in Java cacerts."
		return 0
	else
		echo "Not adding certificate to trusted certs."
		return 1
	fi
}

function is_new_keypair_needed {
	if [ ! -f sslproxy.cert ]
	then
		local expl="File 'sslproxy.cert' missing."
	elif [ ! -f sslproxy.key ]
	then
		local expl="File 'sslproxy.key' missing."
	elif has_arg '--new-keypair'
	then
		local expl="Found argument '--new-keypair'."
	else
		return 1
	fi

	echo "Creating new SSL keys and adding them to keystore. ($expl)"
	return 0
}
##
# @return 0 if script needs to generate a new keystore, 1 if not
##
function is_new_keystore_needed {
	if is_new_keypair_needed
	then
		return 0;
	fi

	if [ ! -f misp2keystore.jks ]
	then
		local expl="File 'misp2keystore.jks' missing."
	elif has_arg '--new-keystore'
	then
		local expl="Found argument '--new-keystore'."
	else
		echo "Keystore already exists, not creating new."
		return 1
	fi

	echo "Creating new keystore. ($expl)"
	return 0
}

##
# Add special character to stdout to color text.
# @arg color name (empty string, 'cert' or 'end' currently allowed)
##
function color {
	local arg="$1"
	if [ "$arg" == "start" ]
	then
		echo -ne "\e[33m"
	elif [ "$arg" == "cert" ]
	then
		echo -ne "\e[92m"
	elif [ "$arg" == "end" ]
	then
		echo -ne "\e[0m"
	else
		echo "ERROR: Unexpected color '$arg'" >> /dev/stdout
	fi
}
##
# Print cert data to stdout using keytool.
# @arg cert path to certificate
##
function print_cert {
	local cert="$1"
	color cert
	keytool -printcert -file "$cert" | awk '{
	    # Skip Extensions up to SubjectAlternativeName
	    if (index($0, "Extensions:") == 1) {
		extensions = 1;
		print "[...]"
	    }
	    else if (index($0, "SubjectAlternativeName") == 1) {
		last_extension = 1;
	    }
	    if (!extensions && !last_extension || last_extension) {
		print $0;
	    }
	}'
	color end
}

if has_arg '--help'
then
cat <<EOF
The script sets up HTTPS connection between security server and MISP2 webapp.
It also performs custom Java truststore contents migration to cacerts in order to support HTTPS in webapp. 

The script takes the following arguments (all optional):
--migrate-truststore-to-cacerts
    If argument is given, runs security server certificate migration from truststore to cacerts.
    Otherwise configures HTTPS connection.
--truststore-path ARG
    If argument and value are given, take truststore location from next command line argument.
    If not given, take it from Tomcat default configuration file.
    Only used during migration.
--truststore-password ARG
    If argument and value are given, take truststore password from next command line argument.
    If not given, take it from Tomcat default configuration file.
    Only used during migration.
--alias ARG
    Alias to be used in store instead of generic alias 'mykey'.
    Used in both, cacerts migration and adding a trusted certificate.
--omit-trust-cert
    If argument is given, add new certificate to cacerts as trusted certificate.
    If not given, skip adding new trusted certificate to cacerts.
    Argument is not used during migration.
--new-keystore
    If argument is given, generate new Java keystore, but not necessarily new key-pair.
    Generating new keystore also changes the SSL client certificate
    that MISP2 webapp uses for HTTPS requests.
    If not given, generate new keystore only if either misp2keystore.jks or SSL key-pair is missing.
    Argument is not used during migration.
--new-keypair
    If argument is given, generate new SSL key-pair and Java keystore.
    This action always includes the option --new-keystore.
    If not given, generate new key-pair only if either sslproxy.key or sslproxy.cert is missing.
    Argument is not used during migration.
--omit-restart
    If argument is given, do not restart Tomcat after truststore has been created.
    Otherwise Tomcat server is restarted.
--help
    Displays this help.

EOF
exit 0
fi

if has_arg '--migrate-truststore-to-cacerts'
then
	truststore_path="$(get_arg_after "--truststore-path")"
	if [ "$truststore_path" == "" ]
	then
		truststore_path="$(get_java_opt "$tomcat_path" "javax.net.ssl.trustStore")"
	fi

	truststore_password="$(get_arg_after "--truststore-password")"
	if [ "$truststore_password" == "" ]
	then
		truststore_password="$(get_java_opt "$tomcat_path" "javax.net.ssl.trustStorePassword")"
	fi

	if [ "$truststore_path" != "" ]
	then
		echo -e "A custom truststore definition was found from Tomcat configuration."	
		echo -e "For HTTPS connectivity within MISP2 web application, cacerts should be included."
		echo -n "Do you want to migrate truststore contents to cacerts? [y/n] [default: y] "
		read migrate_to_cacerts < /dev/tty

		if [ "$migrate_to_cacerts" != "" ] && ! (echo "$migrate_to_cacerts" | grep -iq "y")
		then
			echo "Not migrating truststore contents to cacerts."
			exit 0
		fi

		# Read in cacerts password
		set_cacerts_password

		if [ ! -f "$truststore_path" ]
		then
			echo "ERROR: Truststore '$truststore_path' does not exist." >> /dev/stderr
			exit 1
		elif ! check_keystore_password "$truststore_path" "$truststore_password"
		then
			echo "ERROR: Password '$truststore_password' does not match truststore '$truststore_path'." >> /dev/stderr
			exit 1
		elif [ ! -f "$cacerts_path" ]
		then
			echo "ERROR: Java cacerts file at '$cacerts_path' does not exist." >> /dev/stderr
			exit 1
		elif ! check_keystore_password "$cacerts_path" "$cacerts_password"
		then
			echo "ERROR: Password '$cacerts_password' does not match cacerts file '$cacerts_path'." >> /dev/stderr
			exit 1
		else
			# Rename generic alias name in truststore to a more descriptive alias name (if needed)
			generic_alias_name="mykey"
			if (get_keystore_aliases "$truststore_path" "$truststore_password" | grep -qFx "$generic_alias_name")
			then
				alias_name="$(get_alias)"
				echo "Renaming alias '$generic_alias_name' to '$alias_name' in $truststore_path."
				color start
				keytool -changealias -alias "$generic_alias_name"  -destalias "$alias_name" \
					-keystore "$truststore_path" -storepass "$truststore_password"
				color end
			fi

			# Delete aliases from cacerts that exist in exported truststore,
			# otherwise keytool throws an error during import, in case alias already exists.
			src_aliases_file="/tmp/src_aliases"
			dst_aliases_file="/tmp/dst_aliases"
			get_keystore_aliases "$truststore_path" "$truststore_password" > "$src_aliases_file"
			get_keystore_aliases "$cacerts_path"    "$cacerts_password"    > "$dst_aliases_file"

			# Use 'grep -Fxf' to find common lines in both files
			for existing_alias in $(grep -Fxf "$src_aliases_file" "$dst_aliases_file")
			do
				echo "Removing '$existing_alias' from cacerts before truststore import."
				color start
				keytool -delete -keystore "$cacerts_path" -storepass "$cacerts_password" -alias "$existing_alias"
				color end
			done
			rm "$dst_aliases_file" "$src_aliases_file"

			# Importing truststore from '$truststore_path' to cacerts
			color start
			keytool -importkeystore -noprompt \
				-srcstoretype  jks -srckeystore  "$truststore_path" -srcstorepass  "$truststore_password" \
				-deststoretype jks -destkeystore "$cacerts_path"    -deststorepass "$cacerts_password"
			result=$?
			color end
			if [ "$result" != "0" ]
			then
				echo "ERROR: Importing to cacerts failed." >> /dev/stderr
				exit 1
			else
				echo "Importing truststore to cacerts succeeded."
				truststore_backup="$truststore_path.not-used"
				echo "Renaming truststore."
				mv -v "$truststore_path" "$truststore_backup"
				echo "Truststore at '$truststore_backup' can now be deleted."
				#echo "Deleting truststore."
				#rm -vf "$truststore_backup"
			fi
		fi

		remove_java_opt "$tomcat_path" "javax.net.ssl.trustStore"
		remove_java_opt "$tomcat_path" "javax.net.ssl.trustStorePassword"

		echo "Migrated truststore to cacerts."

		restart_tomcat_if_needed
	else
		echo "Truststore is not set. Nothing to migrate to cacerts."
	fi
else
	# If $conf_dir has been made not readable with 'tar' (700 access rights)
	# make it readable to any user, but writable only for root
	if [ "$(id -u)" == "0" ] && \
		(stat -c %A "$conf_dir" | grep -xq "drwx------") && \
		! (stat -c %U "$conf_dir" | grep -xq "tomcat8")
	then
		# Change ownership of $conf_dir to root if it is not already
		if ! (stat -c %U "$conf_dir" | grep -xq "root")
		then
			echo "Changing '$conf_dir' ownership to root."
			chown root:root "$conf_dir"
		fi
		# Change access rights to 755 so that Tomcat ca access keystore
		echo "Changing '$conf_dir' permissions to 755."
		chmod 755 "$conf_dir"
	fi

	# Change current dir to conf_dir
	cd "$conf_dir"

	if is_adding_trusted_cert_needed
	then
		# Loop until user has copied cert archive to current dir
		first_loop=true
		while [ ! -f certs.tar.gz ] && [ ! -f proxycert.tar.gz ] || [ $first_loop == true ]
		do
			if [ $first_loop == true ]
			then
				first_loop=false
			else # first_loop=false
				echo "File $conf_dir/certs.tar.gz does not exist."
			fi

			echo "Please add Security Server certificate archive 'certs.tar.gz' to the MISP2 server directory '$conf_dir/'."
			echo -n "Proceed with HTTPS configuration? (Answering 'no' means that HTTPS configuration will not be done this time) [y/n] [default: n] "
			read add_sec_cert < /dev/tty
			if [ "$add_sec_cert" == "" ]
			then
				add_sec_cert="n"
			fi
			if [ `echo $add_sec_cert | grep -i y ` ]
			then
				continue
			else
				exit
			fi
		done

		# Remove existing certificate files and truststore
		rm -f cert.der cert.cer misp2truststore.jks

		# Extract cert archive name from existing files in current directory
		archive=$(find ./ -maxdepth 1 -type f \
			\( -name "certs.tar.gz" -o -name "proxycert.tar.gz" \) -printf "%f\n" | sort | head -n 1)

		# Avoid extracting random files from archive; only extract cert.cer or cert.der
		sec_server_cert_file=$(tar tf "$archive" 2> /dev/null | grep -Ex "(\\./)?cert\\.[cd]er" | head -n 1)

		# Extract security server certificate from archive
		if [ "$sec_server_cert_file" != "" ]
		then
			echo "Extracting '$sec_server_cert_file' from '$archive'."
			tar xzf "$archive" "$sec_server_cert_file"
			if [ "$?" != "0" ]
			then
				echo "ERROR! Extracting '$sec_server_cert_file' from '$archive' failed."
			fi
		else
			echo "Archive '$archive' does not contain 'cert.cer' or 'cert.der'."
			echo "Cannot continue HTTPS configuration." >> /dev/stderr
			exit 1
		fi
		# If extracted file is cert.der, rename it to cert.cer
		if (find "$sec_server_cert_file" -maxdepth 1 -printf "%f\n" | grep -Fxq "cert.der")
		then
			echo "Renaming '$sec_server_cert_file' to 'cert.cer'."
			mv "$sec_server_cert_file" cert.cer
			out_cert_name=cert.der
		fi

		if [ -f cert.cer ]
		then
			alias_name="$(get_alias)"
			echo "Adding the following certificate to cacerts ($cacerts_path) under alias '$alias_name':"
			print_cert "cert.cer"

			set_cacerts_password
			# Delete entry with given alias, if it already exists in cacerts
			keytool -delete	-keystore "$cacerts_path" \
				-storepass "$cacerts_password" -alias "$alias_name" \
				2>&1 >> /dev/null || true

			color start
			keytool -import -noprompt -keystore "$cacerts_path" -file cert.cer \
				-storepass "$cacerts_password" -alias "$alias_name"
			result=$?
			color end
			if [ "$result" != "0" ]
			then
				echo "ERROR: Adding trusted cert to cacerts failed." >> /dev/stderr
				exit 1
			fi
			echo "Security server certificate has been added to cacerts."

		else
			echo "Security Server certificate 'cert.cer' not found from '$conf_dir/' directory."
			exit 1
		fi
	fi

	if is_new_keystore_needed
	then
		# Remove existing certificate files and keystore
		rm -f cert.der cert.cer misp2keystore.jks

		read_password "keystore"
		keystore_password="$password_value"

		if is_new_keypair_needed >> /dev/null
		then
			echo "Generating new SSL keypair."
			bash /etc/apache2/ssl/create_sslproxy_cert.sh
		fi

		echo "Adding the following certificate to keystore:"
		print_cert "sslproxy.cert"

		openssl pkcs12 -export -in sslproxy.cert -inkey sslproxy.key -out misp2.p12 -passout "pass:$keystore_password"
		if [ "$?" != "0" ]
		then
			echo "ERROR: Converting cert to p12 format failed." >> /dev/stderr
			exit 1
		fi

		color start
		keytool -noprompt -importkeystore -srcstoretype PKCS12 -srckeystore misp2.p12 -destkeystore misp2keystore.jks \
			-keypass "$keystore_password" -deststorepass "$keystore_password" -srcstorepass "$keystore_password" \
			2>&1 | grep -Ev "^(Warning:|The JKS keystore uses)" >> /dev/stderr
		result=$?
		color end
		if [ "$result" != "0" ]
		then
			echo "ERROR: Adding key to keystore failed." >> /dev/stderr
			exit 1
		fi
		echo "Keystore created."

		echo "Writing changes to Tomcat configuration."
		add_java_opt "$tomcat_path" "javax.net.ssl.keyStore"         "$keystore_path"
		add_java_opt "$tomcat_path" "javax.net.ssl.keyStorePassword" "$keystore_password"
		echo "Configuration changes done."
	fi

	restart_tomcat_if_needed

	# Copy preserving original access rights and owner of sslproxy.cert
	out_cert_path="$conf_dir/$out_cert_name"
	cp -p sslproxy.cert "$out_cert_path"
	echo
	echo "Get '$out_cert_path' and add it to your Security Server."
	echo
fi

#!/bin/bash
#
# MISP2 web application package
#
# Aktors 2016

xrd_prefix=/usr/xtee
tomcat_home=/var/lib/tomcat8
app_name=misp2
host=127.0.0.1
port=5432
db_name=misp2db
username=misp2
username_pass=
config_https=n
config_mobile_id=n
install_default=upgrade
email_host=localhost
email_sender=root@localhost
apache2=/etc/apache2
# 'y' if portal is configured in international mode, 'n' if not; value could be replaced before package generation
configure_international=y
# 'y' to skip estonian portal related prompt questions, 'n' to include them; value could be replaced before package generation
skip_estonian=y

# 'y' for asking nothing from user and setting everything for MISP AWS test setup. 
#         if that's not possible, fail fast (exit 1)

ci_setup=n
if [ -a /usr/xtee/app/ci_installation ]
then
	echo "CI setup noticed" >> /dev/stderr
	ci_setup=y

fi

# default password for ci setup
[ "${ci_setup}" == "y" ]  && username_pass="changeit"

#####################
# Declare functions #
#####################

function ci_fails {
	if [ "$ci_setup" == "y" ]
	then
		echo "CI setup fails ... $1"
		exit 1 
	fi
}
##
# @return success code (0) if MISP2 deployment directory with conf files exist
#         failure code (1) if MISP2 deployment directory or conf files do not exist
##
function misp2_deployed {
	deploy_dir=$tomcat_home/webapps/$app_name
	classes_dir=$deploy_dir/WEB-INF/classes
	meta_inf_dir=$deploy_dir/META-INF

	# Check whether webapp files exist that indicate deployment in Tomcat
	if	[[ -d $classes_dir 			]] &&
		[[ -f $classes_dir/config.cfg 		]] && 
		[[ -f $classes_dir/orgportal-conf.cfg	]] && 
		[[ -f $classes_dir/uniportal-conf.cfg	]] && 
		#[[ -f $classes_dir/log4j.properties	]] && 
		[[ -d $meta_inf_dir 			]] && 
		[[ -f $meta_inf_dir/context.xml 	]]
	then
		# Else webapp has been deployed
		return 0
	else
		# If not all deployment directory files exist, webapp has not yet deployed
		return 1
	fi
}

##
# Wait until MISP2 webapp has been deployed and echo out waiting status
##
function wait_for_misp2_deployment {
	start_time=$SECONDS
	time_spent=""
	while	! misp2_deployed
	do
		time_spent=$(($SECONDS - $start_time))
		echo -ne "...Waiting for MISP2 webapp deployment... ($time_spent s)"\\r  >> /dev/stderr
		sleep 0.5
	done
	sleep 1
	# Add another newline if previous entry was a line update
	[ "$time_spent" != "" ] && echo
	echo "...MISP2 webapp deployment done..." >> /dev/stderr
}

##
# @return success code (0) if MISP2 deployment directory and WAR does not exist
#         failure code (1) if MISP2 deployment directory or WAR exists
##
function misp2_undeployed {
	deploy_dir=$tomcat_home/webapps/$app_name
	war_full_path=$deploy_dir.war
	# Check whether webapp Tomcat deployment directory or the corresponding WAR file exist
	if	[[ -d $deploy_dir 			]] ||
		[[ -f $war_full_path			]]
	then
		# WAR or deployment directory still exists, webapp has not yet been undeployed
		return 1
	else
		# Neither WAR nor deployment directory exist, webapp has totally undeployed
		return 0
	fi
}

##
# Wait until MISP2 webapp has been undeployed and echo out waiting status
##
function wait_for_misp2_undeployment {
	start_time=$SECONDS
	time_spent=""
	while	! misp2_undeployed
	do
		time_spent=$(($SECONDS - $start_time))
		echo -ne "...Waiting for MISP2 webapp undeployment... ($time_spent s)"\\r >> /dev/stderr
		sleep 0.5
	done
	sleep 1
	# Add another newline if previous entry was a line update
	[ "$time_spent" != "" ] && echo
	echo "...MISP2 webapp undeployment done..." >> /dev/stderr
}

##
# Check if misp2 version is older than given version.
# @param input_ver given Maven version string
#        that version is compared to existing version in webapp POM
# @param pom_path optional param, if empty
# @return 0 if existing Webapp version is older than given version, return 1 otherwise
##
function is_misp2_ver_older_than {
	local input_ver="$1"
	if [ "$2" != "" ]
	then
		local pom_path="$2"
	else
		local pom_path="$tomcat_home/webapps/$app_name/META-INF/maven/misp2/misp2/pom.xml"
	fi

	if ! [ -f "$pom_path" ]
	then
		# File does not exist so it cannot be older
		return 1
	fi
	# find WAR POM version by taking text between first found 'version>' and '<' 
	local existing_ver=$(perl -p -e "BEGIN{undef $/;} s/^.*?version[^<]*>([^<]+).*$/\1/smg" "$pom_path")
	
	
	# split Maven version strings to arrays by either '.' or '-' 
	IFS='.-' read -r -a ar_input_ver <<< "$input_ver"
	IFS='.-' read -r -a ar_existing_ver <<< "$existing_ver"

	# compare versions and if one 
	if 	(( ${ar_input_ver[0]} > ${ar_existing_ver[0]} ))
	then
		return 0
	elif (( ${ar_input_ver[0]} == ${ar_existing_ver[0]} ))
	then 
		if (( ${ar_input_ver[1]} > ${ar_existing_ver[1]} ))
		then
			return 0
		elif (( ${ar_input_ver[1]} == ${ar_existing_ver[1]} ))
		then
			if (( ${ar_input_ver[2]} > ${ar_existing_ver[2]} ))
			then
				return 0
			fi
		fi
	fi
	return 1
}

##
# Replace property by property name in config.orig.cfg file.
# Property can be commented out and existing property value does not matter,
# As a result, the replaced line will always be left commented in (enabled).
# If property is not found, nothing is replaced.
# @param prop_name property name (key) in config.orig.cfg file
# @param prop_value new property value assigned to found property
##
function replace_conf_prop {
    prop_name="$1"
    prop_value="$2"
    replacement_expression='s/^#?\s*'"${prop_name//./[.]}"'\s*=.*/'"$prop_name"'='"${prop_value//\//\\\/}"'/g'
	perl -pi -e "$replacement_expression" $xrd_prefix/app/config.orig.cfg
}

##############################################
# Begin MISP2 package installation
##############################################
# Check if Tomcat server is running. If it's not, attempt to start.
status_adverb=
while ! /etc/init.d/tomcat8 status > /dev/null # do not show output, too verbose
do
	ci_fails "Tomcat service is not running"
	echo "Tomcat7 service is not running, attempting to start it." >> /dev/stderr
	/etc/init.d/tomcat8 start
	status_adverb=" now"
	sleep 1
done
echo "Tomcat7 service is$status_adverb running." >> /dev/stderr

# Ask tomcat location
if [ ! -d $tomcat_home/webapps ]
then
	ci_fails "Default tomcat directory not found at: $tomcat_home/webapps"
	echo -n "Please provide Apache Tomcat working directory [default: $tomcat_home]: "  >> /dev/stderr
	read user_tomcat < /dev/tty
	if [ "$user_tomcat" == "" ]
	then
			user_tomcat=$tomcat_home
	fi
	tomcat_home=$user_tomcat
fi

if [ ! -d $tomcat_home/webapps ]
then
	echo "$tomcat_home/webapps is not found" >> /dev/stderr
	exit 1
fi

# If misp2 deploy directory exists then upgrade else install
if [ -d $tomcat_home/webapps/$app_name ]
then
	echo "Found MISP2 deploy directory so upgrading.." >> /dev/stderr
	#ci_fails "MISP2 upgrade not yet supported TODO!"
	install_default=upgrade
else
	echo "Did not find MISP2 deploy directory '$tomcat_home/webapps/$app_name' so installing new.." >> /dev/stderr
	install_default=install
fi


xroad_instances="EE,ee-dev,ee-test"
international_xroad_instances="eu-dev,eu-test,eu"
xroad_member_classes="COM,ORG,GOV,NEE"
international_member_classes="COM,NGO,ORG,GOV"

if [ "$install_default" == "upgrade" ]
then
	echo " === Upgrading MISP2 application  ===" >> /dev/stderr
	echo " " >> /dev/stderr

	$xrd_prefix/app/create_https_certs_security_server.sh --migrate-truststore-to-cacerts --omit-restart
	if [ "$?" != "0" ]
	then
		exit 1
	fi
	
### copy war file to the tomcat webapps directory
### backuping configuration
	echo " === Backing up configuration === " >> /dev/stderr
	cp $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg /tmp/config.cfg.bkp
	cp $tomcat_home/webapps/$app_name/WEB-INF/classes/orgportal-conf.cfg /tmp/orgportal-conf.cfg.bkp
	cp $tomcat_home/webapps/$app_name/WEB-INF/classes/uniportal-conf.cfg /tmp/uniportal-conf.cfg.bkp
	#cp $tomcat_home/webapps/$app_name/WEB-INF/classes/log4j.properties /tmp/log4j.properties.bkp
	
	#Synchronize existing config properties with default ones
	java -Xmx1024M -jar $xrd_prefix/app/propertySynchronizer.jar -s $xrd_prefix/app/config.orig.cfg -t /tmp/config.cfg.bkp -r /tmp/config.cfg.bkp -e ISO-8859-1
	if [ $? -ne 0 ]
	then
		echo "Config properties synchronization has failed" >> /dev/stderr
		exit 1
	fi
	
	#Synchronize existing log4j properties with default ones
	#java -Xmx1024M -jar $xrd_prefix/app/propertySynchronizer.jar -s $xrd_prefix/app/log4j.properties -t /tmp/log4j.properties.bkp -r /tmp/log4j.properties.bkp -e ISO-8859-1
	#if [ $? -ne 0 ]
	#then
	#	echo "log4j properties synchronization has failed"
	#	exit 1
	#fi
	
# check if localhost:8080 exists and rewrite it to localhost (since v. 1.20 Tomcat port 8080 in closed)
	sed 's/localhost:8080/localhost/g' -i /tmp/config.cfg.bkp
# remove ^M from config file
	sed -i s/\\r//g /tmp/config.cfg.bkp
# replace default producer filtering property since producer identifier changed in ver 2.1.28
	perl -pi -e 'BEGIN {$text = q{xrd.v6.exclude_producers_regex = ^([^:]+:[^:]+)|([^:]+:[^:]+:generic-consumer}; $text2=q{xrd.v6.exclude_producers_regex = ^([^:]+:[^:]+:[^:]+)|([^:]+:[^:]+:[^:]+:generic-consumer}} s/\Q$text\E/$text2/g' /tmp/config.cfg.bkp
# config.cfg replacements done 
# rewrite context file
	perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/context.orig.xml
	perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/admintool.sh

	if is_misp2_ver_older_than "2.1.30"
	then
		remove_work_dir=true
	else
		remove_work_dir=false
	fi
	
	if [ "$remove_work_dir" == true ]
	then
		# MISP2 version has older Struts version 2.3, meaning we need to clear Tomcat work directory
		# of existing JSP-s before deploying Struts 2.5-based webapp. Otherwise Tomcat might not recompile them.
		echo " ... Struts 2.5 migration detected ... " >> /dev/stderr
		echo " === Undeploying previous version of MISP2 and clearing work directory. === " >> /dev/stderr
		echo " ... Shutting down Tomcat to clear work directory. ... " >> /dev/stderr
		/etc/init.d/tomcat8 stop
		
		echo " ... Removing $app_name from webapps directory ... " >> /dev/stderr
		rm -rf $tomcat_home/webapps/$app_name*
		
		tomcat_work_dir="$tomcat_home/work/Catalina/localhost/$app_name"
		echo " ... Clearing Tomcat work directory for $app_name at $tomcat_work_dir ... " >> /dev/stderr
		rm -rf "$tomcat_work_dir"
		
		echo " ... Starting up Tomcat ... " >> /dev/stderr
		/etc/init.d/tomcat8 start
	else
		# Normal use case, work directory is not cleared
		echo " === Undeploying previous version of MISP2 web application === " >> /dev/stderr
		rm -rf $tomcat_home/webapps/$app_name*
		wait_for_misp2_undeployment
	fi	

	echo " === Deploying new version of MISP2 web application === " >> /dev/stderr
	cp $xrd_prefix/app/*.war $tomcat_home/webapps/$app_name.war
	wait_for_misp2_deployment
	
	echo " === Restoring configuration === " >> /dev/stderr
### restoring configuration
	if [ ! -d $tomcat_home/webapps/$app_name/WEB-INF/classes -o ! -d $tomcat_home/webapps/$app_name/META-INF ]
	then
		echo "WARNING! Previous configuration could not be restored. Either Tomcat was not running or deployment of the application did not finish in time. When installation is complete copy the files /tmp/config.cfg.bkp (to $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg), /tmp/log4j.properties.bkp (to $tomcat_home/webapps/$app_name/WEB-INF/classes/log4j.properties) and $xrd_prefix/app/context.orig.xml (to $tomcat_home/webapps/$app_name/META-INF/context.xml) manually." >> /dev/stderr
	else
		cp /tmp/config.cfg.bkp $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg
		cp /tmp/orgportal-conf.cfg.bkp $tomcat_home/webapps/$app_name/WEB-INF/classes/orgportal-conf.cfg
		cp /tmp/uniportal-conf.cfg.bkp $tomcat_home/webapps/$app_name/WEB-INF/classes/uniportal-conf.cfg
		#cp /tmp/log4j.properties.bkp $tomcat_home/webapps/$app_name/WEB-INF/classes/log4j.properties 
		#cp /tmp/context.xml.bkp $tomcat_home/webapps/$app_name/META-INF/context.xml - disabled since 1.24 because we want to make sure that context is correct
		cp $xrd_prefix/app/context.orig.xml $tomcat_home/webapps/$app_name/META-INF/context.xml
	fi
	
### replacing new key values in configuration
	if grep -Eq 'languages\s*=\s*et' $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg
	then
		configure_international="n"
		echo "Updating Estonian version" >> /dev/stderr
	else
		configure_international="y"
		echo "Updating international version" >> /dev/stderr
	fi
	if grep -q 'XROAD_INSTANCES' $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg
	then
		# Prompt for user input if configure_international=y and international_xroad_instances variable is set
		if [ "$configure_international" == "y" ] && [ -n "${international_xroad_instances+x}" ]
		then
			xroad_instances=$international_xroad_instances
			echo -n "Please provide X-Road v6 instances (comma separated list)? [default: $xroad_instances] " >> /dev/stderr
			[ -z "$PS1" ] || read user_xroad_instances < /dev/tty
			if [ "$user_xroad_instances" != "" ]
			then
				xroad_instances=$user_xroad_instances
			fi
		fi
		echo "Updating X-Road instances $xroad_instances" >> /dev/stderr
		perl -pi -e "s/XROAD_INSTANCES/$xroad_instances/" $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg
	fi
	
	if grep -q 'XROAD_MEMBER_CLASSES' $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg
	then
		# Prompt for user input if configure_international=y and international_member_classes variable is set
		if [ "$configure_international" == "y" ] && [ -n "${international_member_classes+x}" ]
		then
			xroad_member_classes=$international_member_classes
			echo -n "Please provide X-Road v6 member classes (comma separated list)? [default: $xroad_member_classes] " >> /dev/stderr
			[ -z "$PS1" ] || read user_xroad_member_classes < /dev/tty
			if [ "$user_xroad_member_classes" != "" ]
			then
				xroad_member_classes=$user_xroad_member_classes
			fi
		fi
		echo "Updating X-Road member classes $xroad_member_classes" >> /dev/stderr
		perl -pi -e "s/XROAD_MEMBER_CLASSES/$xroad_member_classes/" $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg
	fi
fi


if [ "$install_default" == "install" ]
then

	echo " === Deploying MISP2 web application === " >> /dev/stderr
	echo " " >> /dev/stderr
	### copy war file to the tomcat webapps directory
	cp $xrd_prefix/app/*.war $tomcat_home/webapps/$app_name.war
		
	# Only prompt when estonian portal related questions are not skipped
	if [ "$skip_estonian" != "y" ]
	then
		echo -n "Do you want to configure as international version (if no, then will be configured as estonian version)? [y/n] [default: n]: " >> /dev/stderr
		ci_fails "no questions possible"
		read configure_international < /dev/tty
	fi

	# Override original config properties with international config properties
	# Synchronize international conf with original, if application is configured as international version
	if [ "$configure_international" == "y" ]
	then
		java -Xmx1024M -jar $xrd_prefix/app/propertySynchronizer.jar -s $xrd_prefix/app/config.orig.cfg -t $xrd_prefix/app/config.origForInternational.cfg -r $xrd_prefix/app/config.orig.cfg -e ISO-8859-1
		if [ $? -ne 0 ]
		then
			echo "Original and international config synchronization has failed" >> /dev/stderr
			exit 1
		fi
	fi

	### database config
	
	echo -n "Please provide database host IP to be used [default: $host]: " >> /dev/stderr
	[ -z "$PS1" ] ||  read user_host < /dev/tty
	if [ "$user_host" == "" ]
	then
		user_host=$host
	fi
	host=$user_host

	echo -n "Please provide database port to be used [default: $port]: " >> /dev/stderr
	[ -z "$PS1" ] || read user_port < /dev/tty
	if [ "$user_port" == "" ]
	then
		user_port=$port
	fi
	port=$user_port


	echo -n "Please provide database name to be used [default: $db_name]: " >> /dev/stderr
	[ -z "$PS1" ] || read user_db < /dev/tty
	if [ "$user_db" == "" ]
	then
		user_db=$db_name
	fi
	db_name=$user_db


	echo -n "Please provide username to be communicating with database [default: $username]: " >> /dev/stderr
	[ -z "$PS1" ] || read user_username < /dev/tty
	if [ "$user_username" == "" ]
	then
		user_username=$username
	fi
	username=$user_username

	# Prompt for DB password
	if [ "$username_pass" == "" ] && [[ ! $(lsb_release --short --release) < "16.04" ]]
	then # release is Xenial or newer (not older than 16.04), do not allow empty password
		# Get new password from user
		while [ "$username_pass" == "" ]
		do
			# Note, backslash is interpreted as a quoting symbol, to insert backslash, user needs to input '\\'
			[ -z "$PS1" ] || read-s -p "Please enter password for database user '$username': " username_pass
			echo
			if [ "$username_pass" == "" ]
			then
				echo "Empty user passwords do not work any more starting from PostgreSQL version 9.5." >> /dev/stderr
			fi
		done
	else # release is Trusty or older, allow empty password
		[ -z "$PS1" ] || read-s -p "Please enter username password: [default: $username_pass]: " username_password
		if [ "$username_password" == "" ]
		then
			username_password=$username_pass
		fi
		username_pass=$username_password
	fi
	
	echo "" >> /dev/stderr
	if [ "$skip_estonian" != "y" ]
	then
		### configure Mobile-ID 
		###

		echo -n "Do you want to enable authentication with Mobile-ID? [y/n] [default: $config_mobile_id] " >> /dev/stderr
		[ -z "$PS1" ] || readuser_config_mobile_id < /dev/tty
		if [ "$user_config_mobile_id" == "" ]
		then
			# By default use default configuration
			user_config_mobile_id="$config_mobile_id"
		fi

		if (echo $user_config_mobile_id | grep -i y ) >> /dev/stderr
                then
			config_mobile_id=y
		else
			config_mobile_id=n
		fi


        if [ "$config_mobile_id" == "y" ]
        then
            mobile_id_url="https://mid.sk.ee/mid-api"
            mobile_id_polling_timeout=60

            while [ "$mobile_id_relying_party_uuid" == "" ]
            do
                echo "Please provide your Mobile-ID relying party UUID" >> /dev/stderr
                echo -n " (format: 00000000-0000-0000-0000-000000000000): " >> /dev/stderr
                [ -z "$PS1" ] || read mobile_id_relying_party_uuid < /dev/tty
                if [ "$mobile_id_relying_party_uuid" == "" ]
                then
                    echo "WARNING! UUID cannot be empty. Please try again." >> /dev/stderr
                fi
            done

            while [ "$mobile_id_relying_party_name" == "" ]
            do
                echo -n "Please provide your Mobile-ID relying party name: " >> /dev/stderr
                read mobile_id_relying_party_name < /dev/tty
                if [ "$mobile_id_relying_party_name" == "" ]
                then
                    echo "WARNING! Name cannot be empty. Please try again." >> /dev/stderr
                fi
            done
        fi
    fi


	### configure mail servers
	##
	echo -n "Please provide SMTP host address [default: $email_host]: " >> /dev/stderr
			[ -z "$PS1" ] || readuser_email_host < /dev/tty
			if [ "$user_email_host" == "" ]
			then
					user_email_host=$email_host
			fi
			email_host=$user_email_host

	### sender address
			echo -n "Please provide server email address: [default: $email_sender]: " >> /dev/stderr
			[ -z "$PS1" ] || read user_email_sender < /dev/tty
			if [ "$user_email_sender" == "" ]
			then
					user_email_sender=$email_sender
			fi
			email_sender=$user_email_sender
	email_sender=$(echo $email_sender | sed 's/\@/\\@/g') >> /dev/stderr

	# Prompt for user input if configure_international=y and international_xroad_instances variable is set
	if [ "$configure_international" == "y" ] && [ -n "${international_xroad_instances+x}" ]
	then
		xroad_instances=$international_xroad_instances
		echo -n "Please provide X-Road v6 instances (comma separated list)? [default: $xroad_instances] " >> /dev/stderr
		[ -z "$PS1" ] || read user_xroad_instances < /dev/tty
		if [ "$user_xroad_instances" != "" ]
		then
			xroad_instances=$user_xroad_instances
		fi
	fi
	
	# Prompt for user input if configure_international=y and international_member_classes variable is set
	if [ "$configure_international" == "y" ] && [ -n "${international_member_classes+x}" ]
	then
		xroad_member_classes=$international_member_classes
		echo -n "Please provide X-Road v6 member classes (comma separated list)? [default: $xroad_member_classes] " >> /dev/stderr
		[ -z "$PS1" ] || read user_xroad_member_classes < /dev/tty
		if [ "$user_xroad_member_classes" != "" ]
		then
			xroad_member_classes=$user_xroad_member_classes
		fi
	fi

	### updating configuration files using perl replace
	### config.cfg
	perl -pi -e "s/MISP2DBHOST/$host/" $xrd_prefix/app/config.orig.cfg
	perl -pi -e "s/MISP2DBPORT/$port/" $xrd_prefix/app/config.orig.cfg
	perl -pi -e "s/MISP2DBNAME/$db_name/" $xrd_prefix/app/config.orig.cfg
	perl -pi -e "s/MISP2DBUSERNAME/$username/" $xrd_prefix/app/config.orig.cfg
	
	# replace '/' with '\/' to create regex replacement string where slashes are quoted
	username_pass="${username_pass//\//\\\/}"
	perl -pi -e "s/MISP2DBPASSWORD/$username_pass/" $xrd_prefix/app/config.orig.cfg
	perl -pi -e "s/EMAILHOST/$email_host/" $xrd_prefix/app/config.orig.cfg
	perl -pi -e "s/EMAILSENDER/$email_sender/" $xrd_prefix/app/config.orig.cfg
	perl -pi -e "s/XROAD_INSTANCES/$xroad_instances/" $xrd_prefix/app/config.orig.cfg
	perl -pi -e "s/XROAD_MEMBER_CLASSES/$xroad_member_classes/" $xrd_prefix/app/config.orig.cfg

    if [ "$config_mobile_id" == "y" ]
    then
        replace_conf_prop "auth.mobileID" "true"
        if [ "$mobile_id_relying_party_uuid" != "" ]
        then
            replace_conf_prop "mobileID.rest.hostUrl"               "$mobile_id_url"
            replace_conf_prop "mobileID.rest.relyingPartyUUID"      "$mobile_id_relying_party_uuid"
            replace_conf_prop "mobileID.rest.relyingPartyName"      "$mobile_id_relying_party_name"
            replace_conf_prop "mobileID.rest.pollingTimeoutSeconds" "$mobile_id_polling_timeout"
        fi

    fi
	sed -i s/\\r//g $xrd_prefix/app/config.orig.cfg

	### META-INF/context.xml config
	perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/context.orig.xml
	perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/admintool.sh

	wait_for_misp2_deployment

	echo "Copying configuration files..." >> /dev/stderr
	cp $xrd_prefix/app/config.orig.cfg $tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg
	exit1=$?
	cp $xrd_prefix/app/context.orig.xml $tomcat_home/webapps/$app_name/META-INF/context.xml
	exit2=$?
	echo "Copying certificates if they exist..." >> /dev/stderr
	if [ -f $apache2/ssl/MISP2_CA_cert.pem ]
		then cp $apache2/ssl/MISP2_CA_cert.pem $tomcat_home/webapps/$app_name/WEB-INF/classes/certs/MISP2_CA_cert.pem
		echo "Copying certificates 1" >> /dev/stderr
	fi
	if [ -f $apache2/ssl/MISP2_CA_key.pem ]
		then cp $apache2/ssl/MISP2_CA_key.pem $tomcat_home/webapps/$app_name/WEB-INF/classes/certs/MISP2_CA_key.pem
	fi
	if [ -f $apache2/ssl/MISP2_CA_key.der ]
		then cp $apache2/ssl/MISP2_CA_key.der $tomcat_home/webapps/$app_name/WEB-INF/classes/certs/MISP2_CA_key.der
	fi
	if [ $exit1 -ne 0 -o $exit2 -ne 0 ]
	then
		echo "Cannot copy files. Maybe they haven't yet been deployed by Tomcat. Please make sure that Tomcat is running and rerun the installation. Exit codes: $exit1 $exit2 $exit3" >> /dev/stderr
		exit 1
	else
		echo "Configuration files created" >> /dev/stderr
		echo -n "Do you want to add new administrator account? [y/n] [default: y] " >> /dev/stderr
		if [ -z "$PS1" ] 
		then
			# no admin account added in ci build
		 	admin_add="n"   
		else
		 	readadmin_add < /dev/tty
		fi 
		if [ "$admin_add" == "" ]
		then
				admin_add="y"
		fi
		if [ `echo $admin_add | grep -i y ` ]
		then
			echo "Adding administrator account: " >> /dev/stderr
			$xrd_prefix/app/admintool.sh -add
			$xrd_prefix/app/configure_admin_interface_ip.sh change
		fi
	fi
	
	echo -n "Do you want to enable HTTPS connection between MISP2 application and security server? [y/n] [default: n] " >> /dev/stderr
	[ -z "$PS1" ] || read config_https < /dev/tty
	if [ "$config_https" == "" ]
	then
		config_https="n"
	fi
	if [ `echo $config_https | grep -i y ` ]
	then
		[ -z "$PS1" ] || $xrd_prefix/app/create_https_certs_security_server.sh --omit-restart || true
		if [ "$?" != "0" ]
		then
			exit 1
		fi
	fi
fi

#Remove cached jsp-s, because for some reason Tomcat does not recompile jsp-s currently. After this deletion however, tomcat will compile jsp-s
rm -f -r /var/cache/tomcat8/Catalina/localhost/$app_name/org/apache/jsp

echo "Restarting Tomcat..." >> /dev/stderr
if [ ! -f /etc/init.d/tomcat8 ]
then 
	echo "Shutdown Tomcat..." >> /dev/stderr
	$tomcat_home/bin/shutdown.sh
	echo "Tomcat starting up..." >> /dev/stderr
	$tomcat_home/bin/startup.sh
else
	/etc/init.d/tomcat8 restart
fi



echo "Successfully installed application $app_name" >> /dev/stderr
echo "You can change the configuration of application later by editing this file: " >> /dev/stderr
echo "$tomcat_home/webapps/$app_name/WEB-INF/classes/config.cfg" >> /dev/stderr

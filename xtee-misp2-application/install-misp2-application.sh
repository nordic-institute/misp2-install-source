#!/bin/bash
#
# MISP2 web application package
#
# Copyright: 2020 NIIS <info@niis.org>

#
#  installation choices to do before package creation
#
# 'y' if portal is configured in international mode, 'n' if not; value could be replaced before package generation
configure_international=y
# 'y' to skip estonian portal related prompt questions, 'n' to include them; value could be replaced before package generation
skip_estonian=y
#
# 
app_name=misp2


#
# installation locations
#
xrd_prefix=/usr/xtee
tomcat_home=/var/lib/tomcat8
apache2=/etc/apache2
misp2_tomcat_resources=$tomcat_home/webapps/$app_name/WEB-INF/classes

#
# default values for user installation choices
#
host=127.0.0.1
port=5432
db_name=misp2db
username=misp2
username_pass=${MISP2_PASSWORD:secret}
config_mobile_id=n
email_host=localhost
email_sender=root@localhost
xroad_instances="EE,ee-dev,ee-test"
international_xroad_instances="eu-dev,eu-test,eu"
xroad_member_classes="COM,ORG,GOV,NEE"
international_member_classes="COM,NGO,ORG,GOV"
mobile_id_truststore_path="$misp2_tomcat_resources/mobiili_id_trust_store.p12"



# recognizing the continuous build - should happen with apt-get install -qq..
# for asking nothing from user and setting everything for MISP AWS test setup.
#         if that's not possible, fail fast (exit 1)
ci_setup=n
if [ -a /tmp/ci_installation ]; then
    echo "CI setup noticed" >> /dev/stderr
    ci_setup=y

fi

# default password for ci setup
[ "${ci_setup}" == "y" ] && username_pass="secret"

#####################
# Declare functions #
#####################

function ci_fails {
    if [ "$ci_setup" == "y" ]; then
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
    if [[ -d $classes_dir ]] \
        && [[ -f $classes_dir/config.cfg ]] \
        && [[ -f $classes_dir/orgportal-conf.cfg ]] \
        && [[ -f $classes_dir/uniportal-conf.cfg ]] \
        &&
        

        #[[ -f $classes_dir/log4j.properties	]] &&
        [[ -d $meta_inf_dir ]] \
        && [[ -f $meta_inf_dir/context.xml ]]; then
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
    while ! misp2_deployed; do
        time_spent=$(($SECONDS - $start_time))
        echo -ne "...Waiting for MISP2 webapp deployment... ($time_spent s)"\\r >> /dev/stderr
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
    if [[ -d $deploy_dir ]] \
        || [[ -f $war_full_path ]]; then
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
    while ! misp2_undeployed; do
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

##
# misp2-base pkg installation already fetched & installed Mobile ID certificates for Apache2
# This function imports them to jks / PKCS12 type keystore in MISP2 deployment
# It's needed for Mobile ID authentication
##
function add_trusted_apache_certs_to_jks_store {
    mobile_id_truststore_p12_file="$1"  # full path to intended .p12 file
    truststore_dir=$(dirname "${mobile_id_truststore_p12_file}" )
    mobile_id_truststore_file="${truststore_dir}/$(basename  --suffix=.p12 "${mobile_id_truststore_p12_file}")"
    standard_trust_store_pwd="${username_pass:-secret}"

    apache_cert_files=$(find ${apache2}/ssl/ -regex '.*trusted_crt.pem')

    for apache_cert_file in $apache_cert_files; do

        cert_alias=$(basename "$apache_cert_file" _trusted_crt.pem)
        echo "$cert_alias"
        openssl x509 -in "${apache_cert_file}" \
            | keytool -import -v -storepass ${standard_trust_store_pwd} \
                -noprompt -trustcacerts -alias "${cert_alias}" \
                -keystore "${mobile_id_truststore_file}".jks
    done
    [ -r "${mobile_id_truststore_file}".jks ] && keytool -importkeystore -noprompt \
        -srckeystore "${mobile_id_truststore_file}".jks -srcstoretype JKS \
        -srcstorepass ${standard_trust_store_pwd} \
        -destkeystore "${mobile_id_truststore_file}".p12 -deststoretype PKCS12 \
        -deststorepass ${standard_trust_store_pwd}

    [ -r "${mobile_id_truststore_file}".jks ] && rm "${mobile_id_truststore_file}".jks
}

function ensure_tomcat_is_running() {
    status_adverb=
    while ! /usr/sbin/invoke-rc.d tomcat8 status > /dev/null; do # do not show output, too verbose
        ci_fails "Tomcat service is not running"
        echo "tomcat8 service is not running, attempting to start it." >> /dev/stderr
        /usr/sbin/invoke-rc.d tomcat8 start
        status_adverb=" now"
        sleep 1
    done
    echo "tomcat8 service is$status_adverb running." >> /dev/stderr
}

function query_for_valid_tomcat_home_dir_if_needed() {
    if [ ! -d $tomcat_home/webapps ]; then
        ci_fails "Default tomcat directory not found at: $tomcat_home/webapps"
        echo -n "Please provide Apache Tomcat working directory [default: $tomcat_home]: " >> /dev/stderr
        read -r user_tomcat < /dev/tty
        if [ "$user_tomcat" == "" ]; then
            user_tomcat=$tomcat_home
        fi
        tomcat_home=$user_tomcat
    fi
    if [ ! -d $tomcat_home/webapps ]; then
        echo "$tomcat_home/webapps is not found" >> /dev/stderr
        exit 1
    fi
}

##############################################
# Begin MISP2 package installation
##############################################

ensure_tomcat_is_running

query_for_valid_tomcat_home_dir_if_needed

if [ -d $tomcat_home/webapps/$app_name ]; then
    {
        echo " === Found MISP2 deploy directory so upgrading MISP2 application  ==="
        echo " "
    } >> /dev/stderr

    conf_backup=$( mktemp --directory --tmpdir misp2_config_backup_XXXXXX)
    

    ### backuping configuration
    echo " === Backing up configuration === to ${conf_backup}" >> /dev/stderr
    cp "$misp2_tomcat_resources"/config.cfg "${conf_backup}"/config.cfg.bkp
    cp "$misp2_tomcat_resources"/orgportal-conf.cfg "${conf_backup}"/orgportal-conf.cfg.bkp
    cp "$misp2_tomcat_resources"/uniportal-conf.cfg "${conf_backup}"/uniportal-conf.cfg.bkp

    #Synchronize existing config properties with default ones

    if java -Xmx1024M -jar $xrd_prefix/app/propertySynchronizer.jar \
        -s $xrd_prefix/app/config.orig.cfg \
        -t "${conf_backup}"/config.cfg.bkp \
        -r "${conf_backup}"/config.cfg.bkp -e ISO-8859-1; then
        echo "Config properties synchronization has failed" >> /dev/stderr
        exit 1
    fi

    # remove ^M from config file
    sed -i s/\\r//g "${conf_backup}"/config.cfg.bkp

    # config.cfg replacements done
    # rewrite context file
    perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/context.orig.xml
    perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/admintool.sh

    echo " === Undeploying previous version of MISP2 web application === " >> /dev/stderr
    rm -rf $tomcat_home/webapps/$app_name*
    wait_for_misp2_undeployment

    echo " === Deploying new version of MISP2 web application === " >> /dev/stderr
    cp $xrd_prefix/app/*.war $tomcat_home/webapps/$app_name.war
    wait_for_misp2_deployment

    echo " === Restoring configuration === " >> /dev/stderr
    ### restoring configuration
    if [ ! -d $misp2_tomcat_resources -o ! -d $tomcat_home/webapps/$app_name/META-INF ]; then
        echo -e "\t\t WARNING! Previous configuration could not be restored. \n\
                 Either Tomcat was not running or deployment of the application did not finish in time.\n\
                 When installation is complete copy the files: \n\
                 ${conf_backup}/config.cfg.bkp (to $misp2_tomcat_resources/config.cfg), \n\
                 ${conf_backup}/log4j.properties.bkp (to $misp2_tomcat_resources/log4j.properties) and \n\
                 $xrd_prefix/app/context.orig.xml (to $tomcat_home/webapps/$app_name/META-INF/context.xml) manually." >> /dev/stderr
    else
        cp "${conf_backup}"/config.cfg.bkp $misp2_tomcat_resources/config.cfg
        cp "${conf_backup}"/orgportal-conf.cfg.bkp $misp2_tomcat_resources/orgportal-conf.cfg
        cp "${conf_backup}"/uniportal-conf.cfg.bkp $misp2_tomcat_resources/uniportal-conf.cfg
        cp $xrd_prefix/app/context.orig.xml $tomcat_home/webapps/$app_name/META-INF/context.xml
        add_trusted_apache_certs_to_jks_store  "$mobile_id_truststore_path"
    fi

    ### replacing new key values in configuration
    if grep -Eq 'languages\s*=\s*et' $misp2_tomcat_resources/config.cfg; then
        configure_international="n"
        echo "Updating Estonian version" >> /dev/stderr
    else
        configure_international="y"
        echo "Updating international version" >> /dev/stderr
    fi
    if grep -q 'XROAD_INSTANCES' $misp2_tomcat_resources/config.cfg; then
        # Prompt for user input if configure_international=y and international_xroad_instances variable is set
        if [ "$configure_international" == "y" ] && [ -n "${international_xroad_instances+x}" ]; then
            xroad_instances=$international_xroad_instances
            echo -n "Please provide X-Road v6 instances (comma separated list)? [default: $xroad_instances] " >> /dev/stderr
            [ -z "$PS1" ] || read user_xroad_instances < /dev/tty
            if [ "$user_xroad_instances" != "" ]; then
                xroad_instances=$user_xroad_instances
            fi
        fi
        echo "Updating X-Road instances $xroad_instances" >> /dev/stderr
        perl -pi -e "s/XROAD_INSTANCES/$xroad_instances/" $misp2_tomcat_resources/config.cfg
    fi
    if grep -q 'XROAD_MEMBER_CLASSES' $misp2_tomcat_resources/config.cfg; then
        # Prompt for user input if configure_international=y and international_member_classes variable is set
        if [ "$configure_international" == "y" ] && [ -n "${international_member_classes+x}" ]; then
            xroad_member_classes=$international_member_classes
            echo -n "Please provide X-Road v6 member classes (comma separated list)? [default: $xroad_member_classes] " >> /dev/stderr
            [ -z "$PS1" ] || read user_xroad_member_classes < /dev/tty
            if [ "$user_xroad_member_classes" != "" ]; then
                xroad_member_classes=$user_xroad_member_classes
            fi
        fi
        echo "Updating X-Road member classes $xroad_member_classes" >> /dev/stderr
        perl -pi -e "s/XROAD_MEMBER_CLASSES/$xroad_member_classes/" $misp2_tomcat_resources/config.cfg
    fi
else
    echo "Did not find MISP2 deploy directory '$tomcat_home/webapps/$app_name' so installing new.." >> /dev/stderr
    echo " " >> /dev/stderr
    ### copy war file to the tomcat webapps directory
    cp $xrd_prefix/app/*.war $tomcat_home/webapps/$app_name.war

    # Only prompt when estonian portal related questions are not skipped
    if [ "$skip_estonian" != "y" ]; then
        echo -n "Do you want to configure as international version (if no, then will be configured as estonian version)? [y/n] [default: n]: " >> /dev/stderr
        ci_fails "no questions possible"
        read configure_international < /dev/tty
    fi

    # Override original config properties with international config properties
    # Synchronize international conf with original, if application is configured as international version
    if [ "$configure_international" == "y" ]; then
        java -Xmx1024M -jar $xrd_prefix/app/propertySynchronizer.jar -s $xrd_prefix/app/config.orig.cfg -t $xrd_prefix/app/config.origForInternational.cfg -r $xrd_prefix/app/config.orig.cfg -e ISO-8859-1
        if [ $? -ne 0 ]; then
            echo "Original and international config synchronization has failed" >> /dev/stderr
            exit 1
        fi
    fi

    ### database config

    echo -n "Please provide database host IP to be used [default: $host]: " >> /dev/stderr
    [ -z "$PS1" ] || read user_host < /dev/tty
    if [ "$user_host" == "" ]; then
        user_host=$host
    fi
    host=$user_host

    echo -n "Please provide database port to be used [default: $port]: " >> /dev/stderr
    [ -z "$PS1" ] || read user_port < /dev/tty
    if [ "$user_port" == "" ]; then
        user_port=$port
    fi
    port=$user_port

    echo -n "Please provide database name to be used [default: $db_name]: " >> /dev/stderr
    [ -z "$PS1" ] || read user_db < /dev/tty
    if [ "$user_db" == "" ]; then
        user_db=$db_name
    fi
    db_name=$user_db

    echo -n "Please provide username to be communicating with database [default: $username]: " >> /dev/stderr
    [ -z "$PS1" ] || read user_username < /dev/tty
    if [ "$user_username" == "" ]; then
        user_username=$username
    fi
    username=$user_username

    # Prompt for DB password
    if [ "$username_pass" == "" ]; then
        # Get new password from user
        while [ "$username_pass" == "" ]; do
            # Note, backslash is interpreted as a quoting symbol, to insert backslash, user needs to input '\\'
            [ -z "$PS1" ] || read-s -p "Please enter password for database user '$username': " username_pass
            echo
            if [ "$username_pass" == "" ]; then
                echo "Empty user passwords do not work any more starting from PostgreSQL version 9.5." >> /dev/stderr
            fi
        done
    fi

    echo "" >> /dev/stderr
    if [ "$skip_estonian" != "y" ]; then
        ### configure Mobile-ID
        ###

        echo -n "Do you want to enable authentication with Mobile-ID? [y/n] [default: $config_mobile_id] " >> /dev/stderr
        [ -z "$PS1" ] || readuser_config_mobile_id < /dev/tty
        if [ "$user_config_mobile_id" == "" ]; then
            # By default use default configuration
            user_config_mobile_id="$config_mobile_id"
        fi

        if (echo $user_config_mobile_id | grep -i y) >> /dev/stderr; then
            config_mobile_id=y
        else
            config_mobile_id=n
        fi

        if [ "$config_mobile_id" == "y" ]; then
            mobile_id_url="https://mid.sk.ee/mid-api"
            mobile_id_polling_timeout=60
            while [ "$mobile_id_relying_party_uuid" == "" ]; do
                echo "Please provide your Mobile-ID relying party UUID" >> /dev/stderr
                echo -n " (format: 00000000-0000-0000-0000-000000000000): " >> /dev/stderr
                [ -z "$PS1" ] || read mobile_id_relying_party_uuid < /dev/tty
                if [ "$mobile_id_relying_party_uuid" == "" ]; then
                    echo "WARNING! UUID cannot be empty. Please try again." >> /dev/stderr
                fi
            done

            while [ "$mobile_id_relying_party_name" == "" ]; do
                echo -n "Please provide your Mobile-ID relying party name: " >> /dev/stderr
                read mobile_id_relying_party_name < /dev/tty
                if [ "$mobile_id_relying_party_name" == "" ]; then
                    echo "WARNING! Name cannot be empty. Please try again." >> /dev/stderr
                fi
            done

            # import Apache2 certs to trust store in MISP2 deployment directory

            add_trusted_apache_certs_to_jks_store "${mobile_id_truststore_path}"

        fi
    fi

    ### configure mail servers
    ##
    echo -n "Please provide SMTP host address [default: $email_host]: " >> /dev/stderr
    [ -z "$PS1" ] || readuser_email_host < /dev/tty
    if [ "$user_email_host" == "" ]; then
        user_email_host=$email_host
    fi
    email_host=$user_email_host

    ### sender address
    echo -n "Please provide server email address: [default: $email_sender]: " >> /dev/stderr
    [ -z "$PS1" ] || read -r user_email_sender < /dev/tty
    if [ "$user_email_sender" == "" ]; then
        user_email_sender=$email_sender
    fi
    email_sender=$user_email_sender
    email_sender=$(echo $email_sender | sed 's/\@/\\@/g') >> /dev/stderr

    # Prompt for user input if configure_international=y and international_xroad_instances variable is set
    if [ "$configure_international" == "y" ] && [ -n "${international_xroad_instances+x}" ]; then
        xroad_instances=$international_xroad_instances
        echo -n "Please provide X-Road v6 instances (comma separated list)? [default: $xroad_instances] " >> /dev/stderr
        [ -z "$PS1" ] || read user_xroad_instances < /dev/tty
        if [ "$user_xroad_instances" != "" ]; then
            xroad_instances=$user_xroad_instances
        fi
    fi

    # Prompt for user input if configure_international=y and international_member_classes variable is set
    if [ "$configure_international" == "y" ] && [ -n "${international_member_classes+x}" ]; then
        xroad_member_classes=$international_member_classes
        echo -n "Please provide X-Road v6 member classes (comma separated list)? [default: $xroad_member_classes] " >> /dev/stderr
        [ -z "$PS1" ] || read user_xroad_member_classes < /dev/tty
        if [ "$user_xroad_member_classes" != "" ]; then
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

    if [ "$config_mobile_id" == "y" ]; then
        replace_conf_prop "auth.mobileID" "true"
        if [ "$mobile_id_relying_party_uuid" != "" ]; then
            replace_conf_prop "mobileID.rest.hostUrl" "$mobile_id_url"
            replace_conf_prop "mobileID.rest.relyingPartyUUID" "$mobile_id_relying_party_uuid"
            replace_conf_prop "mobileID.rest.relyingPartyName" "$mobile_id_relying_party_name"
            replace_conf_prop "mobileID.rest.pollingTimeoutSeconds" "$mobile_id_polling_timeout"
            replace_conf_prop "mobileID.rest.trustStore.password" "$username_pass"
            replace_conf_prop "mobileID.rest.trustStore.path" "$mobile_id_truststore_path"
        fi

    fi
    sed -i s/\\r//g $xrd_prefix/app/config.orig.cfg

    ### META-INF/context.xml config
    perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/context.orig.xml
    perl -pi -e "s/APP_NAME/$app_name/g" $xrd_prefix/app/admintool.sh

    wait_for_misp2_deployment

    echo "Copying configuration files..." >> /dev/stderr
    cp $xrd_prefix/app/config.orig.cfg $misp2_tomcat_resources/config.cfg
    exit1=$?
    cp $xrd_prefix/app/context.orig.xml $tomcat_home/webapps/$app_name/META-INF/context.xml
    exit2=$?
    echo "Copying certificates if they exist..." >> /dev/stderr
    if [ -f $apache2/ssl/MISP2_CA_cert.pem ]; then
        cp $apache2/ssl/MISP2_CA_cert.pem $misp2_tomcat_resources/certs/MISP2_CA_cert.pem
        echo "Copying certificates 1" >> /dev/stderr
    fi
    if [ -f $apache2/ssl/MISP2_CA_key.pem ]; then
        cp $apache2/ssl/MISP2_CA_key.pem $misp2_tomcat_resources/certs/MISP2_CA_key.pem
    fi
    if [ -f $apache2/ssl/MISP2_CA_key.der ]; then
        cp $apache2/ssl/MISP2_CA_key.der $misp2_tomcat_resources/certs/MISP2_CA_key.der
    fi
    if [ $exit1 -ne 0 -o $exit2 -ne 0 ]; then
        echo "Cannot copy files. Maybe they haven't yet been deployed by Tomcat. Please make sure that Tomcat is running and rerun the installation. Exit codes: $exit1 $exit2 $exit3" >> /dev/stderr
        exit 1
    else
        echo "Configuration files created" >> /dev/stderr
    fi
fi

#Remove cached jsp-s, because for some reason Tomcat does not recompile jsp-s currently. After this deletion however, tomcat will compile jsp-s
rm -f -r /var/cache/tomcat8/Catalina/localhost/$app_name/org/apache/jsp

echo "Restarting Tomcat..." >> /dev/stderr
/usr/sbin/invoke-rc.d tomcat8 restart

{
    echo "Successfully installed application $app_name"
    echo "You can change the configuration of application later by editing this file: "
    echo "$misp2_tomcat_resources/config.cfg"
    echo ""
    echo "To get admin access to MISP2 you need to run"
    echo "   - $xrd_prefix/admintool.sh  to create the admin user(s) and"
    echo "   - $xrd_prefix/configure_admin_interface_ip.sh to enable access from hosts you need"
    echo ""
    echo "To enable HTTPS connection between MISP2 application and security server"
    echo "you can do it later with $xrd_prefix/create_https_certs_security_server.sh"
} >> /dev/stderr

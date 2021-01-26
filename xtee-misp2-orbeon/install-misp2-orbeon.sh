#!/bin/bash
#
# MISP2 application XForms engine (Orbeon) installation
#
# Copyright(c) 2020- NIIS <info@niis.org>
# Copyright(c) Aktors 2016


xrd_prefix=/usr/xtee
tomcat_home=/var/lib/tomcat8
# If set to "true", Orbeon conf files properties-local.xml and log4j.xml are preserved after new webapp deployment
# This can be used when there are no configuration changes within new Orbeon package.
preserve_configuration=false

#####################
# Declare functions #
#####################
##
# @return success code (0) if Orbeon deployment directory with conf files exist
#         failure code (1) if Orbeon deployment directory or conf files do not exist
##
function orbeon_deployed {
	deploy_dir=$tomcat_home/webapps/orbeon
	config_dir=$deploy_dir/WEB-INF/resources/config

	# Check whether webapp files exist that indicate deployment in Tomcat
	if	[[ -d $config_dir 				]]  &&
		[[ -f $config_dir/properties-local.xml		]]  &&
		[[ -f $config_dir/theme-orbeon-embedded.xsl	]]  &&
		[[ -f $config_dir/log4j.xml			]]
	then
		# Webapp has been deployed
		return 0
	else
		# If not all deployment directory files exist, webapp has not yet deployed
		return 1
	fi
}

##
# Wait until Orbeon webapp has been deployed and echo out waiting status
##
function wait_for_orbeon_deployment {
	start_time=$SECONDS
	time_spent=""
	while	! orbeon_deployed
	do
		time_spent=$(($SECONDS - $start_time))
		echo -ne "...Waiting for Orbeon webapp deployment... ($time_spent s)"\\r
		sleep 0.5
	done
	sleep 1
	# Add another newline if previous entry was a line update
	[ "$time_spent" != "" ] && echo
	echo "...Orbeon webapp deployment done..."
}

##
# @return success code (0) if Orbeon deployment directory and WAR does not exist
#         failure code (1) if Orbeon deployment directory or WAR exists
##
function orbeon_undeployed {
	deploy_dir=$tomcat_home/webapps/orbeon
	war_full_path=$deploy_dir.war
	# Check whether webapp Tomcat deployment directory or the corresponding WAR file exist
	if	[[ -d $deploy_dir    ]] ||
		[[ -f $war_full_path ]]
	then
		# WAR or deployment directory still exists, webapp has not yet been undeployed
		return 1
	else
		# Neither WAR nor deployment directory exist, webapp has totally undeployed
		return 0
	fi
}

##
# Wait until Orbeon webapp has been undeployed and echo out waiting status
##
function wait_for_orbeon_undeployment {
	start_time=$SECONDS
	time_spent=""
	while	! orbeon_undeployed
	do
		time_spent=$(($SECONDS - $start_time))
		echo -ne "...Waiting for Orbeon webapp undeployment... ($time_spent s)"\\r
		sleep 0.5
	done
	sleep 1
	# Add another newline if previous entry was a line update
	[ "$time_spent" != "" ] && echo
	echo "...Orbeon webapp undeployment done..."
}

#####################################
# Begin Orbeon package installation #
#####################################
# Check if Tomcat server is running. If it's not, attempt to start.
status_adverb=
while ! /etc/init.d/tomcat8 status > /dev/null # do not show output, too verbose
do
	echo "Tomcat7 service is not running, attempting to start it."
	/etc/init.d/tomcat8 start
	status_adverb=" now"
	sleep 1
done
echo "Tomcat7 service is$status_adverb running."

if [ ! -d $tomcat_home/webapps ]
then
	echo -n "Please provide Apache Tomcat client working directory [$tomcat_home]? "
	read user_tomcat < /dev/tty
	if [ "$user_tomcat" == "" ]
	then
		user_tomcat=$tomcat_home
	fi
	tomcat_home=$user_tomcat
fi


if [ ! -d $tomcat_home/webapps ]
then
	echo "$tomcat_home/webapps is not found"
	exit 1
fi

# Back up configuration, if orbeon has been deployed
if orbeon_deployed
then
	echo " === Backing up configuration === "
	cp $tomcat_home/webapps/orbeon/WEB-INF/resources/config/properties-local.xml /tmp/properties-local.xml.bkp
	cp $tomcat_home/webapps/orbeon/WEB-INF/resources/config/log4j.xml /tmp/log4j.xml.bkp
else
	# if webapp is not deployed, do not attempt to restore configuration after deploying new webapp
	preserve_configuration=false
fi

# Undeploy old war
echo " === Undeploying previous version of Orbeon web application === "
rm -rf $tomcat_home/webapps/orbeon*
wait_for_orbeon_undeployment

# Deploy new orbeon.war to webapps directory
echo " === Deploying new version of Orbeon web application === "
cp $xrd_prefix/orbeon/orbeon.war $tomcat_home/webapps/
wait_for_orbeon_deployment

# Restore version for certain package versions, we dont want to restore for Orbeon version upgrade
if [ "$preserve_configuration" == "true" ]
then
	echo " === Restoring configuration from backup === "
	cp /tmp/properties-local.xml.bkp $tomcat_home/webapps/orbeon/WEB-INF/resources/config/properties-local.xml
	cp /tmp/log4j.xml.bkp $tomcat_home/webapps/orbeon/WEB-INF/resources/config/log4j.xml
fi

# Restart Tomcat
if [ ! -f /etc/init.d/tomcat8 ]
then
        echo "Shutdown Tomcat..."
        $tomcat_home/bin/shutdown.sh
        echo "Tomcat starting up..."
        $tomcat_home/bin/startup.sh
else
        /etc/init.d/tomcat8 restart
fi

# Check if Orbeon has been successfully deployed
if orbeon_deployed
then
	echo "Orbeon application added successfully"
else
	echo "Orbeon application deployment failed! Check if Tomcat has deployed orbeon.war in /webapps directory"
fi



#!/bin/bash
#
# MISP2 application XForms engine (Orbeon) installation
#
# Copyright(c) 2020- NIIS <info@niis.org>
# Copyright(c) Aktors 2016

xrd_prefix=/usr/xtee
tomcat_home=/var/lib/tomcat8
orbeon_deploy_dir=$tomcat_home/webapps/orbeon
orbeon_config=$orbeon_deploy_dir/WEB-INF/resources/config
orbeon_config_backup_dir=$(mktemp --directory --tmpdir orbeon_bck.XXXXXX)

# If set to "true", Orbeon conf files properties-local.xml and log4j.xml are preserved after new webapp deployment
# This can be used when there are no configuration changes within new Orbeon package.
preserve_configuration=false

#####################
# Declare functions #
#####################

function clean_up() {
	rm -rf "${orbeon_config_backup_dir}"
}
trap clean_up EXIT
##
# @return success code (0) if Orbeon deployment directory with conf files exist
#         failure code (1) if Orbeon deployment directory or conf files do not exist
##
function orbeon_deployed {
	# Check whether webapp files exist that indicate deployment in Tomcat
	if	[[ -d $orbeon_config 				]]  &&
		[[ -f $orbeon_config/properties-local.xml		]]  &&
		[[ -f $orbeon_config/theme-orbeon-embedded.xsl	]]  &&
		[[ -f $orbeon_config/log4j.xml			]]
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
		time_spent=$((SECONDS - start_time))
		echo -ne "...Waiting for Orbeon webapp deployment... ($time_spent s)"\\r >> /dev/stderr
		sleep 0.5
	done
	sleep 1
	# Add another newline if previous entry was a line update
	[ "$time_spent" != "" ] && echo
	echo "...Orbeon webapp deployment done..." >> /dev/stderr
}

##
# @return success code (0) if Orbeon deployment directory and WAR does not exist
#         failure code (1) if Orbeon deployment directory or WAR exists
##
function orbeon_undeployed {
	war_full_path=$orbeon_deploy_dir.war
	# Check whether webapp Tomcat deployment directory or the corresponding WAR file exist
	if	[[ -d $orbeon_deploy_dir    ]] ||
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
		time_spent=$((SECONDS - start_time))
		echo -ne "...Waiting for Orbeon webapp undeployment... ($time_spent s)"\\r >> /dev/stderr
		sleep 0.5
	done
	sleep 1
	# Add another newline if previous entry was a line update
	[ "$time_spent" != "" ] && echo
	echo "...Orbeon webapp undeployment done..." >> /dev/stderr
}

function ensure_tomcat_is_running() {
	while ! /usr/sbin/invoke-rc.d tomcat8 status > /dev/null 2>&1; do
        /usr/sbin/invoke-rc.d tomcat8 start > /dev/null
        sleep 1
    done
}

function backup_orbeon_config {
	cp $orbeon_config/properties-local.xml "$orbeon_config_backup_dir"/
	cp $orbeon_config/log4j.xml "$orbeon_config_backup_dir"/
}

function restore_orbeon_config {
	cp "$orbeon_config_backup_dir"/properties-local.xml $orbeon_config/properties-local.xml
	cp "$orbeon_config_backup_dir"/log4j.xml $orbeon_config/log4j.xml
}
#####################################
# Begin Orbeon package installation #
#####################################

if [ ! -d $tomcat_home/webapps ]
then
	echo "$tomcat_home/webapps is not found" >> /dev/stderr
	exit 1
fi

ensure_tomcat_is_running

# Back up configuration, if orbeon has been deployed
if orbeon_deployed
then
	backup_orbeon_config
else
	preserve_configuration=false
fi

# Undeploy old war
rm -rf $tomcat_home/webapps/orbeon*
wait_for_orbeon_undeployment

# Deploy new orbeon.war to webapps directory
cp $xrd_prefix/orbeon/orbeon.war $tomcat_home/webapps/
wait_for_orbeon_deployment

if [ "$preserve_configuration" == "true" ]
then
	restore_orbeon_config
fi

/usr/sbin/invoke-rc.d tomcat8 restart       

# Check if Orbeon has been successfully deployed
if ! orbeon_deployed
then
	echo "Orbeon application deployment failed! Check if Tomcat has deployed orbeon.war in /webapps directory" >> /dev/stderr
	exit 1 
fi



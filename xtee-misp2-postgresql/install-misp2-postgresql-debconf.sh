#!/bin/bash
#
# MISP2 application PostgreSQL data structure installation and update
#
# Aktors 2020

# Source debconf library.
. /usr/share/debconf/confmodule

if [ -n "$DEBIAN_SCRIPT_DEBUG" ]; then set -v -x; DEBIAN_SCRIPT_TRACE=1; fi

${DEBIAN_SCRIPT_TRACE:+ echo "#42#DEBUG# RUNNING $0 $*" 1>&2 }

function debconf_value() {
	local db_key="$1"
	RET=''
	db_get "$db_key"
	echo "$RET"
}
xrd_prefix=/usr/xtee

workdir=/root/xteesrc
pgsql_default_port=5432
pgsql_default_dbname=misp2db
pgsql_dir=/usr/lib/postgresql/10/bin
pgsql_conf_dir=/etc/postgresql/10/main
current_version="2.6.3"


error_prefix="\e[1m\e[91mERROR!\e[0m"

# Make sure systemd on Xenial would not send output to 'less' and pause execution when
# 'service x status' is called.
export SYSTEMD_PAGER=""

# Load functions
source /usr/xtee/db/install/install-misp2-postgresql-functions.sh
version=$(dpkg-query  -W -f '${Version}' "xtee-misp2-postgresql")
# remove CI build portion of the version. Schema should change only with actual N.M.K - version changes
if ( echo $version | grep -q 'git' )
then
	echo "Schema version extracted from the build version: $version "
	version=$(echo $version | sed -E 's/([0-9\.]*)([0-9]{14})git[a-z0-9]*/\1/' )
fi
echo "You have package shema version " $version; >> /dev/stderr
mkdir -p $workdir

cd $xrd_prefix/db/sql
#echo
if [ ! -f $pgsql_dir/psql ] ;
then
	echo "$pgsql_dir/psql is not found" >> /dev/stderr
	echo "Install and run PostgreSQL 10" >> /dev/stderr
	echo
	exit 1
fi

# Check if PostgreSQL server is running. If it's not, attempt to start.
status_adverb=
# TODO: prevent endless looping if status cmd gets broken
while ! /etc/init.d/postgresql status > /dev/null # do not show output, too verbose
do
	echo "PostgreSQL service is not running, attempting to start it." >> /dev/stderr
	/etc/init.d/postgresql start
	status_adverb=" now"
	sleep 1
done
echo  "PostgreSQL service is$status_adverb running." >> /dev/stderr

webapp_pgport=$( debconf_value xtee-misp2-postgresql/webapp_pgport )
webapp_dbname=$( debconf_value xtee-misp2-postgresql/webapp_dbname )
webapp_jdbc_username=$( debconf_value xtee-misp2-postgresql/webapp_jdbc_username )
confirm_db_creation=$( debconf_value xtee-misp2-postgresql/confirm_db_creation )
webapp_conf=$( debconf_value xtee-misp2-postgresql/webapp_conf )
webapp_jdbc_password=$( debconf_value xtee-misp2-postgresql/webapp_jdbc_password)

# defaulting to values from debconf
dbname="$webapp_dbname"
username="$webapp_jdbc_username"
### schema name is the same as username
schema_name="$username"

db_exists=false

# we assume Postgresql-10 has been installed and running already according to Depends - control
user_databases_found=$(get_existing_dbs $webapp_pgport  |
            xargs
        )

pgport="$webapp_pgport"

psql_pgport=$(perl -nle 'print $1 if m{^\s*port\s*=\s*([0-9]+)}' $pgsql_conf_dir/postgresql.conf)

if [ "$user_databases_found"  == "" ] && [ "$psql_pgport" != "$webapp_pgport" ]
then 
	if is_migration_possible
	then
		echo "DB migration might be performed." >> /dev/stderr
		# Variables filled in function 'is_migration_possible'
		pgport="$pg_port_old"
		user_databases_found="$existing_dbs_old"
		old_db=true
	else # else use DB port and DB names from new cluster (normal case)
		echo "DB migration will not be performed." >> /dev/stderr
		user_databases_found=$(get_existing_dbs $psql_pgport  |
            xargs
        )
		if [ "$user_databases_found" != "" ]
		then 
			pgport=$psql_pgport
			echo "PostgreSQL server port $pgport is used." >> /dev/stderr
		fi
	fi
else
	webapp_conf_used=true
	echo "Using DB connection parameters from configuration file $webapp_conf." >> /dev/stderr
fi


if ( echo "$user_databases_found" | tr " " "\n" | grep -wq "$webapp_dbname")
then

	# MISP2 DB is set up so that DB username is always the same as schema name.
	# check that this is the case in the db we have encountered.
	# TODO: present list of existing user-defined databases for user to select...

	schema_exists=$(
		$pgsql_dir/psql -p $pgport -U postgres -c "\dn" -t $dbname  2>/dev/null \
			| grep -o  $username 		
	)
	
	user_exists=$(
		$pgsql_dir/psql -p $pgport -U postgres -c "\dg" -t $dbname  2>/dev/null \
		    | grep -o $username 			
	)

	if [ "$schema_exists" == "" ] || [ "$schema_exists" != "$user_exists" ] 	
	then
		echo "Did not find user/schema $webapp_jdbc_username for the provided DB: $dbname @ localhost:$pgport" >> /dev/stderr
		echo "This is db for something else or failed previous misp2 install - retry install with another db name " >>  /dev/stderr
		exit 1 
	else
		echo "Username '$user_exists' found for DB '$dbname'." >>  /dev/stderr
		username="$webapp_jdbc_username"
		db_exists=true
	fi
	
fi
if [ "$db_exists" == "true" ]
then
	echo -e "Connection parameters to existing DB: pgport=$pgport, dbname=$dbname, username=$username \n" >> /dev/stderr
	
fi

### migrate DB from PostgreSQL v 9.3 to 9.5 if necessary
# function defined in install-misp2-postgresql-functions.sh
#  TODO: if 9.3 -> 9.5 still needs to be supported

migrate_db_if_needed

# Configure postgres user to be locally trusted
if [ -f $pgsql_conf_dir/pg_hba.conf ]
then
	# By default, 'postgres' user has peer access.
	# Change it to 'trust' and restart postgresql.
	if grep -Eq "\s*local\s+all\s+postgres\s+peer\s*" $pgsql_conf_dir/pg_hba.conf
	then
		echo  "Allowing 'postgres' user locally trusted access." >> /dev/stderr
		# Assume 'local all postgres ...' line exists in conf:
		# replace that with 'local all postgres trust'
		perl -pi -e "s/(\s*local\s+all\s+postgres\s+).*/\1trust/g" \
			$pgsql_conf_dir/pg_hba.conf
		service postgresql restart
	fi
else
	echo "$pgsql_conf_dir/pg_hba.conf configuration file is not found."\
	     "Cannot check for postgres user privileges." >> /dev/stderr
fi

### adding database
if [ "$db_exists" != "true" ]
then
	if (echo $confirm_db_creation | grep -i true) ;
	then
		echo  "Creating database '$dbname'" >> /dev/stderr
	else
		echo "Did not create new database nor updated existing one. Run installation again with correct DB name." >> /dev/stderr
		exit 1;
	fi

	$pgsql_dir/createdb -p $pgport $dbname -U postgres -T template0 -E UNICODE
	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo "Cannot create database '$dbname'" >> /dev/stderr
		echo "You can try to create \"$dbname\" by yourself: " >> /dev/stderr
		echo "$pgsql_dir/createdb  -p $pgport $dbname -U postgres -E UNICODE" >> /dev/stderr
		exit 1
	fi

	### adding username
	existing_users=$(
		$pgsql_dir/psql -p $pgport -U postgres \
			-c "select rolname from pg_roles" -t | xargs
	)

	if ! (echo "$existing_users" | tr " " "\n" | grep -wq "$username")
	then
		#echo  "Adding new user '$username'"
		$pgsql_dir/createuser  -p $pgport -U postgres -P -A -D $username
		if [ ! "$PIPESTATUS" = "0" ];
		then
			echo "Cannot add new user '$username'" >> /dev/stderr
			echo  "If user does not exist in the database then create him by running: " >> /dev/stderr
			echo  "$pgsql_dir/createuser -p $pgport -U postgres -P -A -D $username" >> /dev/stderr
			exit 1 
		fi
	fi

	#echo  "Updating database structure"
	sed "s/<misp2_schema>/$schema_name/g" create_misp2_db.sql > $workdir/tmp.create_misp2_db.sql
	$pgsql_dir/psql  -p $pgport $dbname -U postgres -f $workdir/tmp.create_misp2_db.sql
	$pgsql_dir/psql  -p $pgport $dbname -U postgres -c "grant all on schema $schema_name to $username;"
	sed "s/misp2/$schema_name/g" grant_misp2_db.sql > $workdir/tmp.grant_misp2_db.sql
	$pgsql_dir/psql  -p $pgport $dbname -U postgres -f $workdir/tmp.grant_misp2_db.sql

	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo "Cannot create database structure" >> /dev/stderr
		exit 1
	fi

	# default classifiers upload
	echo  "Loading classifiers..." >> /dev/stderr
	sed "s/misp2/$schema_name/g" classifier_dump.sql > $workdir/tmp.classifier_dump.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.classifier_dump.sql -q
	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo  "Cannot load classifiers" >> /dev/stderr
		exit 1
	fi

	###  default xsl upload
	echo "Loading stylesheets..." >> /dev/stderr
	sed "s/misp2/$schema_name/g" insert_xslt.sql > $workdir/tmp.insert_xslt.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.insert_xslt.sql -q
	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo "Cannot load stylesheets" >> /dev/stderr
		exit 1
	fi
	echo  "Finished creating new database structure" >> /dev/stderr

### database already exists ###
else
	echo  "Upgrading '$dbname' on port $pgport." >> /dev/stderr
	rm -f $workdir/tmp.alter*
	sed "s/misp2\./$schema_name\./g" alter_table_1.0.50.sql  > $workdir/tmp.alter_1.0.50.sql
	sed "s/misp2\./$schema_name\./g" alter_table_1.0.51.sql  > $workdir/tmp.alter_1.0.51.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.0.sql  > $workdir/tmp.alter_2.1.0.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.1.sql  > $workdir/tmp.alter_2.1.1.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.2.sql  > $workdir/tmp.alter_2.1.2.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.3.sql  > $workdir/tmp.alter_2.1.3.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.4.sql  > $workdir/tmp.alter_2.1.4.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.7.sql  > $workdir/tmp.alter_2.1.7.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.11.sql  > $workdir/tmp.alter_2.1.11.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.12.sql  > $workdir/tmp.alter_2.1.12.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.1.13.sql  > $workdir/tmp.alter_2.1.13.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.2.1.sql  > $workdir/tmp.alter_2.2.1.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.2.2.sql  > $workdir/tmp.alter_2.2.2.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.2.3.sql  > $workdir/tmp.alter_2.2.3.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.2.4.sql  > $workdir/tmp.alter_2.2.4.sql
	sed "s/misp2\./$schema_name\./g" alter_table_2.2.5.sql  > $workdir/tmp.alter_2.2.5.sql

	touch $workdir/tmp.alter.sql

	if [ "$version" = "$current_version" ]
	then
		echo  "You have latest database version" >> /dev/stderr
		version=1
	elif (echo "$version" | grep -Eq "^1[.]")
	then
		echo -e "$error_prefix Existing version $version is too old to upgrade to"\
			"the latest version $current_version directly." >> /dev/stderr
		exit 1
	fi

	if [ "$version" == "2.0.0" ]
	then
		cat $workdir/tmp.alter_1.0.50.sql >> $workdir/tmp.alter.sql
		cat $workdir/tmp.alter_1.0.51.sql >> $workdir/tmp.alter.sql
		version="2.0.1"
	fi

	if [ "$version" == "2.0.1" ]
	then
		cat $workdir/tmp.alter_2.1.0.sql >> $workdir/tmp.alter.sql
		version="2.1.0"
	fi

	if [ "$version" == "2.1.0" ]
	then
		cat $workdir/tmp.alter_2.1.1.sql >> $workdir/tmp.alter.sql
		version="2.1.1"
	fi

	if [ "$version" == "2.1.1" ]
	then
		cat $workdir/tmp.alter_2.1.2.sql >> $workdir/tmp.alter.sql
		version="2.1.2"
	fi

	if [ "$version" == "2.1.2" ]
	then
		cat $workdir/tmp.alter_2.1.3.sql >> $workdir/tmp.alter.sql
		version="2.1.3"
	fi

	if [ "$version" == "2.1.3" ]
	then
		cat $workdir/tmp.alter_2.1.4.sql >> $workdir/tmp.alter.sql
		version="2.1.4"
	fi

	if [ "$version" == "2.1.4" -o "$version" == "2.1.5" -o "$version" == "2.1.6"  ]
	then
		cat $workdir/tmp.alter_2.1.7.sql >> $workdir/tmp.alter.sql
		version="2.1.7"
	fi

	if [ "$version" == "2.1.7" -o "$version" == "2.1.8" -o "$version" == "2.1.9" -o "$version" == "2.1.10" ]
	then
		cat $workdir/tmp.alter_2.1.11.sql >> $workdir/tmp.alter.sql
		version="2.1.11"
	fi

	if [ "$version" == "2.1.11" ]
	then
		cat $workdir/tmp.alter_2.1.12.sql >> $workdir/tmp.alter.sql
		version="2.1.12"
	fi

	if [ "$version" == "2.1.12" ]
	then
		cat $workdir/tmp.alter_2.1.13.sql >> $workdir/tmp.alter.sql
		version="2.1.13"
	fi

	if [ "$version" == "2.1.13" -o "$version" == "2.1.14" ]
    	then
    		cat $workdir/tmp.alter_2.2.1.sql >> $workdir/tmp.alter.sql
    		version="2.2.1"
    fi

    if [ "$version" == "2.2.1" ]
    	then
    		cat $workdir/tmp.alter_2.2.2.sql >> $workdir/tmp.alter.sql
    		version="2.2.2"
    fi

    if [ "$version" == "2.2.2" ]
    	then
    		cat $workdir/tmp.alter_2.2.3.sql >> $workdir/tmp.alter.sql
    		version="2.2.3"
    fi
    
    if [ "$version" == "2.2.3" ]
    	then
    		cat $workdir/tmp.alter_2.2.4.sql >> $workdir/tmp.alter.sql
    		version="2.2.4"
    fi
    
    if [ "$version" == "2.2.4" ]
    	then
    		cat $workdir/tmp.alter_2.2.5.sql >> $workdir/tmp.alter.sql
    		version="2.2.5"
    fi

	if [ "$version" == "2.2.5" ]
    	then
    		version="2.5.0"
    fi

	if [ "$version" == "2.5.0" ]
    	then
    		version="2.6.0"
    fi
	if [ "$version" == "2.6.0" ]
    	then
    		version="2.6.1"
    fi
	if [ "$version" == "2.6.1" ]
    	then
    		version="2.6.2"
    fi
	if [ "$version" == "2.6.2" ]
    	then
    		version="2.6.3"
    fi

	# Substitute schema name in alter scripts
	perl -pi -e "s/<misp2_schema>/$schema_name/g" $workdir/tmp.alter.sql
	
	if [ "$version" != "1" ]
        then
		if [ "$version" != "$current_version" ]
		then
			echo -e "$error_prefix DB update failed! New version is $current_version,"\
				"but updated only to $version." >> /dev/stderr
			exit 1
		fi
	        #echo  ""
		echo  "Updating database structure... " >> /dev/stderr
		# -v ON_ERROR_STOP=1 makes the script fail on error so it would not continue when error is thrown
		# --single-transaction avoids inconsistent state on failure: either everything succeeds or nothing does
		$pgsql_dir/psql --single-transaction -v ON_ERROR_STOP=1 -p $pgport $dbname -U postgres -f $workdir/tmp.alter.sql
		if [ ! "$PIPESTATUS" = "0" ];
		then
			echo "Failed updating structure. You can run the alter script by yourself running this line: psql -p $pgport $dbname -U postgres -f $workdir/tmp.alter.sql" >> /dev/stderr
			exit 1
		fi
        fi
	echo  "Updating classifiers with user 'postgres'..." >> /dev/stderr
	sed "s/misp2/$schema_name/g" classifier_dump.sql > $workdir/tmp.classifier_dump.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.classifier_dump.sql -q
	if [ "$PIPESTATUS" != "0" ];
	then
		echo "Failed updating system classifiers" >> /dev/stderr
		exit 1
	fi
	echo "Updating stylesheets with user 'postgres'..." >> /dev/stderr
	sed "s/misp2/$schema_name/g" insert_xslt.sql > $workdir/tmp.insert_xslt.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.insert_xslt.sql -q
	if [ "$PIPESTATUS" != "0" ];
	then
		echo "Failed updating system XSL stylesheets" >> /dev/stderr
		exit 1
	fi

	echo "Finished updating database structure" >> /dev/stderr
fi
#echo "";


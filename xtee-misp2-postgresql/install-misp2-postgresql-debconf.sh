#!/bin/bash
#
# MISP2 application PostgreSQL data structure installation and update
#
# Aktors 2020

# Source debconf library.
. /usr/share/debconf/confmodule

xrd_prefix=/usr/xtee

workdir=/root/xteesrc
pgsql_default_port=5432
pgsql_default_dbname=misp2db
pgsql_dir=/usr/lib/postgresql/10/bin
pgsql_conf_dir=/etc/postgresql/10/main
current_version="2.2.5"


error_prefix="\e[1m\e[91mERROR!\e[0m"

# Make sure systemd on Xenial would not send output to 'less' and pause execution when
# 'service x status' is called.
export SYSTEMD_PAGER=""

# Load functions
source /usr/xtee/db/install/install-misp2-postgresql-functions.sh

version=$(dpkg-query  -W -f '${Version}' "xtee-misp2-postgresql")
echo "You have package version " $version;
mkdir -p $workdir

cd $xrd_prefix/db/sql
echo
if [ ! -f $pgsql_dir/psql ] ;
then
	echo "$pgsql_dir/psql is not found"
	echo "Install and run PostgreSQL 10"
	echo
	exit 1
fi

# Check if PostgreSQL server is running. If it's not, attempt to start.
status_adverb=
# TODO: prevent endless looping if status cmd gets broken
while ! /etc/init.d/postgresql status > /dev/null # do not show output, too verbose
do
	echo "PostgreSQL service is not running, attempting to start it."
	/etc/init.d/postgresql start
	status_adverb=" now"
	sleep 1
done
echo "PostgreSQL service is$status_adverb running."
RET=''
db_get xtee-misp2-postgresql/webapp_pgport
webapp_pgport="$RET"

RET=''
db_get xtee-misp2-postgresql/webapp_dbname
webapp_dbname="$RET"

RET=''
db_get xtee-misp2-postgresql/webapp_jdbc_username
webapp_jdbc_username="$RET"

RET=''
db_get xtee-misp2-postgresql/confirm_db_creation
confirm_db_creation="$RET"

# defaulting to values from debconf
pgport="$webapp_pgport"
dbname="$webapp_dbname"
username="$webapp_jdbc_username"
### schema name is the same as username
schema_name="$username"

db_exists=false

has_db_connection=$(
            $pgsql_dir/psql -p "$webapp_pgport" -U postgres -lqt 2> /dev/null |
            perl -nle 'print $1 if m{([^\|]+)}' |
            grep -w "$webapp_dbname" |
            xargs
        )

pgport=$(perl -nle 'print $1 if m{^\s*port\s*=\s*([0-9]+)}' $pgsql_conf_dir/postgresql.conf)


if [ "$has_db_connection" == "" ]
then
	### port
	#  use DB port and DB names from new cluster
  	pgport=$(perl -nle 'print $1 if m{^\s*port\s*=\s*([0-9]+)}' $pgsql_conf_dir/postgresql.conf)

	existing_dbs=$(get_existing_dbs $pgport)
	echo "Got existing dbs:$existing_dbs"

	# if port was not found from file, display a error and exit
	if [ "$pgport" == "" ];
	then
		echo -e "$error_prefix PostgreSQL port was not found from config file '$pgsql_conf_dir/postgresql.conf'."
		exit 1
	fi
	echo "PostgreSQL server port $pgport is used."

	### database
	# If we have exactly one DB name and that is the default DB name, use that.
	# Otherwise use given webapp db if  exists in the given posgtress instance OR fail.
	if ( echo "$existing_dbs" | tr " " "\n" | grep -wq "$webapp_dbname")
	then
		db_exists=true
		# try to extract username/schema name from existing database
		# get list of database schema names that are not public or maintainance

		existing_schemas=$(
			$pgsql_dir/psql -p $pgport -U postgres \
				-c "select schema_name from
					information_schema.schemata where
						schema_name not like 'pg_%' and
						schema_name not in
							('information_schema', 'public')" -t $dbname \
				2>/dev/null | xargs
		)
		# get list of added role names (anything but 'postgres')
		existing_users=$(
			$pgsql_dir/psql -p $pgport -U postgres \
				-c "select rolname from pg_roles where
					rolname != 'postgres'" -t | xargs
		)

		if !(echo "$users_same_as_schema" | grep -q "$webapp_jdbc_username") 	
		then
			echo "Did not find user/schema $webapp_jdbc_username "
			echo "tried: DB: $dbname @ localhost:$pgport"
			exit 1 
		else
			echo "Username '$users_same_as_schema' found for DB '$dbname'."
			username="$webapp_jdbc_username"
		fi
	else # DB does not yet exist
		db_exists=false
	fi

	
else # DB access parameters were successfully extracted from webapp config
	webapp_conf_used=true
	echo "Using DB connection parameters from configuration file $webapp_conf."
fi
if [ "$db_exists" == "true" ]
then
	echo "Connection parameters to existing DB:"
	echo "  pgport=$pgport"
	echo "  dbname=$dbname"
	echo "  username=$username"
	echo ""
fi

### migrate DB from PostgreSQL v 9.3 to 9.5 if necessary
# function defined in install-misp2-postgresql-functions.sh
#  TODO: if 9.3 -> 9.5 still needs to be supported
# migrate_db_if_needed

# Configure postgres user to be locally trusted
if [ -f $pgsql_conf_dir/pg_hba.conf ]
then
	# By default, 'postgres' user has peer access.
	# Change it to 'trust' and restart postgresql.
	if grep -Eq "\s*local\s+all\s+postgres\s+peer\s*" $pgsql_conf_dir/pg_hba.conf
	then
		echo "Allowing 'postgres' user locally trusted access."
		# Assume 'local all postgres ...' line exists in conf:
		# replace that with 'local all postgres trust'
		perl -pi -e "s/(\s*local\s+all\s+postgres\s+).*/\1trust/g" \
			$pgsql_conf_dir/pg_hba.conf
		service postgresql restart
	fi
else
	echo "$pgsql_conf_dir/pg_hba.conf configuration file is not found."\
	     "Cannot check for postgres user privileges."
fi

### adding database
if [ "$db_exists" != "true" ]
then
	if (echo $confirm_db_creation | grep -i true) ;
	then
		echo "Creating database '$dbname'"
	else
		echo "Did not create new database nor updated existing one. Run installation again with correct DB name."
		exit 1;
	fi

	$pgsql_dir/createdb -p $pgport $dbname -U postgres -T template0 -E UNICODE
	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo "Cannot create database '$dbname'"
		echo "You can try to create \"$dbname\" by yourself: "
		echo "$pgsql_dir/createdb  -p $pgport $dbname -U postgres -E UNICODE"
		exit 1
	fi

	### adding username
	existing_users=$(
		$pgsql_dir/psql -p $pgport -U postgres \
			-c "select rolname from pg_roles" -t | xargs
	)

	if ! (echo "$existing_users" | tr " " "\n" | grep -wq "$username")
	then
		echo "Adding new user '$username'"
		$pgsql_dir/createuser  -p $pgport -U postgres -P -A -D $username
		if [ ! "$PIPESTATUS" = "0" ];
		then
			echo "Cannot add new user '$username'"
			echo "If user does not exist in the database then create him by running: "
			echo "$pgsql_dir/createuser -p $pgport -U postgres -P -A -D $username"
			exit 1 
		fi
	fi

	echo "Updating database structure"
	sed "s/<misp2_schema>/$schema_name/g" create_misp2_db.sql > $workdir/tmp.create_misp2_db.sql
	$pgsql_dir/psql  -p $pgport $dbname -U postgres -f $workdir/tmp.create_misp2_db.sql
	$pgsql_dir/psql  -p $pgport $dbname -U postgres -c "grant all on schema $schema_name to $username;"
	sed "s/misp2/$schema_name/g" grant_misp2_db.sql > $workdir/tmp.grant_misp2_db.sql
	$pgsql_dir/psql  -p $pgport $dbname -U postgres -f $workdir/tmp.grant_misp2_db.sql

	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo "Cannot create database structure"
		exit 1
	else
	echo "Database structure is created"
	fi

	# default classifiers upload
	echo "Loading classifiers..."
	sed "s/misp2/$schema_name/g" classifier_dump.sql > $workdir/tmp.classifier_dump.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.classifier_dump.sql -q
	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo "Cannot load classifiers"
		exit 1
	fi

	###  default xsl upload
	echo "Loading stylesheets..."
	sed "s/misp2/$schema_name/g" insert_xslt.sql > $workdir/tmp.insert_xslt.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.insert_xslt.sql -q
	if [ ! "$PIPESTATUS" = "0" ];
	then
		echo "Cannot load stylesheets"
		exit 1
	fi
	echo "Finished creating new database structure"

### database already exists ###
else
	echo "Upgrading '$dbname' on port $pgport."
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
		echo "You have latest database version"
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
	        echo ""
		echo "Updating database structure... "
		# -v ON_ERROR_STOP=1 makes the script fail on error so it would not continue when error is thrown
		# --single-transaction avoids inconsistent state on failure: either everything succeeds or nothing does
		$pgsql_dir/psql --single-transaction -v ON_ERROR_STOP=1 -p $pgport $dbname -U postgres -f $workdir/tmp.alter.sql
		if [ ! "$PIPESTATUS" = "0" ];
		then
			echo "Failed updating structure. You can run the alter script by yourself running this line: psql -p $pgport $dbname -U postgres -f $workdir/tmp.alter.sql"
			exit 1
		fi
        fi
	echo "Updating classifiers with user 'postgres'..."
	sed "s/misp2/$schema_name/g" classifier_dump.sql > $workdir/tmp.classifier_dump.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.classifier_dump.sql -q
	if [ "$PIPESTATUS" != "0" ];
	then
		echo "Failed updating system classifiers"
		exit 1
	fi
	echo "Updating stylesheets with user 'postgres'..."
	sed "s/misp2/$schema_name/g" insert_xslt.sql > $workdir/tmp.insert_xslt.sql
	$pgsql_dir/psql -p $pgport $dbname -U postgres -f $workdir/tmp.insert_xslt.sql -q
	if [ "$PIPESTATUS" != "0" ];
	then
		echo "Failed updating system XSL stylesheets"
		exit 1
	fi

	echo "Finished updating database structure"
fi
echo "";


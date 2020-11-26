#!/bin/bash
##
# Echo list of items in human readable format, depending of number of items.
# @param item_name human readable name for a single list element
# @param items space-separated list of items
# @return list of items in human readable format.
#
# E.g. 
# $ echo_list "fruit" "banana orange melon"
# Found the following fruits: 'banana', 'orange' and 'melon'.
# $ echo_list "fruit" "banana"
# Found the following fruit: 'banana'.
##
function echo_list {
        local item_name="$1"
        local items="$2"
		local prefix_some="Found the following"
		local prefix_none="Did not find any"

        local item_name_plural="${item_name}s"
        local num_items=$(echo "$items" | wc -w)

        if [ $num_items == 0 ]
        then
                echo "$prefix_none $item_name_plural."
        elif [ $num_items == 1 ]
        then
                echo "$prefix_some $item_name: '$items'."
        else
                echo -n "$prefix_some $item_name_plural: "
                local i=0
                for item in $items
                do
                        echo -n "'$item'"
                        if [ $i == $((num_items - 2)) ]
                        then
                                echo -n " and "
                        elif  [ $i -lt $((num_items - 2)) ]
                        then
                                echo -n ", "
                        fi
                        local i=$((i+1))
                done
                echo "."
        fi
}

##
# Find space-separated list of databases and
# filter out the databases coming with default PostgreSQL install
# @param pgport PostgreSQL server port where database names are queried from
# @return print the space-separated list of databases to stdout
##
function get_existing_dbs {
	local pgport="$1"
	# get list of databases (sink error message)
	$pgsql_dir/psql -p $pgport -U postgres -lqt 2>/dev/null |
		# eliminate template databases, empty rows and maintainance database	
		cut -d \| -f 1 | grep -vE '^\s*(template.*|\s*|postgres)\s*$' | xargs
}

##
# Determine if DB migration is possible.
# It is considered possible when new DB cluster is empty and old DB cluster contains databases.
# Also initialize global variables describing old and new installation parameters 
# (like port numbers and DB lists).
# @return status code 0 if DB migration is needed, 1 if not
##
function is_migration_possible {
	if [ $(lsb_release --short --codename) == "xenial" ] # perform migration only for Ubuntu Xenial release
	then
		pg_ver_old=9.3
		pg_ver_new=9.5
		pg_conf_old=/etc/postgresql/$pg_ver_old/main
		pg_conf_new=/etc/postgresql/$pg_ver_new/main

		# check if PostgreSQL installations for both versions exist
		if  [ -f $pg_conf_old/postgresql.conf ] && 
	   		[ -f $pg_conf_new/postgresql.conf ]
	   	then
			# extract PostgreSQL server listening port numbers from config
			pg_port_line_old=$(grep -E "^port\s*=\s*" $pg_conf_old/postgresql.conf | cut --delimiter='#' -f 1)
			pg_port_line_new=$(grep -E "^port\s*=\s*" $pg_conf_new/postgresql.conf | cut --delimiter='#' -f 1)
			pg_port_old=$(echo $pg_port_line_old | cut --delimiter='=' -f 2 | xargs)
			pg_port_new=$(echo $pg_port_line_new | cut --delimiter='=' -f 2 | xargs)
			
			if [ "$pg_port_old" != "" ] && [ "$pg_port_new" != "" ]
			then
				existing_dbs_old=$(get_existing_dbs $pg_port_old)
				existing_dbs_new=$(get_existing_dbs $pg_port_new)
				echo_list "PostgreSQL $pg_ver_old (port $pg_port_old) database" "$existing_dbs_old"
				echo_list "PostgreSQL $pg_ver_new (port $pg_port_new) database" "$existing_dbs_new"
				# If databases exist in old installation, but none exists in new installation, allow migration
				if [ "$existing_dbs_old" != "" ] && [ "$existing_dbs_new" == "" ]
				then
					return 0
				fi
			fi
		fi
	fi
	return 1 # by default, migration is not needed
}

##
# @return status code 0 if DB migration will be performed for given $dbname, 
#		1 if migration should not be performed for that database
##
function is_migration_needed {
	# check if webapp database exists on old installation, but not on new
	if ( echo "$existing_dbs_old" | tr " " "\n" | grep -wq $dbname) &&
	   ! (echo "$existing_dbs_new" | tr " " "\n" | grep -wq $dbname)
	then
		return 0
	else
		return 1
	fi
}

##
# Migrate DB from PostgreSQL v 9.3 to 9.5 if necessary.
# DB migration code has been refactored to a separate function for main script code clarity.
#
# Current file only contains a function to be sourced and is not executable.
# The function is meant to be called from 'install-misp2-postgresql.sh' with
# its environment variables (
# 	$current_version
#	$dbname
#	$pgport
#	$dbschema
#	$username
#	$pgsql_dir
#	$webapp_conf
#	$webapp_conf_used
#	$webapp_jdbc_password
# ) initialized.
##
function migrate_db_if_needed {

	# Colors https://stackoverflow.com/a/20983251
	local RED=`tput setaf 1`
	local GREEN=`tput setaf 2`
	local NC=`tput sgr0`

	if is_migration_possible && is_migration_needed
	then
		# verify integrity of PostgreSQL DB
		# echo table row counts as string 
		function get_table_stats {
			local dbport=$1
			local dbname=$2
			local dbschema=$3
			local pgsql_dir=$4
			for table_name in $($pgsql_dir/psql -U postgres -d "$dbname" -p "$dbport" -t -c "SELECT table_name
			  FROM information_schema.tables WHERE table_schema='$dbschema' 
			  AND table_type='BASE TABLE' ORDER BY table_name;")
			do
				row_count=$($pgsql_dir/psql -U postgres -d "$dbname" -p "$dbport" -t -c "SELECT COUNT(*) 
					FROM $dbschema.$table_name;" | xargs)
				echo "  $table_name $row_count"
			done
		}

		function check_missing_tables {
			local table_names="admin classifier group_ group_item group_person"
			local table_names="$table_names org org_name org_person org_query" 
			local table_names="$table_names person portal portal_name"
			local table_names="$table_names producer producer_name query query_error_log query_log"
			local table_names="$table_names query_name query_topic topic topic_name xforms xslt"

			local expected_tables="$(echo $table_names | xargs | tr ' ' '\n' | sort | uniq)"
			# parse table names from get_table_stats output
			local actual_tables="$(get_table_stats "$pg_port_old" "$dbname" "$username" "$pgsql_dir" |
				perl -nle 'print $1 if m{^\s*([^\s]+)\s}' |
				xargs | tr ' ' '\n' | sort | uniq
			)"
			# exclude all actual tables (2) and intersection between actual and expected tables (3)
			local missing_tables="$(comm -23 <(echo "$expected_tables") <(echo "$actual_tables") | xargs)"

			if [ "$missing_tables" != "" ]
			then
				echo "WARNING! ${RED}Missing tables${NC} detected in DB '$dbname' (port $pg_port_old, schema '$username')."
				echo_list "missing table" "$missing_tables"
				echo
				echo -n "Do you want to continue with DB migration (y/n)? [n] "
				read continue_migration < /dev/tty
				if [ "$continue_migration" != "y" ] && [ "$continue_migration" != "Y" ]
				then
					echo "Exiting installation."
					exit 1
				fi
			fi

		}

		function swap_pg_ports {
			# swap old and new PostgreSQL installation port numbers in config and 
			# global variables and then restart servers
			perl -pi -e "s/$pg_port_line_old/$pg_port_line_new/g" $pg_conf_old/postgresql.conf
			perl -pi -e "s/$pg_port_line_new/$pg_port_line_old/g" $pg_conf_new/postgresql.conf
			# swap port lines		
			tmp_port_line=$pg_port_line_new
			pg_port_line_new=$pg_port_line_old
			pg_port_line_old=$tmp_port_line
			# swap old and new port varibles also		
			tmp_port=$pg_port_new
			pg_port_new=$pg_port_old
			pg_port_old=$tmp_port
			echo

			# restart postgresql
			echo "Restarting PostgreSQL server"
			service postgresql restart
		}

		check_missing_tables
		
		# Warn user if password is empty and have it replaced
		if [ "$webapp_conf_used" == "true" ] && [ "$webapp_jdbc_password" == "" ]
		then
			echo "WARNING! Empty user passwords do not work any more in PostgreSQL $pg_ver_new."

			# Get new password from user
			new_password=
			while [ "$new_password" == "" ]
			do
				# Note, backslash is interpreted as a quoting symbol, to insert backslash, user needs to input '\\'
				read -s -p "Please enter new password for database user '$username': " new_password
				echo
				if [ "$new_password" == "" ]
				then
					echo "Password cannot be empty."
				fi
			done

			# Replace PostgreSQL user password
			# replace single quotes with double quotes to avoid SQL injection (sed expr 1)
			echo "Altering DB user '$username' password."
			sql_replacement_password=$(echo "$new_password" | sed -e "s/'/''/g")
			$pgsql_dir/psql -p $pgport -U postgres -c "ALTER USER $username PASSWORD '$sql_replacement_password';"	

			# Replace password in Webapp conf
			# 1) replace '/' with '\/' to create regex replacement string where slashes are quoted (sed expr 1)
			# 2) also quote backslashes (sed expr 2 and 3), two passes are needed:
			#	2.1) perl replacement statement needs double quotes
			#	2.2) need to double each backslash when writing into webapp config file
			echo "Changing DB user password in webapp configuration."
			perl_replacement_password=$(echo "$new_password" | sed -e 's/\//\\\//g' -e 's/\\/\\\\/g' -e 's/\\/\\\\/g')	
			# [^\r#]* Means we only replace password until first carriage return or '#', this will preserve Windows line ending
			perl -pi -e "s/^\s*jdbc\.password\s*=[^\r\n#]*/jdbc.password=$perl_replacement_password/" $webapp_conf

			# Restart webapp if it is running
			if (service tomcat8 status | grep -q "Active: active (running)")
			then
				echo "Restarting webapp."
				service tomcat8 restart
			fi

			echo "Password successfully changed."
			echo
			echo "  You can later change the password with "
			echo "    psql -U postgres -c \"\\password $username\""
			echo "  You then also need to modify 'jdbc.password' parameter in webapp config file "
			echo "    $webapp_conf"
			echo "  and restart Tomcat."
			echo

		# Otherwise if webapp conf is unknown, show notification
		elif [ "$webapp_conf_used" != "true" ]
		then
			echo "Note: Empty user passwords do not work any more in PostgreSQL $pg_ver_new."
			echo
			echo "  You can change the password with "
			echo "    psql -U postgres -c \"\\password $username\""
			echo "  You then also need to modify 'jdbc.password' parameter in webapp config file and"
			echo "  restart Tomcat."
			echo
		fi

		echo "Performing PostgreSQL database migration from version $pg_ver_old to $pg_ver_new."

		echo "Copying $pg_conf_old/pg_hba.conf to $pg_conf_new/"
		cp $pg_conf_old/pg_hba.conf $pg_conf_new/

		# swap listening ports of old and new PostgreSQL installations so that 
		#  new installation is used instead of old
		echo "Configuring PostgreSQL version $pg_ver_new to run on port $pg_port_old "
		echo " (and version $pg_ver_old to run on port $pg_port_new)."
		# swap old and new ports in variables, configuration files and restart PostgreSQL server
		swap_pg_ports

		# testing shows new PostgreSQL installation won't start unless explicitly started
		service postgresql start

		function pg_migration_rollback {
			# Handle DB migration error: restore initial state
			echo "Database ${RED}migration failed${NC}. Cannot continue." >> /dev/stderr
			echo "Deleting migration target database." >> /dev/stderr

			# Delete new DB (is corrupt if exists)
			$pgsql_dir/psql -U postgres -p $pg_port_new -c "DROP DATABASE IF EXISTS $dbname;"

			# Switch back ports
			echo "Swapping PostgreSQL port numbers back to original configuration " >> /dev/stderr
			echo "(version $pg_ver_new will run on $pg_port_old and version $pg_ver_old on $pg_port_new)." >> /dev/stderr
			swap_pg_ports 			
		}

		# Dump old database to new PostgreSQL installation
		$pgsql_dir/pg_dumpall -U postgres -p $pg_port_old | $pgsql_dir/psql -U postgres -d postgres -p $pg_port_new
		exit_code="$#"
		if [ "$exit_code" != "0" ]
		then
			pg_migration_rollback
			exit $exit_code
		fi

		echo "Verifying migration"
		echo "Querying table row count statistics from original DB."
		pg_stats_old=$(get_table_stats "$pg_port_old" "$dbname" "$username" "$pgsql_dir")
		echo "Querying table row count statistics from migrated DB."
		pg_stats_new=$(get_table_stats "$pg_port_new" "$dbname" "$username" "$pgsql_dir")

		if [ "$pg_stats_old" == "$pg_stats_new" ] && [ "$pg_stats_old" != "" ]
		then # success
			echo "Table row counts match."
			echo "$pg_stats_old"
			echo "PostgreSQL $pg_ver_old (old) server now runs on port $pg_port_old."
			echo "PostgreSQL $pg_ver_new (new) server now runs on port $pg_port_new."
			echo
			echo "Database has been ${GREEN}successfully migrated${NC} to PostgreSQL version $pg_ver_new."
			echo "Old database installation can be removed with 'sudo apt-get purge postgresql-$pg_ver_old'."
		else # failure
			if [ "$pg_stats_old" != "" ]
			then
				echo "Table row counts from old DB installation" >> /dev/stderr
				echo "$pg_stats_old" >> /dev/stderr
				echo "Table row counts from new DB installation" >> /dev/stderr
				echo "$pg_stats_new" >> /dev/stderr
				echo "Database table row counts differ." >> /dev/stderr
			else
				echo "Reading table row counts from original database failed." >> /dev/stderr
			fi
		
			pg_migration_rollback
			exit 1
		fi
		echo
		pg_migrated=true
	fi
}

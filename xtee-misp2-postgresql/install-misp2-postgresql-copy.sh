#!/bin/sh

# Andmebaasisüsteemi andmete varundamine ja taastamine

# Cell Network 2005-2006

# kasuta kujul:
# install-postgresql-copy.sh [-backup|-restore|-restoreldap|-delete|-remove]


# xteeprefix=/usr/xtee
# pgsqlbin=/usr/local/pgsql/bin


# workdir=/root/xteesrc
# mkdir -p $workdir

# for param in $@
# do
	# case $param in
	# -backup )
		# andmete varundamine dump-failina
		# cmd=backup;;
	# -restore )
		# andmete taastamine dump-failist
		# cmd=restore;;
	# -restoreldap )
		# andmete laadimine OpenLDAPi LDIF-failist
		# cmd=restoreldap;;
	# -delete )
		# andmete kustutamine
		# cmd=delete;;
	# -remove )
		# andmebaasi kustutamine
		# cmd=remove;;
	# esac
# done


# if [ ! -f $pgsqlbin/psql ] 
# then
	# echo "PostgreSQL 8.x peab olema installeeritud ja töötama"
	# echo -n "Kas PostgreSQL 8.x on installeeritud ja töötab (j/e)? [j] "
	# read pgexists < /dev/tty
	# if [ "$pgexists" == "" ]
	# then
		# pgexists="j"
	# fi
	# if [ `echo $pgexists | grep -i e ` ]
	# then
		# echo "Installeeri PostgreSQL 8.x ja käivita"
		# echo
		# exit 1
	# fi

	# echo -n "Millises kataloogis on PostgreSQLi kliendi programmid [$pgsqlbin]? "
	# read mypgsqlbin < /dev/tty
	# if [ "$mypgsqlbin" == "" ]
	# then
		# mypgsqlbin=$pgsqlbin
	# fi
	# pgsqlbin=$mypgsqlbin
	# if [ ! -f $pgsqlbin/psql ]
	# then
		# echo "Ei leitud programmi $pgsqlbin/psql"
		# exit 1
	# fi
# fi


# echo -n "Millises arvutis asub PostgreSQL server [localhost]? "
# read pghost < /dev/tty
# if [ "$pghost" == "" ]
# then
	# pghost="localhost"
# fi

# echo -n "Millises pordis asub PostgreSQL server [5432]? "
# read pgport < /dev/tty
# if [ "$pgport" == "" ]
# then
	# pgport="5432"
# fi

# echo -n "Kuidas on andmebaasi nimi [xteeportal]? "
# read dbname < /dev/tty
# if [ "$dbname" == "" ]
# then
	# dbname="xteeportal"
# fi

# echo -n "Kuidas on skeemi nimi [misp]? "
# read scname < /dev/tty
# if [ "$scname" == "" ]
# then
	# scname="misp"
# fi

# echo -n "Kuidas on andmebaasi kasutajanimi [misp]? "
# read usname < /dev/tty
# if [ "$usname" == "" ]
# then
	# usname="misp"
# fi

# if [ "$cmd" == "backup" ]
# then
	# echo "Varundan andmed kasutajana '$usname'..."
	# $pgsqlbin/pg_dump -h $pghost -p $pgport -U $usname $dbname -n $scname -o -a > $workdir/xteedata.dump

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Varundamine ei laabunud"
		# exit 1
	# fi
	# n=`grep -ni "set search_path = " $workdir/xteedata.dump | cut -d':' -f1`
	# sed -i $n"s/search_path = $scname/search_path = misp/" $workdir/xteedata.dump
	# echo "Andmed on varundatud faili $workdir/xteedata.dump"
# fi

# if [ "$cmd" == "restore" ]
# then
	# if [ ! -s $workdir/xteedata.dump ]
	# then
		# echo "Andmed pole eksporditud. Ei leia andmete faili $workdir/xteedata.dump."
		# exit 1
	# fi

	# echo "Kustutan vanad andmed kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/delete_data.sql > tmp.delete_data.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.delete_data.sql -q

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Andmete kustutamine ei laabunud"
		# exit 1
	# fi


	# echo "Eemaldan piirangud kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/drop_constraint_fk.sql > tmp.drop_constraint_fk.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.drop_constraint_fk.sql -q

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Ei saanud piiranguid eemaldada"
	# fi


	# echo "Taastan andmed kasutajana '$usname'..."
	# n=`grep -ni "set search_path = " $workdir/xteedata.dump | cut -d':' -f1`
	# sed -i $n"s/search_path = misp/search_path = $scname/" $workdir/xteedata.dump

	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f $workdir/xteedata.dump -q

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Taastamine ei laabunud"
		# exit 1
	# fi


	# echo "Taastan piirangud kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/create_constraint_fk.sql > tmp.create_constraint_fk.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.create_constraint_fk.sql -q

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Ei saanud piiranguid taastada"
	# fi


	# echo "Andmed on laaditud andmebaasi"
# fi

# if [ "$cmd" == "delete" ]
# then
	# echo "Kustutan andmed kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/delete_data.sql > tmp.delete_data.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.delete_data.sql -q

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Andmete kustutamine ei laabunud"
		# exit 1
	# fi
	# echo "Andmed on andmebaasist kustutatud"
# fi

# if [ "$cmd" == "remove" ]
# then
	# echo -n "Kas kustutada andmebaasisüsteemi kasutaja \"$usname\" (j/e)? [e] "
	# read load < /dev/tty
	# if [ "$load" == "" ]
        # then
	    # load="e"
	# fi
	# if [ `echo $load | grep -i j ` ]
	# then
	    # echo "Kustutan kasutaja kasutajana 'postgres'..."
	    # $pgsqlbin/dropuser $usname -h $pghost -p $pgport -U postgres
	    # if [ ! "$PIPESTATUS" = "0" ]
	    # then
		# echo "Kasutaja $usname kustutamine ei laabunud"
	    # fi
        # fi

	# echo -n "Kas kustutada andmebaas \"$dbname\" (j/e)? [e] "
	# read load < /dev/tty
	# if [ "$load" == "" ]
        # then
	    # load="e"
	# fi
	# if [ `echo $load | grep -i j ` ]
	# then
	    # echo "Kustutan andmebaasi kasutajana 'postgres'..."
	    # $pgsqlbin/dropdb $dbname -h $pghost -p $pgport -U postgres
	    # if [ ! "$PIPESTATUS" = "0" ]
	    # then
		# echo "Andmebaasi kustutamine ei laabunud"
	    # fi
	# else
  	    # echo -n "Kas kustutada andmebaasist skeem \"$scname\" (j/e)? [e] "
	    # read load < /dev/tty
	    # if [ "$load" == "" ]
	    # then
		# load="e"
	    # fi
	    # if [ `echo $load | grep -i j ` ]
	    # then
	    	# echo "Kustutan skeemi kasutajana 'postgres'..."
		# echo "DROP SCHEMA $scname CASCADE;" > tmp.drop_schema.sql
		# $pgsqlbin/psql -h $pghost -p $pgport $dbname -f tmp.drop_schema.sql -U postgres
		# if [ ! "$PIPESTATUS" = "0" ]
	        # then
		    # echo "Skeemi kustutamine ei laabunud"
		# fi
	    # fi
        # fi
# fi

# if [ "$cmd" == "restoreldap" ]
# then
	# if [ ! -s $workdir/xteeldap.ldif ]
	# then
		# echo "Andmed pole eksporditud. Ei leia andmete faili $workdir/xteedata.sql."
		# exit 1
	# fi
	
	# cd $workdir

	# mitmerealised vaartused viime yhele reale
	# awk -f $xteeprefix/db/etc/singlerow.awk xteeldap.ldif > xteeldap-s.ldif

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Andmefaili teisendamine ei laabunud"
		# exit 1
	# fi

	# teisendame LDIFi SQLiks, tekib xteeldap.sql
	# awk -v scname=$scname -f $xteeprefix/db/etc/ldif2sql.awk xteeldap-s.ldif

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Andmefaili teisendamine SQLi ei laabunud"
		# exit 1
	# fi

	# teeme andmebaasis abitabelid
	# echo "Teen andmebaasis tabeleid kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/ldif2sql_tbl.sql > tmp.ldif2sql_tbl.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.ldif2sql_tbl.sql 
	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Abitabelite loomine ei laabunud"
		# exit 1
	# fi
	# piirangute eemaldamine
	# echo "Eemaldan piirangud kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/drop_constraint_fk.sql > tmp.drop_constraint_fk.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.drop_constraint_fk.sql 

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Ei saanud piiranguid eemaldada"
	# fi


	# loeme LDIFi andmed abitabelitesse
	# echo "Laadin andmed tabelitesse kasutajana '$usname'..."
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f xteeldap.sql -q
	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Andmete laadimine abitabelitesse ei laabunud"
		# exit 1
	# fi
	
	# viime andmed abitabelitest paris tabelitesse
	# echo "Kopeerin andmeid kasutajana '$usname'..."
	# sed -e '/DELETE/!s/oid/id/g' -e "s/misp./$scname./g" $xteeprefix/db/etc/ldif2sql_ins1.sql > tmp.ldif2sql_ins1.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.ldif2sql_ins1.sql 
	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Andmete laadimine tabelitesse ei laabunud"
		# exit 1
	# fi

	# salvestame andmebaasi identifikaatorite ja LDAP eraldusnimede vastavuse
	# (vastavuse faili loeb install-base-copy.sh)
	# echo "Salvestan andmeid kasutajana '$usname'..."
	# sed  $xteeprefix/db/etc/ldif2sql_ins2.sql > tmp.ldif2sql_ins2.sql
	# sed -e 's/oid/id/g' -e "s/misp./$scname./g" $xteeprefix/db/etc/ldif2sql_ins2.sql > tmp.ldif2sql_ins2.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.ldif2sql_ins2.sql -t > ldif2sql_dn.txt
	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Identifikaatorite salvestamine ei laabunud"
		# exit 1
	# fi

	# echo "Taastan piirangud kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/create_constraint_fk.sql > tmp.create_constraint_fk.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.create_constraint_fk.sql 

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Ei saanud piiranguid taastada"
	# fi


	# eemaldame abitabelid ja abivaljad
	# echo "Eemaldan abitabelid kasutajana '$usname'..."
	# sed "s/misp./$scname./g" $xteeprefix/db/etc/ldif2sql_ins3.sql > tmp.ldif2sql_ins3.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.ldif2sql_ins3.sql 
	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Abiveergude eemaldamine ei laabunud"
		# exit 1
	# fi

	# sed "s/misp./$scname./g" $xteeprefix/db/etc/ldif2sql_tbl_d.sql > tmp.ldif2sql_tbl_d.sql
	# $pgsqlbin/psql -h $pghost -p $pgport $dbname $usname -f tmp.ldif2sql_tbl_d.sql -q

	# if [ ! "$PIPESTATUS" = "0" ]
	# then
		# echo "Abitabelite eemaldamine ei laabunud"
		# exit 1
	# fi
	
	# echo "LDAP andmed on laaditud andmebaasi"
# fi

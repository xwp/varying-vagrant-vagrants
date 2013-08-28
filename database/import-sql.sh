#!/bin/bash
#
# Import provided SQL files in to MySQL.
#
# The files in the {vvv-dir}/database/backups/ directory should be created by
# mysqldump or some other export process that generates a full set of SQL commands
# to create the necessary tables and data required by a database.
#
# For an import to work properly, the SQL file should be named `db_name.sql` in which
# `db_name` matches the name of a database already created in {vvv-dir}/database/init-custom.sql
# or {vvv-dir}/database/init.sql.
#
# If a filename does not match an existing database, it will not import correctly.
#
# If tables already exist for a database, the import will not be attempted again. After an
# initial import, the data will remain persistent and available to MySQL on future boots
# through {vvv-dir}/database/data
#
# Let's begin...

# Move into the newly mapped backups directory, where mysqldump(ed) SQL files are stored
printf "\nStart MySQL Database Import\n"
cd /srv/database/backups/

# Parse through each file in the directory and use the file name to
# import the SQL file into the database of the same name
sql_count=`ls -1 *.sql 2>/dev/null | wc -l`
if [ $sql_count != 0 ]
then
	for file in $( ls *.sql )
	do
	pre_dot=${file%%.*}
	mysql_cmd='SHOW TABLES FROM `'$pre_dot'`' # Required to support hypens in database names
	db_exist=`mysql -u root -pblank --skip-column-names -e "$mysql_cmd"`
	if [ "$?" != "0" ]
	then
		printf "  * Error - Create $pre_dot database via init-custom.sql before attempting import\n\n"
	else
		if [ "" == "$db_exist" ]
		then
			printf "mysql -u root -pblank $pre_dot < $pre_dot.sql\n"
			mysql -u root -pblank $pre_dot < $pre_dot.sql
			printf "  * Import of $pre_dot successful\n"
		else
			printf "  * Skipped import of $pre_dot - tables exist\n"
		fi
	fi
	done
	printf "Databases imported\n"
else
	printf "No databases to import in /srv/database/backups\n"
fi

# Load vvv-data.sql dumps in each WordPress project if WordPress is not installed
if [ -e /usr/local/bin/wp ]; then
	echo "Looking for vvv-data.sql files in WordPress projects within /srv/www..."
	for vvv_data_sql in $(find /srv/www -name vvv-data.sql); do
		cd $(dirname $vvv_data_sql)
		output=$(wp core is-installed 2>&1)
		exit_code=$?
		if [ $exit_code != 0 ] || grep -s 'Error establishing a database connection' <<< $output; then
			wp db import $vvv_data_sql
		else
			echo "Skipping since already installed: $vvv_data_sql"
		fi
	done
else
	echo "Skipping import of /srv/www/**/vvv-data.sql since WP-CLI not installed"
fi

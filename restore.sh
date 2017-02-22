#!/bin/bash

# Restorescript

currentdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define settings file 
CONFIGFILE="$currentdir/settings.ini"
NOW=$(date +"%Y-%m-%d_%H:%M:%S")
# Read and parse config file
eval $(sed '/:/!d;/^ *#/d;s/:/ /;' < "$CONFIGFILE" | while read -r key val
do
  if [ -n "${key}" ]; then
    str="$key='$val'"
    echo "$str"
  fi
done
)

# Set full path to log
LOGFILE="/var/log/drupal/dbrestore-$SITENAME.log"

# Function to log to file
log_message() {
  if  [ ! "$2" ]; then
    LEVEL="NOTICE";
  else
    LEVEL="$2";
  fi
  TIMEDATE=`date`
  echo [$TIMEDATE] [$LEVEL] $1 >> $LOGFILE
}

# Function to display current status in dimmed font
status_message() {
  echo
  log_message "$1"
  echo -e "$1..."
}
status_message "** Starting restore **"

# Function to show error message and exit
exit_error() {
  echo
  log_message "$1" "ERROR"
  echo -e "$(tput setaf 1)$1 $(tput sgr0)"
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  echo -e "$(tput setaf 1)Aborting Restore $(tput sgr0)"
  log_message "Restore Failed" "ERROR"
  echo
  exit 1
}

# Check if logfile exists
if [ ! -f "$LOGFILE" ]; then
  # Fix access to logfile (sudo??)
  status_message "Trying to fix access to \"$LOGFILE\""
  touch $LOGFILE
  if [ "$RESTOREUSER" ]; then
   chown $RESTOREUSER $LOGFILE
  fi
  chmod 775 $LOGFILE
  if [ ! -f "$LOGFILE" ]; then
    exit_error "Unable to open \"$LOGFILE\"!" "Run this script once with a sudo enabled user or root to set correct permissions on the logfile."
  fi
fi

# Check Restore user
if [ "$RESTOREUSER" ]; then
  if  [ ! "$RESTOREUSER" = "$USER" ]; then
    exit_error "Wrong user: $USER" "Deployscript must be run as user \"$RESTOREUSER\". Try: sudo su $RESTOREUSER ./restore.sh"
    # sudo su $RESTOREUSER
    # echo
  fi
fi

# Drop database tables
if [ $DATABASECLEAN = "YES" ]; then
status_message "** Cleaning Database \"$DBNAME\" on \"$DBHOST\" **"
	if ! PGPASSWORD="$DBPASSWORD" /usr/pgsql-9.3/bin/psql -h $DBHOST -U $DBUSER $DBNAME -t -c "select 'drop table \"' || tablename || '\" cascade;' from pg_tables where schemaname = 'public'"  | PGPASSWORD="$DBPASSWORD" /usr/pgsql-9.3/bin/psql -h $DBHOST -U $DBUSER $DBNAME; then
	exit_error "Database clean failed, aborting!"
	fi
fi

BACKUPDIR=`ls -d $BACKUPPATH/*/ | tail -n -1`
status_message "** Taking folder $BACKUPDIR **"

# Restore database from backup
if [ $DATABASERESTORE = "YES" ]; then
status_message "** Restoring DatabaseBackup \"$DBNAME\" on \"$DBHOST\" **"
	if ! gunzip < $BACKUPPATH/$BACKUPDIR/$SITENAME.sql.gz | PGPASSWORD="$DBPASSWORD" /usr/pgsql-9.3/bin/psql -d $DBNAME -h $DBHOST -U $DBUSER; then
	exit_error "Database restore failed, aborting!"
	fi
fi

# Restore files from backup location
if [ $FILESRESTORE = "YES" ]; then
status_message "** Restore files from backup **"
	if ! sudo chown -R $RESTOREUSER $WEBROOT/$DRUPALSITEDIR; then
	exit_error "Chown $RESTOREUSER $WEBROOT/$DRUPALSITEDIR failed, aborting!"
	fi
	if ! tar -zxf $BACKUPPATH/$BACKUPDIR/$SITENAME.filesbackup.tar.gz -C $WEBROOT/$DRUPALSITEDIR; then
	exit_error "Files restore failed, aborting!"
	fi
	if ! sudo chown -R apache:apache $WEBROOT/$DRUPALSITEDIR; then
	exit_error "Chown apache:apache $WEBROOT/$DRUPALSITEDIR failed, aborting!"
	fi
fi




status_message "** Finished restoring the backup ;) **"


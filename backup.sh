#! /bin/bash
#
set -e

INCLUDES_FILE=/opt/restic/includes.list
EXCLUDES_FILE=/opt/restic/excludes.list

# Number of snapshots to keep
DAILY=7
WEEKLY=4
MONTHLY=12
YEARLY=1

Help()
{
   echo "Add description of the script functions here."
   echo
   echo "Syntax: restic-backup [-i|-e|-d|-w|-m|-y]"
   echo "options:"
   echo "h     Print this Help."
   echo "i     Path to the includes file (default: /opt/restic/includes.list)"
   echo "e     Path to the excludes file (default: /opt/restic/excludes.list)"
   echo "d     Number of daily backups ketp (default: 7)"
   echo "w     Number of weekly backups kept (default: 4)"
   echo "m     Number of monthly backups kept (default: 12)"
   echo "y     Number of yearly backups kept (default: 1)"
   echo
}
while getopts "i:e:d:w:m:y:h" option; do
   case $option in
    i) INCLUDES_FILE=$OPTARG;;
    e) EXCLUDES_FILE=$OPTARG;;
    d) DAILY=$OPTARG;;
    w) WEEKLY=$OPTARG;;
    m) MONTHLY=$OPTARG;;
    y) YEARLY=$OPTARG;;
    h) # display Help
        Help
        exit;;
    *) Help
        exit 1 ;;
   esac
done

if [ ! -f "/etc/restic-environment" ]; then
    echo "/etc/restic-environment not found, please run install.sh"
    exit 1
else
    source /etc/restic-environment
fi

if [ ! -f "$INCLUDES_FILE" ]; then
    echo "$INCLUDES_FILE is not found"
    echo "Please ensure an includes.list is in this location"
    exit 1
fi

if [ ! -f "$EXCLUDES_FILE" ]; then
    echo "$EXCLUDES_FILE is not found."
    echo "Please ensure an excludes.list is in this location"
    exit 1
fi

# Check if logfile exists
if [ ! -f /var/log/restic-backup.log ]; then
    touch /var/log/restic-backup.log
fi

LOG_FILE=$(mktemp)
echo "STARTED BACKUP AT $(date)" >> $LOG_FILE
echo "Backing up" >> $LOG_FILE
/usr/bin/restic backup --files-from "$INCLUDES_FILE" --exclude-file "$EXCLUDES_FILE" --exclude-caches >> "$LOG_FILE" 2>&1
echo "Maintaining repo to 7 daily, 4 weekly, 12 monthly, 1 yearly" >> "$LOG_FILE" 2>&1
/usr/bin/restic forget --keep-daily "$DAILY" --keep-weekly "$WEEKLY" --keep-monthly "$MONTHLY" --keep-yearly "$YEARLY" >> "$LOG_FILE" 2>&1

echo "BACKUP COMPLETE AT $(date)" >> $LOG_FILE

# Write out log output to syslog
logger -f "$LOG_FILE"

cat "$LOG_FILE" >> /var/log/restic-backup.log

if [ ! -z "$RESTIC_ALERT_EMAIL" ]; then
    echo "Sending email with backup status to $RESTIC_ALERT_EMAIL"
    echo -e "Subject: Restic Backup for $(hostname) at $(date)" | cat - "$LOG_FILE" | /usr/sbin/sendmail -f "$(hostname)" -t "$ALERT_EMAIL"

fi 

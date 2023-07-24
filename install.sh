#! /bin/bash
#
set -e
INSTALLER_DIR=$PWD
INCLUDES_FILE="$INSTALLER_DIR"/includes.list
EXCLUDES_FILE="$INSTALLER_DIR"/excludes.list
BUCKET_NAME="restic-linux"

Help()
{
   echo "Add description of the script functions here."
   echo
   echo "Syntax: restic-backup [-i|-e|-b|-h]"
   echo "options:"
   echo "h     Print this Help."
   echo "i     Path to the includes file to install (default: $INSTALLER_DIR/includes.list)"
   echo "e     Path to the excludes file to install (default: $INSTALLER_DIR/excludes.list)"
   echo "b     Bucket name (default:restic-linux)"
   echo
}
while getopts "i:e:b:h" option; do
   case $option in
    i) INCLUDES_FILE=$OPTARG;;
    e) EXCLUDES_FILE=$OPTARG;;
    b) BUCKET_NAME=$OPTARG;;
    h) # display Help
        Help
        exit;;
    *) 
        Help
        exit 1 ;;
   esac
done


#Check for root
if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root." >&2; exit 1; 
fi

#Check for env file
if [ ! -f /etc/restic-environment ]; then
    echo "Restic environment file not found... creating"
    touch /etc/restic-environment
    new_install=1
else
    echo "Found /etc/restic-environment, sourcing..."
    source /etc/restic-environment
fi

#Check if env vars are set
if [ -z "${RESTIC_REPOSITORY}" ]; then
    echo "Restic Repository not set"
    repo_tmp="b2:$BUCKET_NAME:$HOSTNAME/repo"

    #See if user wishes to keep default repo name
    echo "Default repo name of $repo_tmp set."
    read -p "Do you wish to keep the repo name set to $repo_tmp? (Y/n)" set_repo
    set_repo=${set_repo:-Y}
    if [ "${set_repo,,}" == "y" ]; then
        restic_repo="$repo_tmp"
    elif [ "${set_repo,,}" == "n" ]; then
        read -p "Enter restic repository name ex: 'b2:restic-linux:$HOSTNAME/repo': " -r restic_repo
    else
        echo "Unknown response to repo name setting question... exiting"
        exit 1
    fi
    echo "export RESTIC_REPOSITORY=\"$restic_repo\"" >> /etc/restic-environment
else
    echo "Restic repository set as ${RESTIC_REPOSITORY}"
fi

if [ -z "${RESTIC_PASSWORD}" ]; then
    echo "Restic Password not set"
    echo -n "Enter the restic repo password to set env var: " 
    read -s -r restic_pw
    echo "export RESTIC_PASSWORD=\"$restic_pw\"" >> /etc/restic-environment
else
    echo "Restic password is set as env var RESTIC_PASSWORD"
fi

if [ -z "${B2_ACCOUNT_ID}" ]; then
    echo "B2 key ID not set"
    echo -n "Enter the b2 key ID for the appkey:"
    read -r b2_acct_id
    echo "export B2_ACCOUNT_ID=\"$b2_acct_id\"" >> /etc/restic-environment
else
    echo "B2_ACCOUNT_ID set to ${B2_ACCOUNT_ID}"
fi

if [ -z "${B2_ACCOUNT_KEY}" ]; then
    echo "B2 Account Key not set for $b2_acct_id"
    echo -n "Enter the app key for the provided b2 app key ID $b2_acct_id:"
    read -s -r b2_acct_key
    echo ""
    echo "export B2_ACCOUNT_KEY=\"$b2_acct_key\"" >> /etc/restic-environment
else
    echo "B2_ACCOUNT_KEY set as env var B2_ACCOUNT_KEY"
fi

# Setup email alerts
if [ -z "${RESTIC_ALERT_EMAIL}" ]; then
    echo "Email for alerts is not set."
    echo "Please enter an email to send restic alerts to:"
    read -s -r restic_alert_email

    echo "Setting email alerts to be sent to $restic_alert_email"
    echo "export RESTIC_ALERT_EMAIL=\"$restic_alert_email\"" >> /etc/restic-environment
else
    echo "Restic alerts are configured to send to $RESTIC_ALERT_EMAIL"
fi

#If new install set RO and source env
if ! lsattr /etc/restic-environment | grep -q '\-i-'; then
    echo "Making /etc/restic-environment RO by root and immutable"
    chmod 0400 /etc/restic-environment
    chattr +i /etc/restic-environment

    source /etc/restic-environment
fi

if [ ! -d /opt/restic ]; then
    echo "Creating restic install dir /opt/restic"
    mkdir -p /opt/restic
fi

if [ ! -f /opt/restic/restic ]; then
    echo "Restic not installed in /opt/restic/, downloading and installing"

    pushd /tmp || exit 1
    wget https://github.com/restic/restic/releases/download/v0.15.2/restic_0.15.2_linux_amd64.bz2 -O restic.bz2
    bzip2 -d restic.bz2
    chmod +x restic
    mv restic /opt/restic/restic
    popd || exit 1
    
    ln -s /opt/restic/restic /usr/bin/restic
    echo "Restic installed to /opt/restic/restic and symlinked to /usr/bin/restic"
fi

if [ ! -f /opt/restic/includes.list ]; then
    echo "include.list not found in /opt/restic/, moving $INCLUDES_FILE"
    cp "$INCLUDES_FILE" /opt/restic/includes.list
fi

if [ ! -f /opt/restic/excludes.list ]; then
    echo "exclude.list not found in /opt/restic/, moving $EXCLUDES_FILE"
    cp "$EXCLUDES_FILE" /opt/restic/excludes.list
fi

# Logging setup
#
# Check if logfile exists
if [ ! -f /var/log/restic-backup.log ]; then
    touch /var/log/restic-backup.log
fi

# Logrotate
if [ ! -f /etc/logrotate.d/restic-backup ]; then
    echo "Installing logrotate for /var/log/restic-backup"
cat << EOF > /etc/logrotate.d/restic-backup 
/var/log/restic-backup {
    rotate 16
    weekly
    compress
}
EOF
fi

if [ ! -f /opt/restic/restic-backup ]; then
    echo "Installing restic-backup into /opt/restic/restic-backup"
    cp "$INSTALLER_DIR"/backup.sh /opt/restic/restic-backup
fi

if [ -f /opt/restic/restic-backup ]; then
    echo "Installation complete!"
    echo "Initializing reposiotry"
    /usr/bin/restic init
    echo "##############################"
    echo "Run /opt/restic/restic-backup to perform backup using exclude and include lists installed in /opt/restic/"
    echo "##############################"
fi


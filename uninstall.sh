#! /bin/bash
#
#Check for root
if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root." >&2; exit 1; 
fi

echo "Removing restic..."
unlink /usr/bin/restic
rm -rf /opt/restic
echo "Removing restic-environment"
chattr -i /etc/restic-environment
rm -f /etc/restic-environment

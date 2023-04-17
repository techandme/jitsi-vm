#!/bin/bash

#################################################################################################################
# DO NOT USE THIS SCRIPT WHEN UPDATING JITSI / YOUR SERVER! RUN `sudo bash /var/scripts/update.sh` INSTEAD. #
#################################################################################################################

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

true
SCRIPT_NAME="Nextcloud Update Script"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Get all needed variables from the library
ncdb
nc_update

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

# Must be root
root_check

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Automatically restart services (Ubuntu 22.04)
if ! version 16.04.10 "$DISTRO" 20.04.10
then
    if ! grep -rq "{restart} = 'a'" /etc/needrestart/needrestart.conf
    then
        # Restart mode: (l)ist only, (i)nteractive or (a)utomatically.
        sed -i "s|#\$nrconf{restart} =.*|\$nrconf{restart} = 'a'\;|g" /etc/needrestart/needrestart.conf
    fi
fi

# Fix fancy progress bar for apt-get
# https://askubuntu.com/a/754653
if [ -d /etc/apt/apt.conf.d ]
then
    if ! [ -f /etc/apt/apt.conf.d/99progressbar ]
    then
        echo 'Dpkg::Progress-Fancy "1";' > /etc/apt/apt.conf.d/99progressbar
        echo 'APT::Color "1";' >> /etc/apt/apt.conf.d/99progressbar
        chmod 644 /etc/apt/apt.conf.d/99progressbar
    fi
fi

print_text_in_color "$ICyan" "Fetching latest packages with apt..."
apt-get clean all
apt-get update -q4 & spinner_loading
if apt-cache policy | grep "ondrej" >/dev/null 2>&1
then
    print_text_in_color "$ICyan" "Ondrejs PPA is installed. \
Holding PHP to avoid upgrading to a newer version without migration..."
    apt-mark hold php* >/dev/null 2>&1
fi

# Make sure fetch_lib.sh is available
download_script STATIC fetch_lib

# Upgrade OS dependencies
export DEBIAN_FRONTEND=noninteractive ; apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

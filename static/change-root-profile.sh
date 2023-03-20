#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

true
SCRIPT_NAME="Change root Profile"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

[ -f /root/.profile ] && rm -f /root/.profile

cat <<ROOT-PROFILE > "$ROOT_PROFILE"

# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]
then
    if [ -f ~/.bashrc ]
    then
        . ~/.bashrc
    fi
fi

if [ -x /var/scripts/jitsi-startup-script.sh ]
then
    /var/scripts/jitsi-startup-script.sh
fi

if [ -x /var/scripts/history.sh ]
then
    /var/scripts/history.sh
fi

mesg n

ROOT-PROFILE

# Add Aliases
{
echo "alias restart_jitsi='bash $SCRIPTS/restart-jitsi.sh'"
} > /root/.bash_aliases


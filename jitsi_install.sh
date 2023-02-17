#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/nextcloud/vm/blob/master/LICENSE

# Prefer IPv4 for apt
echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4

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

# Install curl if not existing
if [ "$(dpkg-query -W -f='${Status}' "curl" 2>/dev/null | grep -c "ok installed")" = "1" ]
then
    echo "curl OK"
else
    apt-get update -q4
    apt-get install curl -y
fi

# Install whiptail if not existing
if [ "$(dpkg-query -W -f='${Status}' "curl" 2>/dev/null | grep -c "ok installed")" = "1" ]
then
    echo "whiptail OK"
else
    apt-get update -q4
    apt-get install whiptail -y
fi


true
SCRIPT_NAME="Jitsi Install Script"
SCRIPT_EXPLAINER="This script is installing all requirements that are needed for Jitsi to run.
It's the first of two parts that are necessary to finish your customized Jitsi installation."
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/techandme/jitsi-vm/dev/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Test RAM size (2GB min) + CPUs (min 1)
ram_check 2 Jitsi
cpu_check 2 Jitsi

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

# Check distribution and version
if ! version 22.04 "$DISTRO" 22.04.10
then
    msg_box "This script can only be run on Ubuntu 22.04 (server)."
    exit 1
fi

# Automatically restart services
# Restart mode: (l)ist only, (i)nteractive or (a)utomatically.
sed -i "s|#\$nrconf{restart} = .*|\$nrconf{restart} = 'a';|g" /etc/needrestart/needrestart.conf

# Add repository Universe
check_universe

# Install needed dependencies
install_if_not lshw
install_if_not net-tools
install_if_not whiptail
install_if_not apt-utils
install_if_not gnupg2
install_if_not nginx-full
install_if_not apt-transport-https
install_if_not ufw

# Nice to have dependencies
install_if_not bash-completion
install_if_not htop
install_if_not nano
install_if_not iputils-ping


########################

# Parsody REPO
curl -sL https://prosody.im/files/prosody-debian-packages.key | sudo tee /etc/apt/keyrings/prosody-debian-packages.key
echo "deb [signed-by=/etc/apt/keyrings/prosody-debian-packages.key] http://packages.prosody.im/debian $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/prosody-debian-packages.list

# Jitsi REPO
curl -sL https://download.jitsi.org/jitsi-key.gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/jitsi-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/" | sudo tee /etc/apt/sources.list.d/jitsi-stable.list

# Install more needed dependcies
install_if_not lua5.2

# UFW rules
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10000/udp
ufw allow 22/tcp
ufw allow 3478/udp
ufw allow 5349/tcp
ufw enable
ufw status verbose

exit # test to install parsody

# Install Jitsi
install_if_not jitsi-meet

sed -i "s|DefaultLimitNOFILE=.*|DefaultLimitNOFILE=65000|g" /etc/systemd/system.conf
sed -i "s|DefaultLimitNPROC=.*|DefaultLimitNPROC=65000|g" /etc/systemd/system.conf
sed -i "s|DefaultTasksMax=.*|DefaultTasksMax=65000|g" /etc/systemd/system.conf

apt purge jitsi-meet-prosody -y


## TODO for STARTUP SCRIPT
org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS=<Local.IP.Address>
org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS=<Public.IP.Address>

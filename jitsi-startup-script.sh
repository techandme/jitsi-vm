#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/techandme/jitsi-vm/blob/main/LICENSE

#########

IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
ICyan='\e[0;96m'        # Cyan
Color_Off='\e[0m'       # Text Reset
print_text_in_color() {
	printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

print_text_in_color "$ICyan" "Fetching all the variables from lib.sh..."

is_process_running() {
PROCESS="$1"

while :
do
    RESULT=$(pgrep "${PROCESS}")

    if [ "${RESULT:-null}" = null ]; then
            break
    else
            print_text_in_color "$ICyan" "${PROCESS} is running, waiting for it to stop..."
            sleep 10
    fi
done
}

#########

# Check if dpkg or apt is running
is_process_running apt
is_process_running dpkg

true
SCRIPT_NAME="Jitsi Startup Script"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check if root
root_check

# Check network
if network_ok
then
    print_text_in_color "$IGreen" "Online!"
else
    print_text_in_color "$ICyan" "Setting correct interface..."
    [ -z "$IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
    # Set correct interface
    cat <<-SETDHCP > "/etc/netplan/01-netcfg.yaml"
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: true
      dhcp6: true
SETDHCP
    check_command netplan apply
    print_text_in_color "$ICyan" "Checking connection..."
    sleep 1
    set_systemd_resolved_dns "$IFACE"
    if ! nslookup github.com
    then
        msg_box "The script failed to get an address from DHCP.
You must have a working network connection to run this script.
You will now be provided with the option to set a static IP manually instead."

        # Run static_ip script
	bash /var/scripts/static_ip.sh
    fi
fi

# Check network again
if network_ok
then
    print_text_in_color "$IGreen" "Online!"
else
    msg_box "Network is NOT OK. You must have a working network connection to run this script.
Please contact us for support:
https://shop.hanssonit.se/product/premium-support-per-30-minutes/
Please also post this issue on: https://github.com/techandme/jitsi-vm"
    exit 1
fi

# Run the startup menu
run_script MENU startup_configuration

true
SCRIPT_NAME="Jitsi Startup Script"
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

msg_box "This script will configure your server and Jitsi.
It will also do the following:
- Generate new SSH keys for the server
- Detect and set hostname
- Upgrade your system and Jitsi to latest version
- Set new passwords to Linux (Ubuntu OS)
- Change timezone
- Add additional options if you choose them
- And more..."

msg_box "PLEASE NOTE:
[#] Please finish the whole setup. The server will reboot once done.
[#] Please read the on-screen instructions carefully, they will guide you through the setup.
[#] When complete it will delete all the *.sh, *.html, *.tar, *.zip inside:
    /root
    /home/$UNIXUSER
[#] Please consider donating if you like the product:
    https://shop.hanssonit.se/product-category/donate/
[#] You can also ask for help here:
    https://community.jitsi.org/
    https://shop.hanssonit.se/product/premium-support-per-30-minutes/"

msg_box "PLEASE NOTE:
The first setup is meant to be run once, and not aborted.
If you feel uncertain about the options during the setup, just choose the defaults by hitting [ENTER] at each question.
When the setup is done, the server will automatically reboot.
Please report any issues to: $ISSUES"

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

### Change passwords
# CLI USER
UNIXUSER="$(getent group sudo | cut -d: -f4 | cut -d, -f1)"
if [[ "$UNIXUSER" != "jitsiadmin" ]]
then
   print_text_in_color "$ICyan" "No need to change password for CLI user '$UNIXUSER' since it's not the default user."
else
    msg_box "For better security, we will now change the password for the CLI user in Ubuntu."
    while :
    do
        UNIX_PASSWORD=$(input_box_flow "Please type in the new password for the current CLI user in Ubuntu: $UNIXUSER.")
        if [[ "$UNIX_PASSWORD" == *" "* ]]
        then
            msg_box "Please don't use spaces."
        else
            break
        fi
    done
    if check_command echo "$UNIXUSER:$UNIX_PASSWORD" | sudo chpasswd
    then
        msg_box "The new password for the current CLI user in Ubuntu ($UNIXUSER) is now set to: $UNIX_PASSWORD
    This is used when you login to the Ubuntu CLI."
    fi
fi
unset UNIX_PASSWORD

# Install Jitsi
install_if_not jitsi-meet # maybe it's possible to pass $1 for domain?

{
echo "# Custom
org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS=$ADDRESS
# This can also be your DNS, e.g. jitsi.yourdomain.com
org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS=$WANIP4"
} >> /etc/jitsi/videobridge/sip-communicator.properties

# Cleanup 1
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$SCRIPTS/static_ip.sh"
rm -f "$SCRIPTS/lib.sh"
rm -f "$SCRIPTS/adduser.sh"
rm -f "/var/log/jitsi"/*.log
rm -f "/var/log/prosody"/*.log

find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name 'results' -o -name '*.zip*' \) -delete
find "$NCPATH" -type f \( -name 'results' -o -name '*.sh*' \) -delete
sed -i "s|instruction.sh|welcome.sh|g" "/home/$UNIXUSER/.bash_profile"

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/nginx/access.log \
    /var/log/nginx/error.log

sed -i "s|sudo -i||g" "$UNIXUSER_PROFILE"

cat << ROOTNEWPROFILE > "$ROOT_PROFILE"
# ~/.profile: executed by Bourne-compatible login shells.
if [ "/bin/bash" ]
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
ROOTNEWPROFILE

# Upgrade system
print_text_in_color "$ICyan" "System will now upgrade..."
bash $SCRIPTS/update.sh minor

# Cleanup 2
apt-get autoremove -y
apt-get autoclean

# Remove preference for IPv4
rm -f /etc/apt/apt.conf.d/99force-ipv4
apt-get update

# Success!
msg_box "The installation process is *almost* done.
Please hit OK in all the following prompts and let the server reboot to complete the installation process."

msg_box "SUPPORT:
Please ask for help in the forums, visit our shop to buy support:
- SUPPORT: https://shop.hanssonit.se/product/premium-support-per-30-minutes/
- FORUM: https://community.jitsi.org/
BUGS:
Please report any bugs here: $ISSUES"

msg_box "### PLEASE HIT OK TO REBOOT ###
Congratulations! You have successfully installed Jitsi!
USE JITSI:
Go to Jitsi in your browser:
- IP: $ADDRESS
- Hostname: $(hostname -f)
### PLEASE HIT OK TO REBOOT ###"

# Reboot
print_text_in_color "$IGreen" "Installation done, system will now reboot..."
check_command rm -f "$SCRIPTS/you-can-not-run-the-startup-script-several-times"
check_command rm -f "$SCRIPTS/jitsi-startup-script.sh"
if ! reboot
then
    shutdown -r now
fi

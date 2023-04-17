#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/
# GNU General Public License v3.0
# https://github.com/techandme/jitsi-vm/blob/main/LICENSE

# shellcheck disable=SC2034
true
# see https://github.com/koalaman/shellcheck/wiki/Directive

# Dirs
SCRIPTS=/var/scripts
VMLOGS=/var/log/jitsi

# Ubuntu OS
DISTRO=$(lsb_release -sr)
CODENAME=$(lsb_release -sc)
KEYBOARD_LAYOUT=$(localectl status | grep "Layout" | awk '{print $3}')

# Letsencrypt
SITES_AVAILABLE="/etc/apache2/sites-available"
LETSENCRYPTPATH="/etc/letsencrypt"
CERTFILES="$LETSENCRYPTPATH/live"
DHPARAMS_TLS="$CERTFILES/$TLSDOMAIN/dhparam.pem"
DHPARAMS_SUB="$CERTFILES/$SUBDOMAIN/dhparam.pem"
TLS_CONF="jitsi_tls_domain_self_signed.conf"
HTTP_CONF="jitsi_http_domain_self_signed.conf"

# Collabora App
HTTPS_CONF="$SITES_AVAILABLE/$SUBDOMAIN.conf"
HTTP2_CONF="/etc/apache2/mods-available/http2.conf"

# PHP-FPM
PHPVER=8.1
PHP_FPM_DIR=/etc/php/$PHPVER/fpm
PHP_INI=$PHP_FPM_DIR/php.ini
PHP_POOL_DIR=$PHP_FPM_DIR/pool.d
PHP_MODS_DIR=/etc/php/"$PHPVER"/mods-available

# User information
UNIXUSER=$SUDO_USER
UNIXUSER_PROFILE="/home/$UNIXUSER/.bash_profile"
ROOT_PROFILE="/root/.bash_profile"

ISSUES="https://github.com/techandme/jitsi-vm/issues"

# Repo
GITHUB_REPO="https://raw.githubusercontent.com/techandme/jitsi-vm/main"
STATIC="$GITHUB_REPO/static"
LETS_ENC="$GITHUB_REPO/lets-encrypt"
NETWORK="$GITHUB_REPO/network"
MENU="$GITHUB_REPO/menu"

# Network
IFACE=$(ip r | grep "default via" | awk '{print $5}')
IFACE2=$(ip -o link show | awk '{print $2,$9}' | grep 'UP' | cut -d ':' -f 1)
REPO=$(grep "^deb " /etc/apt/sources.list | grep http | awk '{print $2}' | head -1)
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
WANIP4=$(curl -s -k -m 5 -4 https://api64.ipify.org)
INTERFACES="/etc/netplan/jitsi.yaml"
GATEWAY=$(ip route | grep default | awk '{print $3}')
# Internet DNS required when a check needs to be made to a server outside the home/SME
INTERNET_DNS="9.9.9.9"
# Default Quad9 DNS servers, overwritten by the systemd global DNS defined servers, if set
DNS1="9.9.9.9"
DNS2="149.112.112.112"

# Whiptails
TITLE="Jitsi VM - $(date +%Y)"
[ -n "$SCRIPT_NAME" ] && TITLE+=" - $SCRIPT_NAME"
CHECKLIST_GUIDE="Navigate with the [ARROW] keys and (de)select with the [SPACE] key. \
Confirm by pressing [ENTER]. Cancel by pressing [ESC]."
MENU_GUIDE="Navigate with the [ARROW] keys and confirm by pressing [ENTER]. Cancel by pressing [ESC]."
RUN_LATER_GUIDE="You can view this script later by running 'sudo bash $SCRIPTS/menu.sh'."


# Functions
is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}

# Check if root
root_check() {
if ! is_root
then
    msg_box "Sorry, you are not root. You now have two options:
1. Use SUDO directly:
   a) :~$ sudo bash $SCRIPTS/name-of-script.sh
2. Become ROOT and then type your command:
   a) :~$ sudo -i
   b) :~# bash $SCRIPTS/name-of-script.sh
In both cases above you can leave out $SCRIPTS/ if the script
is directly in your PATH.
More information can be found here: https://unix.stackexchange.com/a/3064"
    exit 1
fi
}

debug_mode() {
if [ "$DEBUG" -eq 1 ]
then
    set -ex
fi
}

network_ok() {
version(){
    local h t v

    [[ $2 = "$1" || $2 = "$3" ]] && return 0

    v=$(printf '%s\n' "$@" | sort -V)
    h=$(head -n1 <<<"$v")
    t=$(tail -n1 <<<"$v")

    [[ $2 != "$h" && $2 != "$t" ]]
}
if version 20.04 "$DISTRO" 22.04.10
then
    print_text_in_color "$ICyan" "Testing if network is OK..."
    if site_200 github.com
    then
        return
    fi
    if ! netplan apply
    then
        systemctl restart systemd-networkd > /dev/null
    fi
    # Check the connention
    countdown 'Waiting for network to restart...' 3
    if ! site_200 github.com
    then
        # sleep 10 seconds so that some slow networks have time to restart
        countdown 'Not online yet, waiting a bit more...' 10
        if ! site_200 github.com
        then
            # sleep 30 seconds so that some REALLY slow networks have time to restart
            countdown 'Not online yet, waiting a bit more (final attempt)...' 30
            site_200 github.com
        fi
    fi
else
    msg_box "Your current Ubuntu version is $DISTRO but must be between 20.04 - 22.04.10 to run this script."
    msg_box "Please contact us to get support for upgrading your server:
https://www.hanssonit.se/#contact
https://shop.hanssonit.se/"
    msg_box "We will now pause for 60 seconds. Please press CTRL+C when prompted to do so."
    countdown "Please press CTRL+C to abort..." 60
fi
}



# Check if process is runnnig: is_process_running dpkg
is_process_running() {
PROCESS="$1"

while :
do
    RESULT=$(pgrep "${PROCESS}")

    if [ "${RESULT:-null}" = null ]; then
            break
    else
            print_text_in_color "$ICyan" "${PROCESS} is running, waiting for it to stop. Please be patient..."
            sleep 30
    fi
done
}

msg_box() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    whiptail --title "$TITLE$SUBTITLE" --msgbox "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3
}

yesno_box_yes() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    if (whiptail --title "$TITLE$SUBTITLE" --yesno "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    then
        return 0
    else
        return 1
    fi
}

yesno_box_no() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    if (whiptail --title "$TITLE$SUBTITLE" --defaultno --yesno "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    then
        return 0
    else
        return 1
    fi
}

input_box() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    local RESULT && RESULT=$(whiptail --title "$TITLE$SUBTITLE" --nocancel --inputbox "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    echo "$RESULT"
}

input_box_flow() {
    local RESULT
    while :
    do
        RESULT=$(input_box "$1" "$2")
        if [ -z "$RESULT" ]
        then
            msg_box "Input is empty, please try again." "$2"
        elif ! yesno_box_yes "Is this correct? $RESULT" "$2"
        then
            msg_box "OK, please try again." "$2"
        else
            break
        fi
    done
    echo "$RESULT"
}

# Checks if site is reachable with a HTTP 200 status
site_200() {
print_text_in_color "$ICyan" "Checking connection..."
        CURL_STATUS="$(curl -LI "${1}" -o /dev/null -w '%{http_code}\n' -s)"
        if [[ "$CURL_STATUS" = "200" ]]
        then
            return 0
        else
            print_text_in_color "$IRed" "curl didn't produce a 200 status, is ${1} reachable?"
            return 1
        fi
}

# Do a DNS lookup and compare the WAN address with the A record
domain_check_200() {
    print_text_in_color "$ICyan" "Doing a DNS lookup for ${1}..."
    install_if_not dnsutils

    # Try to resolve the domain with nslookup using $DNS as resolver
    if nslookup "${1}" "$INTERNET_DNS"
    then
        print_text_in_color "$IGreen" "DNS seems correct when checking with nslookup!"
    else
        msg_box "DNS lookup failed with nslookup. \
Please check your DNS settings! Maybe the domain isn't propagated?
You can use this site to check if the IP seems correct: https://www.whatsmydns.net/#A/${1}"
        if ! yesno_box_no "Are you 100% sure the domain is correct?"
        then
            exit
        fi
    fi

    # Is the DNS record same as the external IP address of the server?
    if dig +short "${1}" @resolver1.opendns.com | grep -q "$WANIP4"
    then
        print_text_in_color "$IGreen" "DNS seems correct when checking with dig!"
    else
    msg_box "DNS lookup failed with dig. The external IP ($WANIP4) \
address of this server is not the same as the A-record ($DIG).
Please check your DNS settings! Maybe the domain hasn't propagated?
Please check https://www.whatsmydns.net/#A/${1} if the IP seems correct."

    msg_box "As you noticed your WAN IP and DNS record doesn't match. \
This can happen when using DDNS for example, or in other edge cases.
If you feel brave, or are sure that everything is set up correctly, \
then you can choose to skip this test in the next step.
If needed, you can always contact us for further support: \
https://shop.hanssonit.se/product/premium-support-per-30-minutes/"
        if ! yesno_box_no "Do you feel brave and want to continue?"
        then
            exit
        fi
    fi
}

# Install certbot (Let's Encrypt)
install_certbot() {
if certbot --version >/dev/null 2>&1
then
    # Reinstall certbot (use snap instead of package)
    # https://askubuntu.com/a/1271565
    if dpkg -l | grep certbot >/dev/null 2>&1
    then
        # certbot will be removed, but still listed, so we need to check if the snap is installed as well so that this doesn't run every time
        if ! snap list certbot >/dev/null 2>&1
        then
            print_text_in_color "$ICyan" "Reinstalling certbot (Let's Encrypt) as a snap instead..."
            apt-get remove certbot -y
            apt-get autoremove -y
            install_if_not snapd
            snap install core
            snap install certbot --classic
            # Update $PATH in current session (login and logout is required otherwise)
            check_command hash -r
        fi
    fi
else
    print_text_in_color "$ICyan" "Installing certbot (Let's Encrypt)..."
    install_if_not snapd
    snap install certbot --classic
    # Update $PATH in current session (login and logout is required otherwise)
    check_command hash -r
fi
}

# Generate certs and configure it automatically
# https://certbot.eff.org/docs/using.html#certbot-command-line-options
generate_cert() {
uir_hsts=""
if [ -z "$SUBDOMAIN" ]
then
    uir_hsts="--uir --hsts"
fi
a2dissite 000-default.conf
systemctl reload apache2.service
default_le="--cert-name $1 --key-type ecdsa --renew-by-default --no-eff-email --agree-tos $uir_hsts --server https://acme-v02.api.letsencrypt.org/directory -d $1"
#http-01
local  standalone="certbot certonly --standalone --pre-hook \"systemctl stop apache2.service\" --post-hook \"systemctl start apache2.service\" $default_le"
#tls-alpn-01
local  tls_alpn_01="certbot certonly --preferred-challenges tls-alpn-01 $default_le"
#dns
local  dns="certbot certonly --manual --manual-public-ip-logging-ok --preferred-challenges dns $default_le"
local  methods=(standalone dns)

for f in "${methods[@]}"
do
    print_text_in_color "${ICyan}" "Trying to generate certs and validate them with $f method."
    current_method=""
    eval current_method="\$$f"
    if eval "$current_method"
    then
        return 0
    elif [ "$f" != "${methods[$((${#methods[*]} - 1))]}" ]
    then
        msg_box "It seems like no certs were generated when trying \
to validate them with the $f method. We will retry."
    else
        msg_box "It seems like no certs were generated when trying \
to validate them with the $f method. We have exhausted all the methods. Please check your DNS and try again."
        return 1;
    fi
done
}

generate_desec_cert() {
# Check if the hook is in place
if [ ! -f "$SCRIPTS"/deSEC/hook.sh ]
then
    msg_box "Sorry, but it seems like the needed hook for this to work is missing.
No TLS will be generated. Please report this to $ISSUES."
    exit 1
fi

print_text_in_color "$ICyan" "Generating new TLS cert with DNS and deSEC, please don't abort the hook, it may take a while..."
# Renew with DNS by default
if certbot certonly --manual --text --key-type ecdsa --renew-by-default --server https://acme-v02.api.letsencrypt.org/directory --no-eff-email --agree-tos --preferred-challenges dns --manual-auth-hook "$SCRIPTS"/deSEC/hook.sh --manual-cleanup-hook "$SCRIPTS"/deSEC/hook.sh -d "$1"
then
    # Generate DHparams cipher
    if [ ! -f "$DHPARAMS_TLS" ]
    then
        openssl dhparam -out "$DHPARAMS_TLS" 2048
    fi
    # Choose which port for public access
    msg_box "You will now be able to choose which port you want to put your Jitsi on for public access.\n
The default port is 443 for HTTPS and if you don't change port, that's the port we will use.\n
Please keep in mind NOT to use the following ports as they are likely in use already:
${NONO_PORTS[*]}"
    if yesno_box_no "Do you want to change the default HTTPS port (443) to something else?"
    then
        # Ask for port
        while :
        do
            DEDYNPORT=$(input_box_flow "Please choose which port you want between 1024 - 49151.\n\nPlease remember to open this port in your firewall.")
            if (("$DEDYNPORT" >= 1024 && "$DEDYNPORT" <= 49151))
            then
                if check_nono_ports "$DEDYNPORT"
                then
                    print_text_in_color "$ICyan" "Changing to port $DEDYNPORT for public access..."
                    # Main port
                    if ! grep -q "Listen $DEDYNPORT" /etc/apache2/ports.conf
                    then
                        echo "Listen $DEDYNPORT" >> /etc/apache2/ports.conf
                        restart_webserver
                    fi
                    break
                fi
            else
                msg_box "The port number needs to be between 1024 - 49151, please try again."
            fi
        done
    fi
fi
}

# Last message depending on with script that is being run when using the generate_cert() function
last_fail_tls() {
    msg_box "All methods failed. :/
You can run the script again by executing: sudo bash $SCRIPTS/menu.sh
Please try to run it again some other time with other settings.
There are different configs you can try in Let's Encrypt's user guide:
https://letsencrypt.readthedocs.org/en/latest/index.html
Please check the guide for further information on how to enable TLS.
This script is developed on GitHub, feel free to contribute:
https://github.com/techandme/jitsi-vm/"

if [ -n "$2" ]
then
    msg_box "The script will now do some cleanup and revert the settings."
    # Cleanup
    snap remove certbot
    rm -f "$SCRIPTS"/test-new-config.sh
fi

# Restart webserver services
restart_webserver
}

# Use like this: open_port 443 TCP
# or e.g. open_port 3478 UDP
open_port() {
    install_if_not miniupnpc
    print_text_in_color "$ICyan" "Trying to open port $1 automatically..."
    if ! upnpc -a "$ADDRESS" "$1" "$1" "$2" &>/dev/null
    then
        msg_box "Failed to open port $1 $2 automatically. You have to do this manually."
        FAIL=1
    fi
}

cleanup_open_port() {
    if [ -n "$FAIL" ]
    then
        apt-get purge miniupnpc -y
        apt-get autoremove -y
    fi
}

# Check if port is open # check_open_port 443 domain.example.com
check_open_port() {
print_text_in_color "$ICyan" "Checking if port ${1} is open..."
install_if_not curl
# WAN Address
if check_command curl -s -H 'Cache-Control: no-cache' -H 'Referer: https://www.networkappers.com/tools/open-port-checker' "https://networkappers.com/api/port.php?ip=${WANIP4}&port=${1}" | grep -q "open"
then
    print_text_in_color "$IGreen" "Port ${1} is open on ${WANIP4}!"
elif check_command curl -s -H 'Cache-Control: no-cache' -H 'Referer: https://please-do-not-be-so-greedy-with-resources.now' 'https://ports.yougetsignal.com/check-port.php' --data "remoteAddress=${WANIP4}&portNumber=${1}" | grep -q "open"
then
    print_text_in_color "$IGreen" "Port ${1} is open on ${WANIP4}!"
# Domain name
elif check_command curl -s -H 'Cache-Control: no-cache' -H 'Referer: https://www.networkappers.com/tools/open-port-checker' "https://www.networkappers.com/api/port.php?ip=${2}&port=${1}" | grep -q "open"
then
    print_text_in_color "$IGreen" "Port ${1} is open on ${2}!"
elif check_command curl -s -H 'Cache-Control: no-cache' -H 'Referer: https://please-do-not-be-so-greedy-with-resources.now' 'https://ports.yougetsignal.com/check-port.php' --data "remoteAddress=${2}&portNumber=${1}" | grep -q "open"
then
    print_text_in_color "$IGreen" "Port ${1} is open on ${2}!"
else
    msg_box "It seems like the port ${1} is closed. This could happened when your
ISP has blocked the port, or the port isn't open.
If you are 100% sure the port ${1} is open, you can choose to
continue. There are no guarantees that it will work though,
since the service depends on port ${1} being open and
accessible from outside your network."
    if ! yesno_box_no "Are you 100% sure the port ${1} is open?"
    then
        msg_box "Port $1 is not open on either ${WANIP4} or ${2}.
Please follow this guide to open ports in your router or firewall:\nhttps://www.techandme.se/open-port-80-443/"
        any_key "Press any key to exit..."
        exit 1
    fi
fi
}

# Check if program is installed (is_this_installed apache2)
is_this_installed() {
if dpkg-query -W -f='${Status}' "${1}" | grep -q "ok installed"
then
    return 0
else
    return 1
fi
}

# Install_if_not program
install_if_not() {
if ! dpkg-query -W -f='${Status}' "${1}" | grep -q "ok installed"
then
    apt-get update -q4 & spinner_loading && RUNLEVEL=1 apt-get install "${1}" -y
fi
}

# Test RAM size
# Call it like this: ram_check [amount of min RAM in GB] [for which program]
# Example: ram_check 2 Jitsi
ram_check() {
install_if_not bc
# First, we need to check locales, since the functino depends on it.
# When we know the locale, we can then calculate mem available without any errors.
if locale | grep -c "C.UTF-8"
then
    mem_available="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
    mem_available_gb="$(LC_NUMERIC="C.UTF-8" printf '%0.2f\n' "$(echo "scale=3; $mem_available/(1024*1024)" | bc)")"
elif locale | grep -c "en_US.UTF-8"
then
    mem_available="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
    mem_available_gb="$(LC_NUMERIC="en_US.UTF-8" printf '%0.2f\n' "$(echo "scale=3; $mem_available/(1024*1024)" | bc)")"
fi

# Now check required mem
mem_required="$((${1}*(924*1024)))" # 100MiB/GiB margin and allow 90% to be able to run on physical machines
if [ "${mem_available}" -lt "${mem_required}" ]
then
    print_text_in_color "$IRed" "Error: ${1} GB RAM required to install ${2}!" >&2
    print_text_in_color "$IRed" "Current RAM is: ($mem_available_gb GB)" >&2
    sleep 3
    msg_box "** Error: insufficient memory. ${mem_available_gb}GB RAM installed, ${1}GB required.
To bypass this check, comment out (add # before the line) 'ram_check X' in the script that you are trying to run.
Please note this may affect performance. USE AT YOUR OWN RISK!"
    exit 1
else
    print_text_in_color "$IGreen" "RAM for ${2} OK! ($mem_available_gb GB)"
fi
}

# Test number of CPU
# Call it like this: cpu_check [amount of min CPU] [for which program]
# Example: cpu_check 2 Jitsi
cpu_check() {
nr_cpu="$(nproc)"
if [ "${nr_cpu}" -lt "${1}" ]
then
    print_text_in_color "$IRed" "Error: ${1} CPU required to install ${2}!" >&2
    print_text_in_color "$IRed" "Current CPU: ($((nr_cpu)))" >&2
    sleep 3
    exit 1
else
    print_text_in_color "$IGreen" "CPU for ${2} OK! ($((nr_cpu)))"
fi
}

check_command() {
if ! "$@";
then
    print_text_in_color "$ICyan" "Sorry but something went wrong. Please report \
this issue to $ISSUES and include the output of the error message. Thank you!"
    print_text_in_color "$IRed" "$* failed"
    exit 1
fi
}

# Whiptail auto-size
calc_wt_size() {
    WT_HEIGHT=17
    WT_WIDTH=$(tput cols)

    if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
        WT_WIDTH=80
    fi
    if [ "$WT_WIDTH" -gt 178 ]; then
        WT_WIDTH=120
    fi
    WT_MENU_HEIGHT=$((WT_HEIGHT-7))
    export WT_MENU_HEIGHT
}

spinner_loading() {
    printf '['
    while ps "$!" > /dev/null; do
        echo -n '⣾⣽⣻'
        sleep '.7'
    done
    echo ']'
}

# Check universe repository
check_universe() {
UNIV=$(apt-cache policy | grep http | awk '{print $3}' | grep universe | head -n 1 | cut -d "/" -f 2)
if [ "$UNIV" != "universe" ]
then
    print_text_in_color "$ICyan" "Adding required repo (universe)."
    add-apt-repository universe
fi
}

# countdown 'message looks like this' 10
countdown() {
print_text_in_color "$ICyan" "$1"
secs="$(($2))"
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}

print_text_in_color() {
printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}

version(){
    local h t v

    [[ $2 = "$1" || $2 = "$3" ]] && return 0

    v=$(printf '%s\n' "$@" | sort -V)
    h=$(head -n1 <<<"$v")
    t=$(tail -n1 <<<"$v")

    [[ $2 != "$h" && $2 != "$t" ]]
}

version_gt() {
    local v1 v2 IFS=.
    read -ra v1 <<< "$1"
    read -ra v2 <<< "$2"
    printf -v v1 %03d "${v1[@]}"
    printf -v v2 %03d "${v2[@]}"
    [[ $v1 > $v2 ]]
}

add_trusted_key_and_repo() {
    # EXAMPLE: add_trusted_key_and_repo "jcameron-key.asc" \
    # "https://download.webmin.com" \
    # "https://download.webmin.com/download/repository" \
    # "sarge contrib" \
    # "webmin-test.list"

    # $1 = whatever.asc
    # $2 = Key URL e.g. https://download.webmin.com
    # $3 = Deb URL e.g. https://download.webmin.com/download/repository
    # $4 = "$CODENAME $CODENAME main" (e.g. jammy jammy main)
    # $5 = debpackage-name.list

    # This function is only supported in the currently supported release
    check_distro_version

    # Do the magic
    if version 22.04 "$DISTRO" 22.04.10
    then
        # New recommended way not using apt-key
        print_text_in_color "$ICyan" "Adding trusted key in /etc/apt/keyrings/$1..."
        curl -sL "$2"/"$1" | tee -a /etc/apt/keyrings/"$1"
        echo "deb [signed-by=/etc/apt/keyrings/$1] $3 $4" > "/etc/apt/sources.list.d/$5"
        apt-get update -q4 & spinner_loading
    elif version 20.04 "$DISTRO" 20.04.10
    then
        # Legacy way with apt-key
        print_text_in_color "$ICyan" "Adding trusted key with apt-key..."
        curl -sL "$2"/"$1" | apt-key add -
        echo "deb $3 $4" > "/etc/apt/sources.list.d/$5"
        apt-get update -q4 & spinner_loading
    fi
}

# call like: download_script folder_variable name_of_script
# e.g. download_script MENU additional_apps
# Use it for functions like download_static_script
download_script() {
    download_script_function_in_use=yes
    rm -f "${SCRIPTS}/${2}.sh" "${SCRIPTS}/${2}.php" "${SCRIPTS}/${2}.py"
    if ! { curl_to_dir "${!1}" "${2}.sh" "$SCRIPTS" || curl_to_dir "${!1}" "${2}.php" "$SCRIPTS" || curl_to_dir "${!1}" "${2}.py" "$SCRIPTS"; }
    then
        print_text_in_color "$IRed" "Downloading ${2} failed"
        sleep 2
        msg_box "Script failed to download. Please run: \
'sudo curl -sLO ${!1}/${2}.sh|php|py' and try again.
If it still fails, please report this issue to: $ISSUES."
        exit 1
    fi
}

# call like: run_script folder_variable name_of_script
# e.g. run_script MENU additional_apps
# Use it for functions like run_script STATIC
run_script() {
    rm -f "${SCRIPTS}/${2}.sh" "${SCRIPTS}/${2}.php" "${SCRIPTS}/${2}.py"
    if download_script "${1}" "${2}"
    then
        if [ -f "${SCRIPTS}/${2}".sh ]
        then
            bash "${SCRIPTS}/${2}.sh"
            rm -f "${SCRIPTS}/${2}.sh"
        elif [ -f "${SCRIPTS}/${2}".php ]
        then
            php "${SCRIPTS}/${2}.php"
            rm -f "${SCRIPTS}/${2}.php"
        elif [ -f "${SCRIPTS}/${2}".py ]
        then
            install_if_not python3
            python3 "${SCRIPTS}/${2}.py"
            rm -f "${SCRIPTS}/${2}.py"
        fi
    else
        print_text_in_color "$IRed" "Running ${2} failed"
        sleep 2
        msg_box "Script failed to execute. Please run: \
'sudo curl -sLO ${!1}/${2}.sh|php|py' and try again.
If it still fails, please report this issue to: $ISSUES."
        exit 1
    fi
}

curl_to_dir() {
if [ ! -d "$3" ]
then
    mkdir -p "$3"
fi
    rm -f "$3"/"$2"
    if [ -n "$download_script_function_in_use" ]
    then
        curl -sfL "$1"/"$2" -o "$3"/"$2"
    else
        local retries=0
        while :
        do
            if [ "$retries" -ge 10 ]
            then
                if yesno_box_yes "Tried 10 times but didn't succeed. We will now exit the script because it might break things. You can choose 'No' to continue on your own risk."
                then
                    exit 1
                else
                    return 1
                fi
            fi
            if ! curl -sfL "$1"/"$2" -o "$3"/"$2"
            then
                msg_box "We just tried to fetch '$1/$2', but it seems like the server for the download isn't reachable, or that a temporary error occurred. We will now try again.
Please report this issue to $ISSUES"
                retries=$((retries+1))
                print_text_in_color "$ICyan" "$retries of 10 retries."
                countdown "Trying again in 30 seconds..." "30"
            else
                break
            fi
        done
    fi
}



## bash colors
# Reset
Color_Off='\e[0m'       # Text Reset

# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White

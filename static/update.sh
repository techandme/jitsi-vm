#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

true
SCRIPT_NAME="Update Server + Jitsi"
# shellcheck source=lib.sh
source <(curl -sL https://raw.githubusercontent.com/techandme/jitsi-vm/main/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

mkdir -p "$SCRIPTS"

# Delete, download, run
run_script STATIC jitsi_update

exit

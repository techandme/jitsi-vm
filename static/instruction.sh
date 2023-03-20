#!/bin/bash

# T&M Hansson IT AB © - 2023, https://www.hanssonit.se/

BIGreen='\e[1;92m'      # Green
IGreen='\e[0;92m'       # Green
Color_Off='\e[0m'       # Text Reset

clear
cat << INST1
+-----------------------------------------------------------------------+
|      Welcome to the first setup of your own Jitsi Server! :)          |
|                                                                       |
INST1
echo -e "|"  "${IGreen}To run the startup script type the sudoer password, then hit [ENTER].${Color_Off} |"
echo -e "|"  "${IGreen}The default sudoer password is: ${BIGreen}jitsi${IGreen}${Color_Off}                                 |"
cat << INST2
|                                                                       |
| You can find the complete install instructions here:                  |
| Jitsi VM              = https://bit.ly/2S8eGfS                        |
|                                                                       |
| Optional:                                                             |
| If you are running Windows 10 (1809) or later, you can simply use SSH |
| from the command prompt. You can also use Putty, download it here:    |
| https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html        |
| Connect like this: ssh ncadmin@local.IP.of.this.server                |
|                                                                       |
|  ###################### T&M Hansson IT - $(date +"%Y") ######################  |
+-----------------------------------------------------------------------+
INST2

exit 0

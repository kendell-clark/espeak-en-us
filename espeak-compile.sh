#!/bin/bash
## Install updated en-us specific updates for espeak.
## If you encouner problems with this script, please contact me at
## B.H. <es_vinux@vinuxproject.org>
## The latest proposed updates to the en-us voice can be cloned from
## git://github.com/coffeeking/espeak-en-us.

## What is our archetecture?
ARCH="$(uname -m|sed 's/x86_//;s/i[3-6]86/32/')"
if [[ ${ARCH} = +(32|64) ]]; then
ARCH="$ARCH"
else
echo "You may be using an unsupported archetecture.
Only x86_64 or i*86 archetecture is supported by this script in some distros."
fi 

## What distro are we running on?
if [ -f /etc/lsb-release ]; then
DISTRO="$(lsb_release -is)"
else
sudo install -m 755 ./lsb_release /usr/bin/ && DISTRO="$(lsb_release -is)"
fi

if [[ ${DISTRO} = +(Manjaro|Arch) ]]; then
Path="/usr/share/"
elif [[ ${DISTRO} = +(Ubuntu|Debian) ]]; then
if [ "$ARCH" = "64" ]; then
Path="/usr/lib/x86_64-linux-gnu/"
elif [ "$ARCH" = "32" ]; then
Path="/usr/lib/i386-linux-gnu/"
else
echo "Your archetecture isunsupported by this script at this time."
exit 1
     fi
     else
Path="/usr/share/"
echo "I do not know the default location for espeak-data installation
for your distro, so the standard installation path /usr/share will be tried.
If the script exits with out installing the updated files,
please email me the distro you use and the path to espeak-data it uses."
     fi

## Do not start script as root cause it can mess up read/write perms
if [[ $(whoami) == "root" ]]; then
echo "this script should not be initiated as root.
 It will copy files using sudo, prompting for passwords when needed."
     exit 2
fi

#check for updates, or clone git repo if it does not exist.
#make sure all required files and directories are present
if [ -d ./espeak-en-us ]; then
cd ./espeak-en-us/ && git pull
else
if ! [ -d ../espeak-en-us ]; then
git clone git://github.com/coffeeking/espeak-en-us
cd ./espeak-en-us/
echo "The espeak-en-us repo has been cloned in to ${PWD}."
else
git pull
fi
fi
 
#make sure all required files are present
     if [ ! -f "en_extra" -o ! -f "en_list" -o ! -f "en_rules" -o ! -f "en_listx" ]; then
echo "Required files are missing. There appears to have been a problem pulling from git.
Check your internet connection and try running this script again.
     exiting."
exit 3
fi

if [ ! -d "${Path}espeak-data/" ] ; then
echo "Destination directory missing, exiting."
exit 4
fi

## Tell the user what is required and what is about to be done.
echo
echo "Updates are about to be aplied to the U.S. English espeak voice.
${Path} will be used as the espeak-data directory.
 You will need a very recent espeak or espeak-ng version for the updates
 to compile and work properly, so if you need to update your espeak
 or make any other changes, you should exit this installer now."
echo
read -p 'Press y or Y to continue; any other key to exit.
' ConTNU
     if [[ ${ConTNU} != +(y|Y) ]]; then
echo "Exiting espeak-compile.sh:"
exit 0
     fi
    
## Root permissions are required to proceed.
echo "Copying files:"
## Copy files to espeak directory
sudo cp ./en_* ${Path}espeak-data/
## Change to espeak-data directory and compile
cd ${Path}espeak-data/
sudo espeak --compile=en-us
echo "Files Updated!"
echo
serviceName="$(systemctl --no-pager --all | grep -E espeakup.*service | cut -d " " -f3)"
if [ -n "$serviceName" ]; then
    read -n 1 -p "Restart $serviceName? " restart
    if [ "${restart^}" == "Y" ]; then
        sudo systemctl restart $serviceName
    fi
else
echo "Restart any daemons or services that are using espeak,
 or reboot your system for changes to take effect."
     fi
echo
exit 0

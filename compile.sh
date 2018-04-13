#!/bin/bash

# Get espeak path:
distroName="$(uname -r | rev | cut -d - -f1 | rev))"
# for distros that put stuff in different places, set the Path variable here:
case "$distroName" in
*)
Path="/usr/share/espeak-ng-data"
esac
## Install updated ## Root permissions are required to proceed.
echo "Copying files:"
## Copy files to espeak directory
sudo cp ./en_* ${Path}/
sudo cp -rf ./phsource ${Path}/
sudo cp en-US ${Path}/
#copy french rules
sudo cp fr_* ${Path}/
## Change to espeak-data directory and compile
cd $Path
sudo espeak --compile=en-us
sudo espeak --compile-phonemes=phsource
sudo espeak --compile=fr
if [ $? -eq 0 ]; then
echo "Files Updated!"
else
echo "Compilation failed, exiting..."
exit 1
fi
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

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
## Change to espeak-data directory and compile
cd $Path
sudo espeak-ng --compile=en-us
if [ $? -eq 0 ]; then
echo "Files Updated!"
else
echo "Compilation failed, exiting..."
exit 1
fi


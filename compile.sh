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
sudo espeak-ng --compile=en-us
sudo espeak-ng --compile-phonemes=phsource
sudo espeak-ng --compile=fr
if [ $? -eq 0 ]; then
echo "Files Updated!"
else
echo "Compilation failed, exiting..."
exit 1
fi


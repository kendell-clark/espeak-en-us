#!/bin/bash
# Compile custom eSpeak dictionary safely

# Set eSpeak data path
ESPEAK_PATH="/usr/share/espeak-ng-data"

# List of files to copy, in order
# en_extra goes last to take precedence
FILES_TO_COPY=("en_list" "en_rules" "en_emoji" "en_extra")

echo "Copying files to $ESPEAK_PATH..."
for f in "${FILES_TO_COPY[@]}"; do
    if [[ -f $f ]]; then
        echo "Copying $f..."
        sudo cp "$f" "$ESPEAK_PATH/"
    else
        echo "Warning: $f not found, skipping..."
    fi
done

# Compile en-us voice
cd "$ESPEAK_PATH" || { echo "Failed to cd to $ESPEAK_PATH"; exit 1; }
echo "Compiling en-us..."
sudo espeak-ng --compile=en-us
if [[ $? -eq 0 ]]; then
    echo "Compilation successful! Files are updated."
else
    echo "Compilation failed, exiting..."
    exit 1
fi

#!/bin/bash
# Compile custom eSpeak dictionary safely with automatic speech-dispatcher, Orca reload, and logging
# Cross-distro support (Fedora, Ubuntu, etc.)

# =====================
# Optional path override
# =====================
if [[ -n "$1" ]]; then
    ESPEAK_PATH="$1"
    if [[ ! -d "$ESPEAK_PATH" ]]; then
        echo "Provided path $ESPEAK_PATH does not exist."
        exit 1
    fi
fi

# =====================
# Detect eSpeak-ng data path if not overridden
# =====================
if [[ -z "$ESPEAK_PATH" ]]; then
    COMMON_PATHS=(
        "/usr/share/espeak-ng-data"
        "/usr/local/share/espeak-ng-data"
        "/usr/share/espeak-data"
        "/usr/local/share/espeak-data"
        "/usr/lib/x86_64-linux-gnu/espeak-ng-data"  # Ubuntu 64-bit multiarch
        "/usr/lib64/espeak-ng-data"                  # Older/custom builds
    )

    for path in "${COMMON_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            ESPEAK_PATH="$path"
            break
        fi
    done

    if [[ -z "$ESPEAK_PATH" ]]; then
        echo "Could not detect eSpeak-ng data path. Provide it as an argument or adjust COMMON_PATHS."
        exit 1
    fi
fi

echo "Using eSpeak data path: $ESPEAK_PATH"

# =====================
# Copy dictionary files (merge order: en_extra last to override)
# =====================
FILES_TO_COPY=("en_list" "en_rules" "en_emoji" "en_extra")  # en_extra last

echo "Copying files..."
for f in "${FILES_TO_COPY[@]}"; do
    if [[ -f $f ]]; then
        echo "Copying $f..."
        sudo cp "$f" "$ESPEAK_PATH/"
    else
        echo "Warning: $f not found, skipping..."
    fi
done

# =====================
# Compile en-us voice
# =====================
cd "$ESPEAK_PATH" || { echo "Failed to cd to $ESPEAK_PATH"; exit 1; }
echo "Compiling en-us..."
sudo espeak-ng --compile=en-us
if [[ $? -ne 0 ]]; then
    echo "Compilation failed, exiting..."
    exit 1
fi
echo "Compilation successful! Files are updated."

# =====================
# Reload speech-dispatcher
# =====================
echo "Reloading speech-dispatcher..."
if command -v systemctl &>/dev/null && systemctl --user list-units | grep -q speech-dispatcher; then
    systemctl --user restart speech-dispatcher
    if [[ $? -eq 0 ]]; then
        echo "speech-dispatcher restarted successfully via systemd."
    else
        echo "Failed to restart speech-dispatcher via systemd."
    fi
else
    # Fallback: kill any running speech-dispatcher process manually
    SD_PIDS=$(pgrep -u "$USER" -f speech-dispatcher)
    if [[ -n "$SD_PIDS" ]]; then
        echo "Killing running speech-dispatcher processes: $SD_PIDS"
        kill -TERM $SD_PIDS
        sleep 1
        echo "speech-dispatcher stopped. It will restart automatically on next TTS call."
    else
        echo "No running speech-dispatcher process found."
    fi
fi

# =====================
# Restart Orca completely
# =====================
echo "Restarting Orca to pick up updated eSpeak-ng pronunciations..."
ORCA_PIDS=$(pgrep -u "$USER" -f orca)
if [[ -n "$ORCA_PIDS" ]]; then
    echo "Stopping running Orca processes: $ORCA_PIDS"
    kill -TERM $ORCA_PIDS
    sleep 1
fi
echo "Starting Orca..."
orca -r &
sleep 2
echo "Orca restarted. New pronunciations should now be active."

# =====================
# Logging
# =====================
LOG_FILE="$HOME/.espeak_compile.log"
if [[ ! -f "$LOG_FILE" ]]; then
    echo "eSpeak-ng compilation log - $HOME/.espeak_compile.log" > "$LOG_FILE"
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - Compiled en-us with files: ${FILES_TO_COPY[*]} at $ESPEAK_PATH" >> "$LOG_FILE"
echo "Compile logged to $LOG_FILE"


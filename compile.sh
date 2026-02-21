# =====================
# Restart Orca completely
# =====================
echo "Restarting Orca to pick up updated eSpeak-ng pronunciations..."
ORCA_PIDS=$(pgrep -u "$USER" -f orca)
if [[ -n "$ORCA_PIDS" ]]; then
    echo "Stopping running Orca processes: $ORCA_PIDS"
    kill -TERM $ORCA_PIDS
    sleep 1
    echo "Starting Orca..."
    orca -r &
    sleep 2
    echo "Orca restarted. New pronunciations should now be active."
else
    echo "Orca is not running, starting it..."
    orca -r &
    sleep 2
    echo "Orca started."
fi

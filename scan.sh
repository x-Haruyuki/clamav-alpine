#!/bin/bash
set -euo pipefail

echo ""
echo -e "$( date -I'seconds' ) ClamAV process starting"
echo ""
echo -e "Updating ClamAV scan DB"
echo ""

set +e
freshclam
FRESHCLAM_EXIT=$?
MODE="${MODE:-scan}"

set -e
if [[ "$FRESHCLAM_EXIT" -eq "0" ]]; then
    echo ""
    echo -e "Freshclam updated the DB"
    echo ""
elif [[ "$FRESHCLAM_EXIT" -eq "1" ]]; then
    echo ""
    echo -e "ClamAV DB already up to date..."
    echo ""
else
    echo ""
    echo -e "An error occurred (freshclam returned with exit code '$FRESHCLAM_EXIT')"
    echo ""
    exit $FRESHCLAM_EXIT
fi

if [ "$MODE" = "server" ]; then
    echo "[clam-av] Configuring clamd TCP port..."
    sed -i '/^TCPSocket/d' /etc/clamav/clamd.conf
    echo "TCPSocket ${CLAMD_TCP_PORT:-3310}" >> /etc/clamav/clamd.conf

    echo "[clam-av] Configuring clamd TCP addr..."
    sed -i '/^TCPAddr/d' /etc/clamav/clamd.conf
    echo "TCPAddr ${CLAMD_TCP_ADDR:-0.0.0.0}" >> /etc/clamav/clamd.conf

    echo "[clam-av] Starting in server mode..."
    exec clamd -c /etc/clamav/clamd.conf

elif [ "$MODE" = "scan" ]; then
    clamscan -V
    echo ""
    echo -e "Scanning $SCANDIR"
    echo ""

    FILE_COUNT=$(find "$SCANDIR" -type f | wc -l)

    if command -v pv >/dev/null 2>&1; then
        echo "[clam-av] Found $FILE_COUNT files, scanning with progress bar..."

        TMP_FIFO=$(mktemp -u)
        mkfifo "$TMP_FIFO"

        # clamscan liest aus der Pipe
        clamscan --file-list="$TMP_FIFO" "$@" &
        CLAM_PID=$!

        # pv schickt Dateien in die Pipe
        find "$SCANDIR" -type f \
            | pv -l -s "$FILE_COUNT" -p -t -e -N files > "$TMP_FIFO"

        wait $CLAM_PID
        rm -f "$TMP_FIFO"
    else
        echo "[clam-av] pv not installed, running without progress bar..."
        clamscan -r "$SCANDIR" "$@"
    fi

    echo ""
    echo -e "$( date -I'seconds' ) ClamAV scanning finished"

else
    echo -e "MODE not selected. Use MODE=scan or MODE=server"
fi

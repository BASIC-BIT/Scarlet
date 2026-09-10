#!/bin/sh
# Tells a human when the Scarlet container is not running. `restart: on-failure:5`
# correctly never restarts a clean exit 0, so without this nothing notices.
# Install as root cron on the host. See docs/ALARM.md.
set -eu

CURLRC=/etc/scarlet-alarm.curlrc
STATE_DIR=/var/lib/scarlet-alarm
STATE=$STATE_DIR/down

[ -r "$CURLRC" ] || { echo "scarlet-alarm: cannot read $CURLRC" >&2; exit 2; }
install -d -m 700 -o root -g root "$STATE_DIR"

# The webhook URL comes from the curl config file, so it never reaches argv and
# never shows up in `ps`. This returns curl's exit status on purpose: the caller
# only moves the marker when the message actually went out.
post() {
    curl -sS -f --max-time 10 -K "$CURLRC" \
        -H 'Content-Type: application/json' \
        -d "{\"content\":\"$1\"}" >/dev/null 2>&1
}

running=$(docker inspect scarlet --format '{{.State.Running}}' 2>/dev/null || echo false)

if [ "$running" != "true" ] && [ ! -e "$STATE" ]; then
    detail=$(docker inspect scarlet \
        --format 'exit code {{.State.ExitCode}}, finished at {{.State.FinishedAt}}' \
        2>/dev/null || echo 'no container found')
    post "Scarlet bot is down on $(hostname): $detail" && : > "$STATE"
elif [ "$running" = "true" ] && [ -e "$STATE" ]; then
    post "Scarlet bot is running again on $(hostname)." && rm -f "$STATE"
fi

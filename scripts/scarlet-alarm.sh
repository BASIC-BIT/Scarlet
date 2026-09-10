#!/bin/sh
# Tells a human when the Scarlet container is not running. `restart: on-failure:5`
# correctly never restarts a clean exit 0, so without this nothing notices.
# Install as root cron on the host. See docs/ALARM.md.
set -eu

ENV_FILE=/etc/scarlet-alarm.env
STATE=/var/tmp/scarlet-alarm.down

[ -r "$ENV_FILE" ] || { echo "scarlet-alarm: cannot read $ENV_FILE" >&2; exit 2; }
. "$ENV_FILE"
[ -n "${SCARLET_ALARM_WEBHOOK:-}" ] || {
    echo "scarlet-alarm: SCARLET_ALARM_WEBHOOK is not set in $ENV_FILE" >&2
    exit 2
}

post() {
    curl -sS --max-time 10 -H 'Content-Type: application/json' \
        -d "{\"content\":\"$1\"}" "$SCARLET_ALARM_WEBHOOK" >/dev/null 2>&1 || true
}

running=$(docker inspect scarlet --format '{{.State.Running}}' 2>/dev/null || echo false)

if [ "$running" != "true" ] && [ ! -e "$STATE" ]; then
    detail=$(docker inspect scarlet \
        --format 'exit code {{.State.ExitCode}}, finished at {{.State.FinishedAt}}' \
        2>/dev/null || echo 'no container found')
    post "Scarlet bot is down on $(hostname): $detail"
    : > "$STATE"
elif [ "$running" = "true" ] && [ -e "$STATE" ]; then
    post "Scarlet bot is running again on $(hostname)."
    rm -f "$STATE"
fi

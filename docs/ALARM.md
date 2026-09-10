# Alarm

`restart: on-failure:5` in `docker-compose.yml` does not restart a container that
exits 0, which is correct: a clean exit is not a failure. Nothing else watches the
container, so a human has to be told, and that is what `scripts/scarlet-alarm.sh`
does. It posts to a Discord webhook when the container stops running, and again
when it comes back. The host has no mail transport, so the webhook is the channel.

The webhook URL lives in a curl config file at `/etc/scarlet-alarm.curlrc`. The
whole file is one line:

```
url = "https://discord.com/api/webhooks/<id>/<token>"
```

Create it as root, `chmod 600`, and keep it out of this repository. It holds a
credential. curl reads it with `-K`, so the URL never appears on the command line
and never shows up in `ps` output for the seconds the request takes.

Install the script as a root-owned copy outside the checkout:

```
install -o root -g root -m 755 scripts/scarlet-alarm.sh /usr/local/sbin/scarlet-alarm
```

Root cron must never execute a file that a non-root user can write. `/home/basic/Scarlet`
is owned by `basic`, so running the script from the checkout would let anything
that can write as `basic` run arbitrary code as root on the next tick. The copy in
`/usr/local/sbin` is root-owned and root-writable only. The repository copy is the
source of truth: re-run the `install` command after any change to the script, or
the host keeps running the old one.

Run it from root cron every five minutes:

```
*/5 * * * * root /usr/local/sbin/scarlet-alarm
```

Both steps are manual and happen on the host after this merges. Merging changes
nothing on its own. The script needs root to read the curl config, to write its
state directory, and to reach the Docker socket, so install the crontab line as
root, in `/etc/crontab` or a file under `/etc/cron.d/` (the `root` field above is
the crontab format used there, not a user crontab).

The script alerts once per down episode. The marker is `/var/lib/scarlet-alarm/down`,
in a `0700` root-owned directory the script creates on each run. `/var/tmp` was the
wrong home for it: it is world-writable, so anyone on the host could create the
marker and silence the alarm, or delete it and cause a repeat alert every five
minutes. Delete the marker by hand if you want the next run to alert again.

The marker only moves after a delivery succeeds. `curl -f` makes an HTTP 4xx or 5xx
a failure, so a Discord outage or a rate limit leaves the state as it was and the
next tick tries again. The old version treated a dropped message as a delivered one
and went quiet for the rest of the outage.

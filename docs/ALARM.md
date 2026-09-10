# Alarm

`restart: on-failure:5` in `docker-compose.yml` does not restart a container that
exits 0, which is correct: a clean exit is not a failure. Nothing else watches the
container, so a human has to be told, and that is what `scripts/scarlet-alarm.sh`
does. It posts to a Discord webhook when the container stops running, and again
when it comes back. The host has no mail transport, so the webhook is the channel.

The script reads one variable from `/etc/scarlet-alarm.env`. The whole file is one
line:

```
SCARLET_ALARM_WEBHOOK=https://discord.com/api/webhooks/<id>/<token>
```

That file holds a credential. Create it as root, `chmod 600`, and keep it out of
this repository.

Run the script from root cron every five minutes:

```
*/5 * * * * root /home/basic/Scarlet/scripts/scarlet-alarm.sh
```

Both steps are manual and happen on the host after this merges. Merging changes
nothing on its own. The script needs root to read the env file and to reach the
Docker socket, so install the crontab line as root, in `/etc/crontab` or a file
under `/etc/cron.d/` (the `root` field above is the crontab format used there, not
a user crontab).

The script alerts once per down episode. It uses `/var/tmp/scarlet-alarm.down` as
the marker, creating it with the first alert and removing it on recovery. Delete
that file by hand if you want the next run to alert again.

# Services

## Vaultwarden

### Features

- daily backups
- supports websockets
- supports emails
- invite only
- paid features (orgs/OTP/etc)
- secret config at `etc/default/vaultwarden`

### how to restore from backup

[official docs](https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault#restoring-backup-data)

- untar the tar for date you want to restore from
- stop vaultwarden service
- `sudo su`
- cd to the vaultwarden data directory `/var/lib/vaultwarden`
- remove all files in the data directory
- copy the files from the tar to the data directory `cp -r /path/to/backup/* /var/lib/vaultwarden`
- chown the files to the vaultwarden user `chown -R vaultwarden:vaultwarden /var/lib/vaultwarden`
- start the vaultwarden service and verify things are working as expected
- Caddy failover is automatic; no proxy edit is normally required

### automatic read-only failover

The reusable `modules/vaultwarden-replication.nix` module gives a node either a
`master` or `standby` role. Archive directory paths are shared through named
constants so the master destinations and standby storage cannot drift, while
roles, hostnames, ports, and Caddy ordering remain explicit in their host
configurations. `home-server-1` is the master. It atomically ships a rolling
snapshot to `bduggan-desktop` and `arden` every hour, retains timestamped hourly
snapshots for 48 hours, and separately keeps and ships a timestamped long-term
archive once per day. `bduggan-framework` receives the backup files but does not
run Vaultwarden or participate in Caddy failover. It is an optional destination,
so backups continue normally while the laptop is asleep or offline.

Upload failures are best-effort: every destination is attempted even if an
earlier one is unavailable. Required destination failures mark the hourly job
failed for visibility, but do not prevent creation of a fresh daily archive.

Both standbys check their rolling snapshot every five minutes, validate its
SQLite database, and restore it into Vaultwarden on port 8222. Their database
files are not writable by the Vaultwarden user, and the entire data directory is
also mounted read-only inside the service, so neither can become a second
writable copy.

Caddy on `digdugdev` prefers `home-server-1`, then `bduggan-desktop`, then
`arden`, and automatically moves down that list when a node fails its health
check. The standby web vault shows a persistent warning that it is an emergency,
read-only copy. Writes from web, desktop, and mobile clients fail while a standby
is active.

Failback is automatic once `home-server-1` passes Caddy's health check again.
There is no reverse database sync because the standby cannot accept changes.

Deploy the standby configurations before the master so their upload directories
exist before the first replication run.

## Grafana

Secret config at `etc/default/grafana`

## Open Web UI / LiteLLM

This server facilitates LLM usage via lite llm. This points to all the services I want to expose
and controls keys and limits to anyone using my services. The main use right now is open web ui which exposes a chatgpt like interface over the internet so I can provide access to friends and family to LLMs I run within my tailnet on various servers.

## n8n meeting transcript ingestion

TranscriptTonic webhook to https://n8n.digdug.dev/webhook/abb342bd-72d7-4676-8bce-f36a6786eeeb will put the transcript file in my obsidan vault

### features

- alerting (email)
- greenhouse metrics and alerts
- memory usage alerts

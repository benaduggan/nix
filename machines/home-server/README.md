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
- cd to the vaultwarden data directory `/var/lib/bitwarden_rs`
- remove all files in the data directory
- copy the files from the tar to the data directory `cp -r /path/to/backup/* /var/lib/bitwarden_rs`
- chown the files to the vaultwarden user `chown -R vaultwarden:vaultwarden /var/lib/bitwarden_rs`
- start the vaultwarden service and verify things are working as expected
- swap out the caddy entry on digdugdev

## Grafana

Secret config at `etc/default/grafana`

## Open Web UI / LiteLLM

This server facilitates LLM usage via lite llm. This points to all the services I want to expose
and controls keys and limits to anyone using my services. The main use right now is open web ui which exposes a chatgpt like interface over the internet so I can provide access to friends and family to LLMs I run within my tailnet on various servers.

### features

- alerting (email)
- greenhouse metrics and alerts
- memory usage alerts

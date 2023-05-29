# Services

## Vaultwarden

### Features
- daily backups
- supports websockets
- supports emails
- invite only
- paid features (orgs/OTP/etc)

### how to restore from backup

[official docs](https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault#restoring-backup-data)

- stop vaultwarden service
- cp the tar for date you want to restore from: `/etc/vault/backups` -> `/var/lib/bitwarden_rs`
- unzip and mv all files into the data directory
- start the vaultwarden service and verify

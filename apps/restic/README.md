# restic

[restic](https://restic.net/) -- encrypted, deduplicated backups. This is the
operational runbook for the batdots restic setup.

## files

| File            | Purpose                                            |
| --------------- | -------------------------------------------------- |
| `restic_ignore` | exclude patterns shared by every backup invocation |
| `README.md`     | this runbook                                       |

## configuration

Secrets and machine-specific values live in `local/env.sh` (gitignored) -- never
in tracked code. The backup scripts are driven by `DOTFILES_RESTIC_*` variables:

```bash
# in local/env.sh
export DOTFILES_RESTIC_REPOS=( "rclone:gdrive:BackupFolder" "/media/usb/restic" )
export DOTFILES_RESTIC_BACKUP_PATHS=( "$HOME/Documents" "$HOME/Pictures" )
export DOTFILES_RESTIC_PASS_FILE="${DOTFILES_ROOT}/local/restic_pass"
```

The repo password is **never** committed. Create the password file once:

```bash
printf '%s\n' 'your-strong-password' > local/restic_pass
chmod 600 local/restic_pass
```

`apps/bash/profile.d/restic.sh` defaults `RESTIC_PASSWORD_FILE` to
`local/restic_pass`, so ad-hoc `restic ...` commands work without extra setup.

## sanity checks

```bash
restic snapshots                       # recent snapshots exist, dates look right
restic check                           # repo integrity
restic stats latest                    # size / file count of the latest snapshot
./scripts/user/restic-test-restore.sh  # end-to-end "can I actually restore?" proof
```

restic has no native backend for personal Google Drive (it only supports Google
Cloud Storage), so [rclone](https://rclone.org/) acts as a bridge: rclone
handles the Google Drive connection, restic handles encryption and
deduplication.

## installing dependencies

```bash
sudo apt update && sudo apt install restic rclone
```

## configuring rclone

```bash
rclone config
```

1. Type `n` to create a **n**ew remote. Name it something simple, like `gdrive`,
   and hit Enter.
2. You will see a long list of cloud storage providers. Look for Google Drive
   (usually number 18 or 19, but check the list to be sure) and type that
   number.
3. Client ID and Client Secret: leave these completely blank and just hit Enter
   for both.
4. Scope: type `1` (Full access to all files).
5. Service Account Credentials: leave blank and hit Enter.
6. Advanced Config: type `n` for No.
7. Web Browser Authentication: type `y` for Yes. A browser window pops up asking
   you to log into your Google account and grant rclone permission.

Once authorized, go back to the terminal, confirm the settings with `y`, then
`q` to quit the config menu.

## configuring restic

### first-time setup

Create an encrypted vault in Google Drive called `BackupFolder`:

```bash
restic -r rclone:gdrive:BackupFolder init
```

### if the vault already exists

```bash
restic -r rclone:gdrive:BackupFolder snapshots
```

## browsing the remote

### via mount

A read-only view of the backup:

```bash
mkdir -p /tmp/gdrive-backup
restic -r rclone:gdrive:BackupFolder mount /tmp/gdrive-backup
```

### with `ls`, `find`, `dump`

```bash
restic -r rclone:gdrive:BackupFolder ls latest
restic -r rclone:gdrive:BackupFolder find "document.pdf"
restic -r rclone:gdrive:BackupFolder dump latest /path/to/backup/document.txt
restic -r rclone:gdrive:BackupFolder dump latest /path/to/backup/document.txt > ~/Desktop/recovered_document.txt
```

## ad-hoc environment variables

For running `restic` directly on the command line (the scripts set these
per-repo automatically):

- `RESTIC_REPOSITORY`: the target vault (e.g. `rclone:gdrive:BackupFolder`).
- `RESTIC_PASSWORD_FILE`: a local file containing the vault password -- safer
  than `RESTIC_PASSWORD`, which would leave the plaintext in your shell history.
- `RESTIC_CACHE_DIR`: (optional) where restic stores its local cache chunks --
  useful to keep `$HOME` clean or move the cache to a faster drive.

## restoring

List available snapshots:

```bash
restic snapshots
```

Note the ID (an 8-character string like `a1b2c3d4`) of the snapshot to restore,
or use `latest` for the most recent backup:

```bash
restic restore latest --target /tmp/restic-recovery
restic restore a1b2c3d4 --target /tmp/restic-recovery
```

## how batdots automates it

Three systemd **user** services, each with a script and a timer:

| Job             | Service                     | Timer                     | Script                 |
| --------------- | --------------------------- | ------------------------- | ---------------------- |
| Backup          | restic-backup.service       | restic-backup.timer       | restic-backup.sh       |
| Integrity Check | restic-check.service        | restic-check.timer        | restic-check.sh        |
| Recovery Test   | restic-test-restore.service | restic-test-restore.timer | restic-test-restore.sh |

Trigger a job manually through systemd -- this respects the resource limits
(CPU/IO priority) defined in the service file:

```bash
# Start a backup immediately
systemctl --user start restic-backup.service

# Run an integrity check immediately
systemctl --user start restic-check.service
```

Alternatively, run the underlying scripts directly (they are symlinked onto your
`PATH`):

```bash
restic-backup.sh
```

### viewing logs

These are systemd user services, so their output is captured in the journal:

```bash
# Most recent logs for the backup service
journalctl --user -u restic-backup.service

# Follow logs in real-time (useful while a manual backup is running)
journalctl --user -u restic-backup.service -f

# Logs for all restic-related services
journalctl --user -u restic-backup -u restic-check -u restic-test-restore
```

### checking status

See when the next backup is scheduled or when the last one finished:

```bash
# All active timers and their next run time
systemctl --user list-timers

# Status of the specific backup timer
systemctl --user status restic-backup.timer
```

### removing snapshots

Pruning is a two-step process:

- `forget` removes the snapshot's reference from the index -- it disappears from
  `restic snapshots`, but its data still occupies space.
- `prune` is the garbage collection: it scans for data no longer referenced by
  any snapshot and physically deletes it.

To remove a specific snapshot ID:

```bash
# 1. Forget the snapshot (use --dry-run first to be safe!)
restic forget abc12345 --dry-run
restic forget abc12345

# 2. Free the space
restic prune
```

### retention policy

The retention policy is defined in `lib/backup.sh`; every backup automatically
runs `forget --prune` using these rules:

- **Daily**: keep the last 7 days.
- **Weekly**: keep the last 4 weeks.
- **Monthly**: keep the last 12 months.
- **Yearly**: keep the last 3 years.

Customize them in `local/env.sh`:

```bash
export DOTFILES_RESTIC_KEEP_DAILY=7
export DOTFILES_RESTIC_KEEP_WEEKLY=4
export DOTFILES_RESTIC_KEEP_MONTHLY=12
export DOTFILES_RESTIC_KEEP_YEARLY=3
```

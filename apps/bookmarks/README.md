# Browser bookmarks

Browsers don't expose a stable file format suitable for symlink-syncing across
machines (Chromium SQLite, Firefox `places.sqlite`, etc.), and including a
personal bookmark dump in a public repo is a privacy disaster.

## Workflow

Use the browser's built-in HTML import/export:

```text
chrome://bookmarks/      # Chrome / Brave / Vivaldi

brave://bookmarks/
about:profiles           # Firefox (then Manage > Backup)

```

Export -> `bookmarks.html` -> keep in a private vault (Bitwarden file
attachment, encrypted USB, restic backup, etc.) -- **not in this repo**.

## Cross-machine sync

For real cross-machine sync prefer the browser's own sync (Brave/Chrome sync,
Firefox Sync) -- both end-to-end encrypt the payload, both work without dumping
a giant HTML blob into a git repo.

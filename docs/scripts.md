# User Script Catalog

Every command in [`scripts/user/`](../scripts/user) -- the personal automation
toolkit shipped with batdots. Names link to source. Most accept `-h`/`--help`
for usage, and the ones that touch files support `-n`/`--dry-run`.

This page is grouped by domain; each script appears once.

## Documents & PDF

| Script                                                                | What it does                                                  |
| --------------------------------------------------------------------- | ------------------------------------------------------------- |
| [`pdf-merge`](../scripts/user/pdf-merge.sh)                           | Merge PDFs into one with Ghostscript.                         |
| [`pdf-compress`](../scripts/user/pdf-compress.sh)                     | Shrink PDFs with Ghostscript, balancing size against quality. |
| [`pdf-sanitize`](../scripts/user/pdf-sanitize.sh)                     | Make untrusted PDFs safe to open and share.                   |
| [`pdf-remove-metadata`](../scripts/user/pdf-remove-metadata.sh)       | Strip metadata from PDFs before sharing.                      |
| [`pdf-to-image`](../scripts/user/pdf-to-image.sh)                     | Render PDF pages to images with Poppler's `pdftoppm`.         |
| [`pdf-to-black-and-white`](../scripts/user/pdf-to-black-and-white.sh) | Convert PDFs to grayscale with Ghostscript.                   |
| [`image-to-pdf`](../scripts/user/image-to-pdf.sh)                     | Combine images into a single PDF.                             |
| [`office-to-pdf`](../scripts/user/office-to-pdf.sh)                   | Convert office documents to PDF, then archive the originals.  |
| [`add-yaml-front-matter`](../scripts/user/add-yaml-front-matter.sh)   | Add YAML front matter to Markdown files.                      |
| [`rofi-pdf`](../scripts/user/rofi-pdf.sh)                             | Rofi-based PDF selector and opener.                           |

## Images & photos

| Script                                                                  | What it does                                      |
| ----------------------------------------------------------------------- | ------------------------------------------------- |
| [`image-compress`](../scripts/user/image-compress.sh)                   | Lossy-optimize PNG and JPEG images in place.      |
| [`photo-video-rename-exif`](../scripts/user/photo-video-rename-exif.sh) | Rename photos and videos by capture date.         |
| [`svg-logos`](../scripts/user/svg-logos.sh)                             | Download SVG logos declaratively from a registry. |

## Video

| Script                                                                | What it does                                                                |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [`media-convert`](../scripts/user/media-convert.sh)                   | Convert media between formats with ffmpeg.                                  |
| [`video-trimmer`](../scripts/user/video-trimmer.sh)                   | Trim a video to a `[start, end]` window.                                    |
| [`video-concat-same`](../scripts/user/video-concat-same.sh)           | Losslessly join same-codec videos.                                          |
| [`video-concat-different`](../scripts/user/video-concat-different.sh) | Join videos with differing properties by re-encoding.                       |
| [`video-compress-share`](../scripts/user/video-compress-share.sh)     | Compress videos into small, metadata-stripped H.264/MP4 copies for sharing. |
| [`video-archive`](../scripts/user/video-archive.sh)                   | Storage-optimize videos into an HEVC/MKV archive.                           |
| [`video-sanitize`](../scripts/user/video-sanitize.sh)                 | Maximum-sanitize untrusted videos.                                          |
| [`video-fix`](../scripts/user/video-fix.sh)                           | Repair videos that fail validation.                                         |
| [`hikvision-to-phone`](../scripts/user/hikvision-to-phone.sh)         | Transcode Hikvision MP4s for phones.                                        |
| [`screencast`](../scripts/user/screencast.sh)                         | Toggle a screen-region recording with optional audio.                       |

## Audio & music

| Script                                            | What it does                                      |
| ------------------------------------------------- | ------------------------------------------------- |
| [`audio-play`](../scripts/user/audio-play.sh)     | Play audio files using the best available player. |
| [`audio-record`](../scripts/user/audio-record.sh) | Record a snippet and save it as an MP3.           |
| [`mp3-safe`](../scripts/user/mp3-safe.sh)         | Harden a music library against malicious MP3s.    |

## Downloads & sync

| Script                                          | What it does                                |
| ----------------------------------------------- | ------------------------------------------- |
| [`yt-mp4`](../scripts/user/yt-mp4.sh)           | Download video with yt-dlp as a merged MP4. |
| [`yt-mp3`](../scripts/user/yt-mp3.sh)           | Download audio with yt-dlp as a tagged MP3. |
| [`rclone-sync`](../scripts/user/rclone-sync.sh) | Sync a local directory to an rclone remote. |

## Files & archives

| Script                                                                        | What it does                                                                            |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| [`decompress`](../scripts/user/decompress.sh)                                 | Extract any common archive into its own sibling directory.                              |
| [`compute-checksums`](../scripts/user/compute-checksums.sh)                   | Generate or verify SHA-256 checksum manifests.                                          |
| [`bulk-rename`](../scripts/user/bulk-rename.sh)                               | Sanitize and normalize file and directory names.                                        |
| [`bulk-rename-sequential`](../scripts/user/bulk-rename-sequential.sh)         | Rename files to a zero-padded running number, with optional base name and start offset. |
| [`flatten-nested-directories`](../scripts/user/flatten-nested-directories.sh) | Move every nested file up into a target directory, optionally pruning empties.          |
| [`archive-subfolders`](../scripts/user/archive-subfolders.sh)                 | Archive a folder, detecting tags for sensible exclusions.                               |
| [`backup-file`](../scripts/user/backup-file.sh)                               | Create a `.bak` copy of a file.                                                         |
| [`purge-originals`](../scripts/user/purge-originals.sh)                       | Sweep workflow-archived originals to trash.                                             |
| [`notes-assets`](../scripts/user/notes-assets.sh)                             | Watch the notes-assets dir and rename each new file to a sortable timestamp.            |
| [`extract-links`](../scripts/user/extract-links.sh)                           | Print the unique absolute http(s) links found in web pages or local HTML.               |
| [`tab-opener`](../scripts/user/tab-opener.sh)                                 | Open URLs from one or more files in a browser safely.                                   |

## Dev project tooling

| Script                                                      | What it does                                                    |
| ----------------------------------------------------------- | --------------------------------------------------------------- |
| [`archive-auto`](../scripts/user/archive-auto.sh)           | Sniff a project's type and dispatch to the right archiver.      |
| [`archive-angular`](../scripts/user/archive-angular.sh)     | Archive Angular project(s), excluding caches.                   |
| [`archive-flutter`](../scripts/user/archive-flutter.sh)     | Archive Flutter project(s), excluding caches.                   |
| [`archive-ionic`](../scripts/user/archive-ionic.sh)         | Archive Ionic project(s), excluding caches.                     |
| [`archive-java`](../scripts/user/archive-java.sh)           | Archive Java project(s), excluding caches.                      |
| [`archive-latex`](../scripts/user/archive-latex.sh)         | Archive LaTeX project(s), excluding aux files.                  |
| [`clean-all-flutter`](../scripts/user/clean-all-flutter.sh) | Clean every Flutter project under a target directory.           |
| [`clean-all-ionic`](../scripts/user/clean-all-ionic.sh)     | Clean every Ionic project under a target directory.             |
| [`clean-all-dotnet`](../scripts/user/clean-all-dotnet.sh)   | Clean every .NET project under a target directory.              |
| [`use-java`](../scripts/user/use-java.sh)                   | Switch between Java versions via SDKMAN or update-alternatives. |

## Backup (restic)

| Script                                                          | What it does                                                                               |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [`backup`](../scripts/user/backup.sh)                           | Timestamped `tar.gz` backup to `DOTFILES_BACKUP_DIR`.                                      |
| [`restic-backup`](../scripts/user/restic-backup.sh)             | Snapshot the configured paths into every restic repo, then prune per the retention policy. |
| [`restic-check`](../scripts/user/restic-check.sh)               | Verify the integrity of every reachable restic repo.                                       |
| [`restic-test-restore`](../scripts/user/restic-test-restore.sh) | Restore a sentinel file from the latest snapshot to prove the restore path works.          |

## Desktop, bar & hardware

| Script                                                                  | What it does                                                                  |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [`popup-calendar`](../scripts/user/popup-calendar.sh)                   | Status-bar clock -- print the date, or pop up a yad calendar near the cursor. |
| [`power-menu`](../scripts/user/power-menu.sh)                           | Rofi power menu (lock / logout / suspend / reboot).                           |
| [`brightness`](../scripts/user/brightness.sh)                           | Adjust screen brightness and notify.                                          |
| [`volume`](../scripts/user/volume.sh)                                   | Adjust volume and notify.                                                     |
| [`battery-notification`](../scripts/user/battery-notification.sh)       | Notify once when the battery goes low.                                        |
| [`screenshot`](../scripts/user/screenshot.sh)                           | Capture screenshots, strip metadata, then save or copy.                       |
| [`theme-switch-lxterminal`](../scripts/user/theme-switch-lxterminal.sh) | Switch LXTerminal color schemes.                                              |
| [`prayer-times`](../scripts/user/prayer-times.sh)                       | Display today's Muslim prayer times.                                          |

## Wallpaper

| Script                                                    | What it does                                 |
| --------------------------------------------------------- | -------------------------------------------- |
| [`wallpaper-set`](../scripts/user/wallpaper-set.sh)       | Set the desktop wallpaper.                   |
| [`wallpaper-random`](../scripts/user/wallpaper-random.sh) | Set a random wallpaper from the collection.  |
| [`wallpaper-add`](../scripts/user/wallpaper-add.sh)       | Add a new image to the wallpaper collection. |
| [`rofi-wallpaper`](../scripts/user/rofi-wallpaper.sh)     | Rofi-based wallpaper selector.               |

## Launchers & pickers

| Script                                                        | What it does                                    |
| ------------------------------------------------------------- | ----------------------------------------------- |
| [`rofi-scripts`](../scripts/user/rofi-scripts.sh)             | Rofi launcher for all your dotfiles utilities.  |
| [`rofi-emojie-picker`](../scripts/user/rofi-emojie-picker.sh) | Rofi-based emoji picker with clipboard support. |

## Camera & networking

| Script                                                | What it does                                     |
| ----------------------------------------------------- | ------------------------------------------------ |
| [`cam-home`](../scripts/user/cam-home.sh)             | Open RTSP camera streams from a DVR/NVR in mpv.  |
| [`webcam`](../scripts/user/webcam.sh)                 | Open a local webcam stream using ffplay (MJPEG). |
| [`wifi-qr-create`](../scripts/user/wifi-qr-create.sh) | Generate a WiFi QR code.                         |
| [`wifi-qr-read`](../scripts/user/wifi-qr-read.sh)     | Read a WiFi QR code from the camera.             |

## System health & misc

| Script                                                          | What it does                                                        |
| --------------------------------------------------------------- | ------------------------------------------------------------------- |
| [`package-status`](../scripts/user/package-status.sh)           | Installed vs pinned version for every registry component (offline). |
| [`para-doctor`](../scripts/user/para-doctor.sh)                 | Audit-only health check for the PARA file tree.                     |
| [`browser-clear-cache`](../scripts/user/browser-clear-cache.sh) | Free disk space by clearing browser caches.                         |
| [`catalog-bad-media`](../scripts/user/catalog-bad-media.sh)     | Catalog quarantined bad-media directories.                          |
| [`randpw`](../scripts/user/randpw.sh)                           | Generate a random password.                                         |

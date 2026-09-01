# ByeTunes16 — Dopamine Rootless Port

A jailbreak-native iOS 16 port of ByeTunes for Dopamine + ElleKit devices (including users who also use TrollStore).

## Differences from stock-device ByeTunes

- No pairing file.
- No LocalDevVPN.
- No AFC/idevice transport.
- No computer sync after installation.
- A root helper on `127.0.0.1:45981` performs guarded direct media-library operations.
- The tweak injects a **BT** control into `com.apple.Music`.

## Features

- MP3, M4A, AAC, ALAC, FLAC, WAV and Opus import.
- Embedded metadata extraction.
- Embedded artwork import into the iTunes artwork store and media DB.
- Music-library browser inside Music.app.
- Title / artist / album / genre / year editing.
- Editable playlist creation.
- Automatic database backup before every mutation.
- Manual backup and latest-backup restore.
- SQLite `quick_check` before import and after repair.
- Repair of missing sync IDs and orphan playlist rows.
- Safe removal of library records while preserving the underlying audio file for recovery.
- Rootless paths and ElleKit filter for `com.apple.Music`.

## Target

- iOS 16.x
- Dopamine rootless
- ElleKit
- arm64

TrollStore can coexist with this setup, but tweak injection itself is supplied by Dopamine/ElleKit; TrollStore alone does not load jailbreak tweaks.

## Safety model

All writes are transactional. A database snapshot is created under `/var/mobile/Library/ByeTunes16/Backups` before import, metadata edits, playlist creation, repair or delete operations. The helper refuses to mutate a database that fails `PRAGMA quick_check`.

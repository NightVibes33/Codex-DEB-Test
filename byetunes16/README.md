# ByeTunes16 — Dopamine Rootless Port

A jailbreak-native iOS 16 ByeTunes port for Dopamine + ElleKit devices, including setups that also use TrollStore.

## Architecture

- No pairing file.
- No LocalDevVPN.
- No AFC/idevice transport.
- No computer sync after installation.
- Root helper on `127.0.0.1:45981` performs guarded media-library operations.
- ElleKit injects the **BT** control directly into `com.apple.Music`.

## 0.2.0 feature set

- MP3, M4A, AAC, ALAC, FLAC, WAV and Opus injection into the native Music library.
- Embedded metadata extraction on import.
- Embedded cover-art import into `iTunes_Control/iTunes/Artwork/Originals` plus media-library artwork bindings.
- Apple/iTunes metadata search from inside Music.app.
- Deezer metadata search/fallback from inside Music.app.
- Selected search results can update title, artist, album, genre and year and can replace artwork from the provider result.
- Full local library browser inside Music.app.
- Manual title / artist / album / genre / year editing.
- Create editable Music playlists.
- Add existing songs to existing editable playlists.
- Remove injected/local library records while preserving the underlying audio file for recovery.
- Automatic database backup before every mutating operation.
- Manual backup and latest-backup restore.
- SQLite `quick_check` protection before imports and after repair.
- Repair missing sync IDs and orphaned playlist rows.
- Rootless Dopamine paths and ElleKit filter for `com.apple.Music`.

## Target

- iOS 16.x
- Dopamine rootless
- ElleKit
- arm64

TrollStore can coexist with this setup, but tweak injection is supplied by Dopamine/ElleKit. TrollStore alone does not load jailbreak tweaks.

## Safety model

Media-library writes use SQLite transactions. A snapshot is created under `/var/mobile/Library/ByeTunes16/Backups` before import, metadata edits, playlist mutations, repair or deletion. The helper refuses import when the current database fails `PRAGMA quick_check`.

## Upstream

Behavior and iOS media-library schema work are based on the MIT-licensed ByeTunes project by Edualexxis. See `THIRD_PARTY_Byetunes_LICENSE.txt`.

# Native Music Extras for the legacy iOS 27 Music.app guest

This is an **additive** feature module built into the existing HEIC compatibility dylib. It does not replace the original Music app's tabs, layout, artwork, browsing, account integration, or native playback implementation.

## Build

- Source: `tools/MusicExtras.m`
- GitHub Actions: `.github/workflows/music-ios27-sim-test.yml`
- Guest bundle: `com.nightvibes33.applemusic27`
- Min. OS metadata: iOS 27.
- Loading mechanism: `Music` binary's `LC_LOAD_DYLIB` dependency on `MusicHEICCompat.dylib`, which also includes this native module.
- The original Apple Music executable is an iOS *device* binary and is **not runnable in iOS Simulator**. Only compile-time, packaging, and separately simulated shim tests are supported without a physical iOS 27 device.

## Native iOS user interface

When the Music guest is active in FlekDeck, the module installs a small red **♫+** floating accessory button over the original interface. Tap it to open a bottom feature sheet. Tap Done to close; playback through Apple Music is not changed automatically.

Features currently implemented:
1. **Synced lyrics** with timestamp parsing, on-demand LRCLIB `/api/get`, title/artist fallback `/api/search`, local cache, synchronized line highlighting where MediaPlayer exposes a time position, manual title/artist fields.
2. **Authorized library** counts from `MPMediaLibrary` (requests permission only after the user taps Allow).
3. **Read-only playback status** displayed separately for `MPMusicPlayerController.applicationQueuePlayer` and `systemMusicPlayer`, so missing state in one does not override the other.
4. **Local audio import** via the iOS Files document picker for MP3, M4A, AAC, WAV, AIFF and CAF. Tracks are stored under `Documents/MusicExtras/Audio`.
5. **Imported music playback** using `AVAudioPlayer`, including explicit play, pause, resume and stop. Local audio can activate the playback audio session **only when the user selects a local file**.
6. **Artwork API compatibility** by retaining the `setMaxHEICRequestPercentage:` selector and previous CarPlay weak-import patch.

## Subscription integration

The original Music.app remains responsible for its existing Apple Music library and authenticated Apple playback. **No extra Apple Music account** is created by this module. Its public MediaPlayer library browsing respects system permissions. Public MusicKit does not document an API returning complete synchronized Apple subscription lyrics; the optional lyrics panel searches LRCLIB rather than claiming to extract protected lyrics from Apple.

## Safety / regression protection

- No MusicKit playback changes at module initialization.
- No constructor-based MediaRemote polling, no system player ownership overrides.
- No stop/pause/seek commands against the original Apple Music session.
- Remote lyrics requests happen only after tapping Find.
- The `MPMusicPlayerController` read-only snapshot is only taken when visiting Playback sources or Synced lyrics.
- The original version proven to play audio in FlekDeck remains available as an independent rollback.
- If an exception prevents launching, revert to the Audio Restored IPA rather than deleting the existing guest data container.

## Not implemented yet

The feature panel is **not a full port of døPe**. The original Flutter UI is intentionally not included. Remaining features include full Navidrome/Jellyfin clients and server account support, a native EQ/AVAudioEngine playback pipeline, per-track metadata editing, editable local playlists, cross-source queue management, network caching, full native MusicKit app-owned playback, and direct integration with the legacy Music application's internal Now Playing and lyrics views.

The in-app legacy Not Playing bug remains unresolved until on-device state-provider attribution identifies a safe integration path. A completed simulator build cannot establish end-to-end playback on an iOS device.

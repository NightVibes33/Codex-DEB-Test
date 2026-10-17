# Apple Music iOS 27 compatibility: døPe / mo1 port audit

## Scope and baseline

- Source to consult: [NightVibes33/mo1](https://github.com/NightVibes33/mo1), branded **døPe**. It is an independent Flutter application with a native Swift media bridge; it is **not** Apple's Music application.
- Destination: extracted iOS 15.8.8 `Music.app`, repackaged as `com.nightvibes33.applemusic27` for a FlekDeck host on iOS 27.
- Regression policy: retain the previously known audible-playback IPA as a control, and never modify it during a diagnostic-only change. The earlier injected MediaRemote observer coincided with lost audio and was reverted.
- Simulator limitation: Apple Music's original ARM64 *device* executable is rejected by the iOS 27 simulator platform. A standalone iOS 27 test app may validate adapters, but not legacy Music.app behavior.

## Verified source mapping

| Feature | døPe implementation | Transfer to legacy Music |
|---|---|---|
| Native application-owned Apple Music queue | `ios/Runner/AppDelegate.swift`, `AppleMusicLookupChannel.playCatalogQueueWithMediaPlayer` | Candidate replacement for selected playback commands only; original guest binaries do not use Flutter MethodChannels |
| ApplicationMusicPlayer (MusicKit) | `AppDelegate.swift`, `playCatalogQueueWithMusicKit`, `musicKitPlaybackSnapshot` | Candidate when an app-owned MusicKit playback entitlement/authorization flow succeeds |
| Position and state snapshots | `AppDelegate.swift`, `playbackSnapshot` and `musicKitPlaybackSnapshot`; `lib/core/services/apple_music_playback_service.dart` | Port pure backend separation, not fixed "Playing" flags or guessed player ownership |
| Now Playing metadata and remote commands | `AppDelegate.swift`, `NowPlayingChannel` (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`) | Only publish once **this process** owns playback; publishing while Apple Music owns the session causes inconsistent Control Center behavior |
| File music playback | `lib/core/services/audio_player_service.dart`, Just Audio, `audio_service` | Requires new native guest-controlled player or separately embedded engine; Flutter source is not a drop-in dylib |
| Timed lyrics and metadata | `lib/core/services/lyrics_lookup_service.dart`, related song editing and caching | Transfer algorithms and data modeling; need UI and legal lyrics data source |
| Debug/error recovery | Swift MediaPlayer prepares queue, logs errors, falls back from store descriptor to library descriptor | Useful for newly built playback backend, not automatically for proprietary older Music framework |

## Evidence from device logs

Prior FlekDeck log `MusicPlaybackStatus.log`: the MediaRemote listener was present but reported playback=false, owner PID=0 (unavailable), no track metadata. It did **not** prove that the native Music app owned playback. On-device sound occurred in an earlier build, but app-side transport displayed Not Playing.

Apple's published distinction:
- `MPMusicPlayerController.applicationQueuePlayer` and `MusicKit.ApplicationMusicPlayer` provide app-owned music playback and should not manipulate the installed Music app's state.
- `MPMusicPlayerController.systemMusicPlayer` and `MusicKit.SystemMusicPlayer` control the installed Music app's playback.

## Completed isolated prototype

- `tools/MusicLegacyPlaybackStateAdapter.m` exports `MLMusicPlaybackSnapshot` to query **both** system and application MediaPlayer controllers, on the **main thread**.
- The snapshot keeps both playing states separate. An idle application controller cannot overwrite an active system controller. Nil track information is reported as absence, never fabricated.
- No constructor, timers, notifications, MediaRemote calls, playback commands, method swizzling, or changes to the Music.app binary.
- `.github/workflows/verify-mo1-music-state-adapter.yml` compiles independent iOS 27 device and simulator dylibs; this only establishes ABI/build viability, not an on-device session bridge.

## Next engineering gates

1. **Observe, without playback mutation.** Add an explicit diagnostic invocation to a private development FlekDeck host or separate probe app and compare device system/application state while actual audio plays. Require measured playback-state source and item identity.
2. **Locate legacy UI state source.** Reverse engineer the specific `MusicApplication.framework` method that maps system state to the Not Playing view. Capture selector name/signature before any swizzle or interposition.
3. **Implement a state adapter behind feature flag.** Use the backend confirmed by the device, with pause/seek/queue controls read-only until actual playback ownership is established. Avoid changing `MPNowPlayingInfoCenter` to spoof other apps' playback.
4. **Independent playback.** Build a separately loaded native `applicationQueuePlayer` or MusicKit `ApplicationMusicPlayer` service with explicit authorization, supported library/catalog IDs, queue preparation, and recoverable failure behavior. Do not stop the system player until this service has prepared and actually started audio.
5. **Feature parity.** Add local file support, synced lyrics and artwork metadata incrementally after stable play/pause/seek and transitions.
6. **Regression testing.** Test on a physical iOS 27 iPhone under FlekDeck, compare with the last user-confirmed playable IPA, log failures to Files, and preserve user libraries and data containers.

This audit does not claim the repackaged Music app now has independent playback or a repaired Not Playing status.
## User Apple Music subscription integration (October 17, 2026)

- **Authentication:** Use the current iPhone owner's `MusicAuthorization.request()` and `MusicSubscription.current`, not a second login, hardcoded credentials, embedded developer user tokens, shared accounts, or payment flow. Media access must use the user's legitimate authorization. The native bridge returns the real `canPlayCatalogContent` result rather than assuming subscription status.
- **Private user data:** MusicKit automatically manages the Music User Token for requests on iOS. Do not log tokens or persist Apple passwords. The user's authorized library is requested through `MusicLibraryRequest<Song>`.
- **Playback ownership:** The new `ApplicationMusicPlayer.shared` path uses the authorized user's account and is separate from Apple's installed Music app. It requires MusicKit support in the signing/host process and must be explicitly invoked. Never stop the previously working player simply to switch backends.
- **Lyrics:** Apple provides song `hasLyrics` availability metadata but no documented endpoint for retrieving full time-coded lyrics. Our source port uses LRCLIB on demand, exact title + artist + duration match first, then confidently matched search fallback; label these results **LRCLIB**, not official Apple Music lyrics. Do not upload personal listening history.
- **Host permission:** The main FlekDeck Info.plist already declares `NSAppleMusicUsageDescription`. The separate `LiveProcess/Info.plist` did not, so branch `NightVibes33/FlekDeck:temp/music-subscription-permissions-ios27` adds the purpose string for the extension process (commit a87a52f).
- **Code:** `tools/MusicLegacySubscriptionLyricsBridge.swift` implements opt-in authorization, subscription check, library browsing, catalog search, app-owned queue play/pause/resume/skip/seek, snapshot, and synced LRCLIB text lookup. `.github/workflows/build-music-subscription-lyrics.yml` builds the arm64 iOS device and simulator modules.
- **Activation still required:** These compiled modules are **not** connected to the original proprietary MusicApplication binary or its Now Playing / lyrics UI, and MusicKit playback has not been verified on the user's signed iOS 27 host. Do not report full feature integration or issue a "fixed" IPA until app-UI wiring and physical-device validation are completed.

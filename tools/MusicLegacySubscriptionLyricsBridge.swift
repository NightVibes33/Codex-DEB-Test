// Native feature layer for the original iOS Music user interface.
//
// Reuses concepts from NightVibes33/mo1 (døPe):
// - MusicKit authorized subscription/account access
// - app-owned music queue and separate playback snapshots
// - timed LRCLIB lyrics matched to title, artist, album and duration
//
// No constructors, no swizzling, no global MediaRemote observer and no
// automatic playback mutation. Must be invoked explicitly by the guest/host.
//
// The user must approve MusicKit access and already have an appropriate
// Apple Music subscription for catalog playback. This never bypasses DRM.
//
// Apple Music's public MusicKit APIs only expose Song.hasLyrics, not complete
// time-coded lyric data. LRCLIB is an independent lyrics source and should
// not be labeled "Apple official lyrics".
import Foundation
import MusicKit

@objc(MusicLegacySubscriptionLyricsBridge)
public final class MusicLegacySubscriptionLyricsBridge: NSObject {
    @objc public static let shared = MusicLegacySubscriptionLyricsBridge()
    private override init() { super.init() }

    private static func emit(_ completion: @escaping (NSDictionary) -> Void,
                             _ value: [String: Any]) {
        DispatchQueue.main.async {
            completion(value as NSDictionary)
        }
    }

    @objc public func authorizationStatus() -> String {
        switch MusicAuthorization.currentStatus {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    @objc public func requestAuthorization(_ completion: @escaping (NSDictionary) -> Void) {
        Task {
            let status = await MusicAuthorization.request()
            Self.emit(completion, [
                "authorized": status == .authorized,
                "status": String(describing: status),
                "provider": "MusicKit"
            ])
        }
    }

    @objc public func subscriptionStatus(_ completion: @escaping (NSDictionary) -> Void) {
        Task {
            guard MusicAuthorization.currentStatus == .authorized else {
                Self.emit(completion, [
                    "authorized": false,
                    "canPlayCatalogContent": false,
                    "error": "MusicKit permission not granted"
                ])
                return
            }
            do {
                let subscription = try await MusicSubscription.current
                Self.emit(completion, [
                    "authorized": true,
                    "canPlayCatalogContent": subscription.canPlayCatalogContent,
                    "canBecomeSubscriber": subscription.canBecomeSubscriber,
                    "hasCloudLibraryEnabled": subscription.hasCloudLibraryEnabled,
                    "provider": "userAppleMusicSubscription"
                ])
            } catch {
                Self.emit(completion, ["authorized": true,
                                       "canPlayCatalogContent": false,
                                       "error": error.localizedDescription])
            }
        }
    }

    // Uses the application's own MusicKit player, NEVER SystemMusicPlayer.
    // The caller must choose this path; we do not automatically switch the
    // original Music application's playback or stop another app's player.
    @objc public func playCatalogSong(_ catalogID: String,
                                      completion: @escaping (NSDictionary) -> Void) {
        let requestedID = catalogID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedID.isEmpty else {
            Self.emit(completion, ["started": false, "error": "Empty song identifier"])
            return
        }
        Task { @MainActor in
            guard MusicAuthorization.currentStatus == .authorized else {
                Self.emit(completion, ["started": false, "error": "MusicKit permission required"])
                return
            }
            do {
                let subscription = try await MusicSubscription.current
                guard subscription.canPlayCatalogContent else {
                    Self.emit(completion, ["started": false,
                                           "error": "Active Apple Music catalog access required"])
                    return
                }
                var request = MusicCatalogResourceRequest<Song>(
                    matching: \.id, equalTo: MusicItemID(requestedID))
                request.limit = 1
                let response = try await request.response()
                guard let song = response.items.first else {
                    Self.emit(completion, ["started": false, "error": "Song not found in catalog"])
                    return
                }
                let player = ApplicationMusicPlayer.shared
                player.queue = ApplicationMusicPlayer.Queue(for: [song])
                try await player.prepareToPlay()
                try await player.play()
                Self.emit(completion, [
                    "started": true,
                    "backend": "ApplicationMusicPlayer",
                    "independentOfSystemMusic": true,
                    "songID": requestedID
                ])
            } catch {
                Self.emit(completion, [
                    "started": false,
                    "backend": "ApplicationMusicPlayer",
                    "error": error.localizedDescription
                ])
            }
        }
    }

    @objc public func playbackSnapshot(_ completion: @escaping (NSDictionary) -> Void) {
        Task { @MainActor in
            let player = ApplicationMusicPlayer.shared
            let status = player.state.playbackStatus
            let t = player.playbackTime
            Self.emit(completion, [
                "backend": "ApplicationMusicPlayer",
                "isPlaying": status == .playing,
                "playbackState": String(describing: status),
                "positionSeconds": t.isFinite && t > 0 ? t : 0
            ])
        }
    }

    @objc public func pauseAppOwnedPlayer() {
        Task { @MainActor in
            ApplicationMusicPlayer.shared.pause()
        }
    }

    @objc public func resumeAppOwnedPlayer(_ completion: @escaping (NSDictionary) -> Void) {
        Task { @MainActor in
            do {
                try await ApplicationMusicPlayer.shared.play()
                Self.emit(completion, ["playing": true])
            } catch {
                Self.emit(completion, ["playing": false, "error": error.localizedDescription])
            }
        }
    }

    @objc public func skipNext(_ completion: @escaping (NSDictionary) -> Void) {
        Task { @MainActor in
            do {
                try await ApplicationMusicPlayer.shared.skipToNextEntry()
                Self.emit(completion, ["success": true])
            } catch {
                Self.emit(completion, ["success": false, "error": error.localizedDescription])
            }
        }
    }

    // LRCLIB provides the actual LRC text. Do not claim MusicKit provided it.
    // Nothing is requested until the user opens lyrics for a track.
    @objc public func fetchLyrics(track: String,
                                  artist: String,
                                  album: String,
                                  durationSeconds: Int,
                                  completion: @escaping (NSDictionary) -> Void) {
        let cleanTrack = track.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTrack.isEmpty else {
            Self.emit(completion, ["found": false, "error": "Missing track title"])
            return
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "lrclib.net"
        components.path = "/api/get"
        var query = [URLQueryItem(name: "track_name", value: cleanTrack)]
        if !cleanArtist.isEmpty {
            query.append(URLQueryItem(name: "artist_name", value: cleanArtist))
        }
        if !cleanAlbum.isEmpty {
            query.append(URLQueryItem(name: "album_name", value: cleanAlbum))
        }
        if durationSeconds > 0 {
            query.append(URLQueryItem(name: "duration", value: String(durationSeconds)))
        }
        components.queryItems = query
        guard let url = components.url else {
            Self.emit(completion, ["found": false, "error": "Invalid request parameters"])
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MusicLegacy-iOS27/1.0", forHTTPHeaderField: "User-Agent")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        URLSession(configuration: config).dataTask(with: request) { data, response, error in
            guard error == nil, let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Self.searchLyricsFallback(track: cleanTrack, artist: cleanArtist, completion: completion)
                return
            }
            let synced = (result["syncedLyrics"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let plain = (result["plainLyrics"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let returnedTitle = result["trackName"] as? String ?? ""
            let returnedArtist = result["artistName"] as? String ?? ""
            guard returnedTitle.caseInsensitiveCompare(cleanTrack) == .orderedSame &&
                    (cleanArtist.isEmpty ||
                     returnedArtist.caseInsensitiveCompare(cleanArtist) == .orderedSame),
                  !synced.isEmpty || !plain.isEmpty else {
                Self.searchLyricsFallback(track: cleanTrack, artist: cleanArtist, completion: completion)
                return
            }
            Self.emit(completion, [
                "found": true,
                "source": "LRCLIB",
                "hasSyncedLyrics": !synced.isEmpty,
                "syncedLyrics": synced,
                "plainLyrics": plain,
                "track": returnedTitle,
                "artist": returnedArtist
            ])
        }.resume()
    }
    // Source-aware user library loading. MusicKit handles the user's token;
    // no passwords, session cookies, or authorization headers are exported.
    @objc public func librarySongs(limit: Int,
                                   completion: @escaping (NSDictionary) -> Void) {
        Task {
            guard MusicAuthorization.currentStatus == .authorized else {
                Self.emit(completion, ["success": false, "error": "MusicKit permission required"])
                return
            }
            do {
                var request = MusicLibraryRequest<Song>()
                request.limit = max(1, min(limit, 100))
                let response = try await request.response()
                let records = response.items.map { song -> [String: Any] in
                    [
                        "id": song.id.rawValue,
                        "title": song.title,
                        "artist": song.artistName,
                        "album": song.albumTitle ?? "",
                        "hasLyrics": song.hasLyrics,
                        "provider": "MusicKit"
                    ]
                }
                Self.emit(completion, [
                    "success": true,
                    "count": records.count,
                    "songs": records
                ])
            } catch {
                Self.emit(completion, ["success": false, "error": error.localizedDescription])
            }
        }
    }

    @objc public func searchCatalog(_ query: String,
                                    completion: @escaping (NSDictionary) -> Void) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            Self.emit(completion, ["success": false, "error": "Empty search query"])
            return
        }
        Task {
            guard MusicAuthorization.currentStatus == .authorized else {
                Self.emit(completion, ["success": false, "error": "MusicKit permission required"])
                return
            }
            do {
                var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
                request.limit = 25
                let response = try await request.response()
                let records = response.songs.map { song -> [String: Any] in
                    [
                        "id": song.id.rawValue,
                        "title": song.title,
                        "artist": song.artistName,
                        "album": song.albumTitle ?? "",
                        "hasLyrics": song.hasLyrics,
                        "provider": "AppleMusicCatalog"
                    ]
                }
                Self.emit(completion, [
                    "success": true,
                    "count": records.count,
                    "songs": records
                ])
            } catch {
                Self.emit(completion, ["success": false, "error": error.localizedDescription])
            }
        }
    }

    @objc public func skipPrevious(_ completion: @escaping (NSDictionary) -> Void) {
        Task { @MainActor in
            do {
                try await ApplicationMusicPlayer.shared.skipToPreviousEntry()
                Self.emit(completion, ["success": true])
            } catch {
                Self.emit(completion, ["success": false, "error": error.localizedDescription])
            }
        }
    }

    @objc public func seekAppOwnedPlayer(to seconds: Double) {
        guard seconds.isFinite && seconds >= 0 else { return }
        Task { @MainActor in
            ApplicationMusicPlayer.shared.playbackTime = seconds
        }
    }

    // Mirrors døPe's exact-first then search fallback. Only accepts an exact
    // title+artist match so unrelated songs cannot silently receive lyrics.
    private static func searchLyricsFallback(track: String,
                                             artist: String,
                                             completion: @escaping (NSDictionary) -> Void) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "lrclib.net"
        components.path = "/api/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: [track, artist].filter { !$0.isEmpty }.joined(separator: " "))
        ]
        guard let url = components.url else {
            emit(completion, ["found": false, "source": "LRCLIB"])
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("MusicLegacy-iOS27/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let records = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                emit(completion, ["found": false, "source": "LRCLIB"])
                return
            }
            let matched = records.filter { record in
                let title = record["trackName"] as? String ?? ""
                let singer = record["artistName"] as? String ?? ""
                return title.caseInsensitiveCompare(track) == .orderedSame &&
                    (artist.isEmpty || singer.caseInsensitiveCompare(artist) == .orderedSame)
            }
            let selected = matched.first {
                !(( $0["syncedLyrics"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)).isEmpty
            } ?? matched.first
            guard let selected else {
                emit(completion, ["found": false, "source": "LRCLIB",
                                  "reason": "No matching lyrics"])
                return
            }
            let synced = selected["syncedLyrics"] as? String ?? ""
            let plain = selected["plainLyrics"] as? String ?? ""
            guard !synced.isEmpty || !plain.isEmpty else {
                emit(completion, ["found": false, "source": "LRCLIB"])
                return
            }
            emit(completion, [
                "found": true,
                "source": "LRCLIB",
                "hasSyncedLyrics": !synced.isEmpty,
                "syncedLyrics": synced,
                "plainLyrics": plain,
                "track": selected["trackName"] as? String ?? track,
                "artist": selected["artistName"] as? String ?? artist,
                "fallback": true
            ])
        }.resume()
    }

}

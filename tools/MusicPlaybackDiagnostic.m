// Music Playback Attribution Diagnostic for FlekDeck.
// This module is deliberately READ-ONLY. It does not claim to move ownership
// of FairPlay/Apple Music playback to a re-signed third-party app.
// It records remote playback state and active player PID in the app's own
// Documents directory without collecting song names, library, or artwork.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <unistd.h>
#import <limits.h>
#import <stdatomic.h>

typedef void (*MRPlayingQuery)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRPIDQuery)(dispatch_queue_t, void (^)(int));
typedef void (*MRInfoQuery)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRRegister)(dispatch_queue_t);

static MRPlayingQuery queryPlaying;
static MRPIDQuery queryPID;
static MRInfoQuery queryInfo;
static MRRegister registerNotifications;
static atomic_bool initialized = false;
static dispatch_queue_t stateQueue;
static int lastPID = INT_MIN;
static int lastPlaying = -1;
static int lastInfo = -1;

static void logStatus(NSString *message) {
    // HOME is the FlekDeck-selected guest data container when available.
    const char *home = getenv("HOME");
    if (!home || !*home) return;
    NSString *directory = [[NSString stringWithUTF8String:home] stringByAppendingPathComponent:@"Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *path = [directory stringByAppendingPathComponent:@"MusicPlaybackStatus.log"];
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                  dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", timestamp, message];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    } else {
        NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:path];
        if (f) {
            [f seekToEndOfFile];
            [f writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [f closeFile];
        }
    }
}

static void sampleRemote(void) {
    if (!queryPlaying || !queryPID || !queryInfo) return;
    queryPID(stateQueue, ^(int playerPID) {
        if (playerPID != lastPID) {
            lastPID = playerPID;
            logStatus([NSString stringWithFormat:@"remote_now_playing_pid=%d guest_host_pid=%d ownership=%@",
                       playerPID, getpid(), playerPID == getpid() ? @"in-host-process" : @"other-process"]);
        }
    });
    queryPlaying(stateQueue, ^(Boolean playing) {
        int value = playing ? 1 : 0;
        if (value != lastPlaying) {
            lastPlaying = value;
            logStatus([NSString stringWithFormat:@"remote_is_playing=%d", value]);
        }
    });
    queryInfo(stateQueue, ^(CFDictionaryRef info) {
        int hasInfo = info && CFDictionaryGetCount(info) > 0 ? 1 : 0;
        if (hasInfo != lastInfo) {
            lastInfo = hasInfo;
            logStatus([NSString stringWithFormat:@"remote_has_track_metadata=%d", hasInfo]);
        }
    });
}

__attribute__((visibility("default")))
void MUSICPlaybackForceSample(void) {
    if (atomic_load(&initialized)) {
        dispatch_async(stateQueue, ^{ sampleRemote(); });
    }
}

__attribute__((visibility("default")))
int MUSICPlaybackRemoteIsPlaying(void) {
    // -1 means no authoritative result yet; do not turn this into false.
    return lastPlaying;
}

__attribute__((visibility("default")))
int MUSICPlaybackRemoteOwnerPID(void) {
    return lastPID;
}

__attribute__((constructor))
static void initializeMusicPlaybackObserver(void) {
    if (atomic_exchange(&initialized, true)) return;
    stateQueue = dispatch_queue_create("com.nightvibes33.music.playback-diagnostic", DISPATCH_QUEUE_SERIAL);
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
                          RTLD_LAZY | RTLD_LOCAL);
    if (!handle) {
        logStatus([NSString stringWithFormat:@"MediaRemote unavailable: %s", dlerror()]);
        return;
    }
    queryPlaying = (MRPlayingQuery)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    queryPID = (MRPIDQuery)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID");
    queryInfo = (MRInfoQuery)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
    registerNotifications = (MRRegister)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    logStatus([NSString stringWithFormat:@"guest_bundle_id=%@ effective_host_pid=%d api_playing=%d api_pid=%d api_info=%d",
               NSBundle.mainBundle.bundleIdentifier ?: @"unknown", getpid(),
               queryPlaying!=NULL, queryPID!=NULL, queryInfo!=NULL]);
    if (!queryPlaying || !queryPID || !queryInfo) return;
    dispatch_async(stateQueue, ^{
        if (registerNotifications) registerNotifications(stateQueue);
        sampleRemote();
        NSArray<NSString *> *names = @[
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
        ];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        for (NSString *name in names) {
            [center addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *notification) {
                dispatch_async(stateQueue, ^{ sampleRemote(); });
            }];
        }
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,stateQueue);
        // Kept alive for as long as the guest is loaded; no global ownership mutations.
        static dispatch_source_t retainedTimer;
        retainedTimer=timer;
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC),
                                  5*NSEC_PER_SEC, 500*NSEC_PER_MSEC);
        dispatch_source_set_event_handler(timer, ^{ sampleRemote(); });
        dispatch_resume(timer);
    });
}

// MusicLegacyPlaybackStateAdapter.m
//
// Reference implementation adapted from the PUBLIC MediaPlayer playback
// snapshot architecture in NightVibes33/mo1, ios/Runner/AppDelegate.swift
// (AppleMusicLookupChannel.playbackSnapshot).
//
// IMPORTANT: No constructors, timers, notifications, method swizzling,
// playback commands, or MediaRemote access. This module must be invoked
// explicitly from the FlekDeck host, not automatically loaded as an app
// replacement. It cannot itself repair the compiled Music.app user interface.
//
// Copyright (c) 2026 NightVibes33. This module is new code, not Apple code.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <dispatch/dispatch.h>
#import <math.h>

static NSString *MLStateName(MPMusicPlaybackState state) {
    switch (state) {
        case MPMusicPlaybackStateStopped: return @"stopped";
        case MPMusicPlaybackStatePlaying: return @"playing";
        case MPMusicPlaybackStatePaused: return @"paused";
        case MPMusicPlaybackStateInterrupted: return @"interrupted";
        case MPMusicPlaybackStateSeekingForward: return @"seekingForward";
        case MPMusicPlaybackStateSeekingBackward: return @"seekingBackward";
        default: return @"unknown";
    }
}

static NSDictionary<NSString *, id> *MLSnapshotPlayer(MPMusicPlayerController *player,
                                                     NSString *kind) {
    // Apple requires access to MPMusicPlayerController on the main thread.
    // Do not query music player objects on background libdispatch queues.
    MPMusicPlaybackState playbackState = player.playbackState;
    MPMediaItem *item = player.nowPlayingItem;
    NSTimeInterval rawDuration = item ? item.playbackDuration : 0.0;
    NSTimeInterval rawPosition = player.currentPlaybackTime;
    double duration = (isfinite(rawDuration) && rawDuration > 0) ? rawDuration : 0.0;
    double position = (isfinite(rawPosition) && rawPosition > 0) ? rawPosition : 0.0;
    if (duration > 0) position = fmin(position, duration);
    return @{
        @"backend": kind,
        @"playbackState": MLStateName(playbackState),
        @"isPlaying": @(playbackState == MPMusicPlaybackStatePlaying),
        @"hasNowPlayingItem": @(item != nil),
        @"positionSeconds": @(position),
        @"durationSeconds": @(duration),
        @"supported": @YES
    };
}

// Snapshot both backend types. Do not assume they share playback ownership.
__attribute__((visibility("default")))
NSDictionary<NSString *, id> *MLMusicPlaybackSnapshot(void) {
    __block NSDictionary<NSString *, id> *report = nil;
    void (^capture)(void) = ^{
        @try {
            NSDictionary *system = MLSnapshotPlayer(
                [MPMusicPlayerController systemMusicPlayer], @"systemMusicPlayer");
            NSDictionary *application = MLSnapshotPlayer(
                [MPMusicPlayerController applicationQueuePlayer], @"applicationQueuePlayer");
            // Keep both results separate so "not playing" in one backend
            // cannot override "playing" in the other.
            report = @{
                @"system": system,
                @"application": application,
                @"hasAnyPlayingBackend": @([system[@"isPlaying"] boolValue] ||
                                            [application[@"isPlaying"] boolValue]),
                @"source": @"public MediaPlayer"
            };
        } @catch (NSException *exception) {
            report = @{
                @"source": @"public MediaPlayer",
                @"error": exception.name ?: @"unknown exception"
            };
        }
    };
    if ([NSThread isMainThread]) capture();
    else dispatch_sync(dispatch_get_main_queue(), capture);
    return report;
}

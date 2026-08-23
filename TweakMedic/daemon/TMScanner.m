#import "TMScanner.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <libproc.h>
#import <objc/message.h>
#import <signal.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSString * const TMRoot = @"/var/mobile/Library/TweakMedic";
static NSString * const TMStageRoot = @"/var/mobile/Library/TweakMedic/Staging";
static NSString * const TMDisabledRoot = @"/var/mobile/Library/TweakMedic/Disabled";
static NSString * const TMReportsRoot = @"/var/mobile/Library/TweakMedic/Reports";
static NSString * const TMPrefsPath = @"/var/mobile/Library/Preferences/com.nightvibes33.tweakmedic.plist";
static NSString * const TMTweakDir = @"/var/jb/usr/lib/TweakInject";
static NSString * const TMSelfBundleID = @"com.nightvibes33.tweakmedic";

static NSString *TMISODate(void) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    return [formatter stringFromDate:NSDate.date];
}

static void TMEnsureDirectories(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *path in @[TMRoot, TMStageRoot, TMDisabledRoot, TMReportsRoot]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:nil];
    }
}

static NSDictionary *TMReadPlist(NSString *path) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    return [d isKindOfClass:NSDictionary.class] ? d : @{};
}

static BOOL TMBroadUIKitEnabled(void) {
    NSDictionary *prefs = TMReadPlist(TMPrefsPath);
    id value = prefs[@"broadUIKit"];
    return value ? [value boolValue] : YES;
}

static NSString *TMDisplayName(NSDictionary *info, NSString *fallback) {
    for (NSString *key in @[@"CFBundleDisplayName", @"CFBundleName", @"CFBundleExecutable"]) {
        NSString *v = [info[key] isKindOfClass:NSString.class] ? info[key] : nil;
        if (v.length) return v;
    }
    return fallback;
}

static NSDictionary *TMAppAtPath(NSString *path) {
    NSDictionary *info = TMReadPlist([path stringByAppendingPathComponent:@"Info.plist"]);
    NSString *bid = [info[@"CFBundleIdentifier"] isKindOfClass:NSString.class] ? info[@"CFBundleIdentifier"] : nil;
    NSString *exe = [info[@"CFBundleExecutable"] isKindOfClass:NSString.class] ? info[@"CFBundleExecutable"] : nil;
    if (!bid.length || !exe.length) return nil;
    return @{ @"bundleID": bid,
              @"name": TMDisplayName(info, path.lastPathComponent.stringByDeletingPathExtension),
              @"executable": exe,
              @"path": path };
}

static void TMAppendAppsFromRoot(NSMutableArray *apps, NSString *root, BOOL nested) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *children = [fm contentsOfDirectoryAtPath:root error:nil] ?: @[];
    for (NSString *child in children) {
        NSString *candidate = [root stringByAppendingPathComponent:child];
        BOOL isDir = NO;
        [fm fileExistsAtPath:candidate isDirectory:&isDir];
        if (!isDir) continue;
        if ([candidate.pathExtension.lowercaseString isEqualToString:@"app"]) {
            NSDictionary *app = TMAppAtPath(candidate);
            if (app) [apps addObject:app];
        } else if (nested) {
            NSArray *grand = [fm contentsOfDirectoryAtPath:candidate error:nil] ?: @[];
            for (NSString *g in grand) {
                NSString *p = [candidate stringByAppendingPathComponent:g];
                if (![p.pathExtension.lowercaseString isEqualToString:@"app"]) continue;
                NSDictionary *app = TMAppAtPath(p);
                if (app) [apps addObject:app];
            }
        }
    }
}

static NSArray<NSDictionary *> *TMInstalledApps(void) {
    NSMutableArray *apps = [NSMutableArray array];
    TMAppendAppsFromRoot(apps, @"/var/jb/Applications", NO);
    TMAppendAppsFromRoot(apps, @"/Applications", NO);
    TMAppendAppsFromRoot(apps, @"/var/containers/Bundle/Application", YES);
    NSMutableDictionary *unique = [NSMutableDictionary dictionary];
    for (NSDictionary *app in apps) unique[app[@"bundleID"]] = app;
    return [unique.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
}

static NSDictionary<NSString *, NSString *> *TMPackageMap(void) {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSString *infoRoot = @"/var/jb/var/lib/dpkg/info";
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:infoRoot error:nil] ?: @[];
    for (NSString *file in files) {
        if (![file hasSuffix:@".list"]) continue;
        NSString *package = [file substringToIndex:file.length - 5];
        NSString *text = [NSString stringWithContentsOfFile:[infoRoot stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:nil];
        if (!text.length) continue;
        [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            (void)stop;
            if (!([line containsString:@"/TweakInject/"] || [line containsString:@"/DynamicLibraries/"])) return;
            NSString *base = line.lastPathComponent;
            if ([base.pathExtension.lowercaseString isEqualToString:@"dylib"]) map[base.stringByDeletingPathExtension] = package;
        }];
    }
    return map;
}

static BOOL TMArrayContainsString(NSArray *array, NSString *needle) {
    for (id value in array) {
        if ([value isKindOfClass:NSString.class] && [value caseInsensitiveCompare:needle] == NSOrderedSame) return YES;
    }
    return NO;
}

static BOOL TMTweakMatchesTarget(NSDictionary *filter, NSDictionary *target, BOOL broad) {
    NSArray *bundles = [filter[@"Bundles"] isKindOfClass:NSArray.class] ? filter[@"Bundles"] : @[];
    NSArray *executables = [filter[@"Executables"] isKindOfClass:NSArray.class] ? filter[@"Executables"] : @[];
    NSString *bid = target[@"bundleID"];
    NSString *exe = target[@"executable"];
    if (TMArrayContainsString(bundles, bid) || TMArrayContainsString(executables, exe)) return YES;
    if (broad) {
        for (NSString *framework in @[@"com.apple.UIKit", @"com.apple.UIKitCore", @"com.apple.Foundation", @"com.apple.CoreFoundation"]) {
            if (TMArrayContainsString(bundles, framework)) return YES;
        }
    }
    return bundles.count == 0 && executables.count == 0;
}

static NSArray<NSDictionary *> *TMCandidatesForTarget(NSDictionary *target) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *files = [fm contentsOfDirectoryAtPath:TMTweakDir error:nil] ?: @[];
    NSDictionary *packageMap = TMPackageMap();
    BOOL broad = TMBroadUIKitEnabled();
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *file in files) {
        if (![file.pathExtension.lowercaseString isEqualToString:@"plist"]) continue;
        NSString *name = file.stringByDeletingPathExtension;
        NSString *plistPath = [TMTweakDir stringByAppendingPathComponent:file];
        NSDictionary *root = TMReadPlist(plistPath);
        NSDictionary *filter = [root[@"Filter"] isKindOfClass:NSDictionary.class] ? root[@"Filter"] : root;
        if (!TMTweakMatchesTarget(filter, target, broad)) continue;
        NSString *dylib = [TMTweakDir stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"dylib"]];
        if (![fm fileExistsAtPath:dylib]) continue;
        NSArray *bundles = [filter[@"Bundles"] isKindOfClass:NSArray.class] ? filter[@"Bundles"] : @[];
        NSArray *executables = [filter[@"Executables"] isKindOfClass:NSArray.class] ? filter[@"Executables"] : @[];
        NSString *summary = @"Broad/unknown filter";
        if (bundles.count) summary = [NSString stringWithFormat:@"Bundles: %@", [bundles componentsJoinedByString:@", "]];
        else if (executables.count) summary = [NSString stringWithFormat:@"Executables: %@", [executables componentsJoinedByString:@", "]];
        [out addObject:@{ @"name": name,
                          @"plist": plistPath,
                          @"dylib": dylib,
                          @"package": packageMap[name] ?: @"",
                          @"filter": summary }];
    }
    return [out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
}

static NSArray<NSNumber *> *TMAllPIDs(void) {
    int capacity = proc_listallpids(NULL, 0);
    if (capacity <= 0) return @[];
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    int actual = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
    if (actual < 0) actual = 0;
    if (actual > capacity) actual = capacity;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:(NSUInteger)actual];
    for (int i = 0; i < actual; i++) if (pids[i] > 0) [result addObject:@(pids[i])];
    free(pids);
    return result;
}

static pid_t TMPIDForTarget(NSDictionary *target) {
    NSString *expected = [target[@"path"] stringByAppendingPathComponent:target[@"executable"]];
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    for (NSNumber *n in TMAllPIDs()) {
        pid_t pid = (pid_t)n.intValue;
        bzero(pathbuf, sizeof(pathbuf));
        if (proc_pidpath(pid, pathbuf, sizeof(pathbuf)) <= 0) continue;
        NSString *path = [NSString stringWithUTF8String:pathbuf];
        if ([path isEqualToString:expected]) return pid;
    }
    return 0;
}

static void TMKillTarget(NSDictionary *target) {
    for (int tries = 0; tries < 3; tries++) {
        pid_t pid = TMPIDForTarget(target);
        if (pid <= 0) return;
        kill(pid, SIGKILL);
        usleep(250000);
    }
}

static BOOL TMLaunchBundle(NSString *bundleID) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    if (handle) {
        int (*launch)(CFStringRef, Boolean) = dlsym(handle, "SBSLaunchApplicationWithIdentifier");
        if (launch) {
            int result = launch((__bridge CFStringRef)bundleID, false);
            dlclose(handle);
            if (result == 0) return YES;
        } else {
            dlclose(handle);
        }
    }

    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
    Class cls = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSel = NSSelectorFromString(@"defaultWorkspace");
    SEL openSel = NSSelectorFromString(@"openApplicationWithBundleID:");
    if (cls && [cls respondsToSelector:defaultSel]) {
        id workspace = ((id (*)(id, SEL))objc_msgSend)(cls, defaultSel);
        if (workspace && [workspace respondsToSelector:openSel]) {
            return ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, openSel, bundleID);
        }
    }
    return NO;
}

static int TMRunProgram(NSString *program, NSArray<NSString *> *arguments) {
    NSUInteger argc = arguments.count + 2;
    char **argv = calloc(argc, sizeof(char *));
    argv[0] = strdup(program.UTF8String);
    for (NSUInteger i = 0; i < arguments.count; i++) argv[i + 1] = strdup(arguments[i].UTF8String);
    argv[argc - 1] = NULL;
    pid_t pid = 0;
    int rc = posix_spawn(&pid, program.fileSystemRepresentation, NULL, NULL, argv, environ);
    for (NSUInteger i = 0; i + 1 < argc; i++) free(argv[i]);
    free(argv);
    if (rc != 0) return rc;
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) return errno;
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 128;
}

@interface TMScanner ()
@property (nonatomic) BOOL running;
@property (nonatomic, strong) NSDictionary *currentStatus;
@end

@implementation TMScanner

+ (instancetype)sharedScanner {
    static TMScanner *scanner;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ scanner = [[TMScanner alloc] init]; });
    return scanner;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        TMEnsureDirectories();
        [self restoreStagingInternal];
        self.currentStatus = @{ @"state": @"idle", @"message": @"Ready" };
    }
    return self;
}

- (NSDictionary *)snapshot {
    NSArray *apps = TMInstalledApps();
    return @{ @"ok": @YES, @"apps": apps, @"appCount": @(apps.count), @"broadUIKit": @(TMBroadUIKitEnabled()) };
}

- (NSDictionary *)latestReport {
    NSArray *items = [self reports][@"reports"];
    return items.count ? items.firstObject : @{};
}

- (NSDictionary *)status {
    @synchronized (self) {
        return @{ @"ok": @YES, @"running": @(self.running), @"status": self.currentStatus ?: @{}, @"latestReport": [self latestReport] ?: @{} };
    }
}

- (NSDictionary *)reports {
    TMEnsureDirectories();
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *files = [fm contentsOfDirectoryAtPath:TMReportsRoot error:nil] ?: @[];
    files = [files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *name, NSDictionary *bindings) {
        (void)bindings;
        return [name hasSuffix:@".json"];
    }]];
    files = [files sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSDate *da = [fm attributesOfItemAtPath:[TMReportsRoot stringByAppendingPathComponent:a] error:nil][NSFileModificationDate] ?: NSDate.distantPast;
        NSDate *db = [fm attributesOfItemAtPath:[TMReportsRoot stringByAppendingPathComponent:b] error:nil][NSFileModificationDate] ?: NSDate.distantPast;
        return [db compare:da];
    }];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *file in files) {
        NSData *data = [NSData dataWithContentsOfFile:[TMReportsRoot stringByAppendingPathComponent:file]];
        if (!data) continue;
        NSDictionary *report = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([report isKindOfClass:NSDictionary.class]) [out addObject:report];
        if (out.count >= 25) break;
    }
    return @{ @"ok": @YES, @"reports": out };
}

- (NSInteger)restoreStagingInternal {
    TMEnsureDirectories();
    NSFileManager *fm = NSFileManager.defaultManager;
    NSInteger restored = 0;
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:TMStageRoot];
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *relative in enumerator) {
        if ([relative.pathExtension.lowercaseString isEqualToString:@"plist"]) [paths addObject:relative];
    }
    for (NSString *relative in paths) {
        NSString *src = [TMStageRoot stringByAppendingPathComponent:relative];
        NSString *dst = [TMTweakDir stringByAppendingPathComponent:src.lastPathComponent];
        if ([fm fileExistsAtPath:dst]) {
            [fm removeItemAtPath:src error:nil];
            continue;
        }
        if ([fm moveItemAtPath:src toPath:dst error:nil]) restored++;
    }
    NSArray *children = [fm contentsOfDirectoryAtPath:TMStageRoot error:nil] ?: @[];
    for (NSString *child in children) [fm removeItemAtPath:[TMStageRoot stringByAppendingPathComponent:child] error:nil];
    return restored;
}

- (NSDictionary *)restoreStaging {
    NSInteger count = [self restoreStagingInternal];
    return @{ @"ok": @YES, @"restored": @(count) };
}

- (BOOL)stageDisabledCandidates:(NSArray<NSDictionary *> *)candidates enabledNames:(NSSet<NSString *> *)enabled error:(NSError **)error {
    [self restoreStagingInternal];
    NSString *session = [TMStageRoot stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:session withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSDictionary *candidate in candidates) {
        NSString *name = candidate[@"name"];
        if ([enabled containsObject:name]) continue;
        NSString *src = candidate[@"plist"];
        if (![NSFileManager.defaultManager fileExistsAtPath:src]) continue;
        NSString *dst = [session stringByAppendingPathComponent:src.lastPathComponent];
        if (![NSFileManager.defaultManager moveItemAtPath:src toPath:dst error:error]) {
            [self restoreStagingInternal];
            return NO;
        }
    }
    return YES;
}

- (void)setState:(NSString *)state message:(NSString *)message target:(NSDictionary *)target extra:(NSDictionary *)extra {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:@{ @"state": state ?: @"", @"message": message ?: @"", @"updated": TMISODate() }];
    if (target) {
        d[@"targetName"] = target[@"name"] ?: @"";
        d[@"bundleID"] = target[@"bundleID"] ?: @"";
    }
    [d addEntriesFromDictionary:extra ?: @{}];
    @synchronized (self) { self.currentStatus = d; }
}

- (NSDictionary *)testTarget:(NSDictionary *)target candidates:(NSArray<NSDictionary *> *)candidates enabledNames:(NSSet<NSString *> *)enabled timeout:(NSInteger)timeout label:(NSString *)label {
    NSError *stageError = nil;
    if (![self stageDisabledCandidates:candidates enabledNames:enabled error:&stageError]) {
        return @{ @"label": label ?: @"test", @"survived": @NO, @"appeared": @NO, @"error": stageError.localizedDescription ?: @"staging failed" };
    }
    NSTimeInterval start = NSDate.date.timeIntervalSince1970;
    BOOL appeared = NO;
    BOOL survived = NO;
    @try {
        TMKillTarget(target);
        usleep(800000);
        BOOL launchRequested = TMLaunchBundle(target[@"bundleID"]);
        if (launchRequested) {
            for (int i = 0; i < 12; i++) {
                usleep(250000);
                if (TMPIDForTarget(target) > 0) { appeared = YES; break; }
            }
        }
        if (appeared) {
            NSTimeInterval deadline = NSDate.date.timeIntervalSince1970 + timeout;
            survived = YES;
            while (NSDate.date.timeIntervalSince1970 < deadline) {
                usleep(500000);
                if (TMPIDForTarget(target) <= 0) { survived = NO; break; }
            }
        }
        TMKillTarget(target);
    } @finally {
        [self restoreStagingInternal];
    }
    NSTimeInterval elapsed = NSDate.date.timeIntervalSince1970 - start;
    return @{ @"label": label ?: @"test", @"survived": @(survived), @"appeared": @(appeared), @"elapsed": @(elapsed), @"enabledCount": @(enabled.count), @"candidateCount": @(candidates.count) };
}

- (NSDictionary *)findApp:(NSString *)bundleID {
    for (NSDictionary *app in TMInstalledApps()) {
        if ([app[@"bundleID"] isEqualToString:bundleID]) return app;
    }
    return nil;
}

- (void)saveReport:(NSDictionary *)report jobID:(NSString *)jobID {
    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    if (data) [data writeToFile:[TMReportsRoot stringByAppendingPathComponent:[jobID stringByAppendingPathExtension:@"json"]] atomically:YES];
}

- (NSDictionary *)startScanForBundleID:(NSString *)bundleID timeout:(NSInteger)timeout {
    if (!bundleID.length) return @{ @"ok": @NO, @"error": @"Missing bundle identifier." };
    timeout = MAX(8, MIN(timeout, 120));
    @synchronized (self) {
        if (self.running) return @{ @"ok": @NO, @"error": @"A scan is already running." };
        self.running = YES;
    }
    NSDictionary *target = [self findApp:bundleID];
    if (!target) {
        @synchronized (self) { self.running = NO; }
        return @{ @"ok": @NO, @"error": @"App not found." };
    }
    NSString *jobID = NSUUID.UUID.UUIDString;
    [self setState:@"queued" message:@"Preparing candidate inventory" target:target extra:@{ @"jobID": jobID }];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self performScan:target timeout:timeout jobID:jobID];
    });
    return @{ @"ok": @YES, @"jobID": jobID, @"target": target };
}

- (void)performScan:(NSDictionary *)target timeout:(NSInteger)timeout jobID:(NSString *)jobID {
    NSString *started = TMISODate();
    NSMutableArray *timeline = [NSMutableArray array];
    NSString *result = @"unknown";
    NSString *culprit = @"";
    NSString *package = @"";
    NSString *confidence = @"none";
    NSArray<NSDictionary *> *candidates = TMCandidatesForTarget(target);

    @try {
        [self restoreStagingInternal];
        [self setState:@"baseline" message:[NSString stringWithFormat:@"Testing normal launch (%lu candidates)", (unsigned long)candidates.count] target:target extra:@{ @"jobID": jobID, @"candidateCount": @(candidates.count) }];
        NSSet *all = [NSSet setWithArray:[candidates valueForKey:@"name"]];
        NSDictionary *normal = [self testTarget:target candidates:candidates enabledNames:all timeout:timeout label:@"normal"];
        [timeline addObject:normal];

        if ([normal[@"survived"] boolValue]) {
            result = @"no_failure_reproduced";
            confidence = @"high";
        } else if (candidates.count == 0) {
            result = @"no_matching_tweaks";
            confidence = @"high";
        } else {
            [self setState:@"safe-baseline" message:@"Testing with all matching tweak filters disabled" target:target extra:@{ @"jobID": jobID }];
            NSDictionary *safe = [self testTarget:target candidates:candidates enabledNames:[NSSet set] timeout:timeout label:@"all-disabled"];
            [timeline addObject:safe];
            if (![safe[@"survived"] boolValue]) {
                result = @"failure_without_matching_tweaks";
                confidence = @"high";
            } else {
                NSMutableArray<NSDictionary *> *suspects = [candidates mutableCopy];
                NSInteger round = 1;
                while (suspects.count > 1) {
                    NSUInteger leftCount = (suspects.count + 1) / 2;
                    NSArray *left = [suspects subarrayWithRange:NSMakeRange(0, leftCount)];
                    NSArray *right = [suspects subarrayWithRange:NSMakeRange(leftCount, suspects.count - leftCount)];
                    NSSet *enabledLeft = [NSSet setWithArray:[left valueForKey:@"name"]];
                    [self setState:@"bisect" message:[NSString stringWithFormat:@"Round %ld: testing %lu of %lu suspects", (long)round, (unsigned long)left.count, (unsigned long)suspects.count] target:target extra:@{ @"jobID": jobID, @"round": @(round), @"remaining": @(suspects.count) }];
                    NSDictionary *test = [self testTarget:target candidates:candidates enabledNames:enabledLeft timeout:timeout label:[NSString stringWithFormat:@"bisect-%ld", (long)round]];
                    [timeline addObject:test];
                    NSArray *chosen = [test[@"survived"] boolValue] ? right : left;
                    suspects = [chosen mutableCopy];
                    round++;
                }

                NSDictionary *candidate = suspects.firstObject;
                culprit = candidate[@"name"] ?: @"";
                package = candidate[@"package"] ?: @"";
                [self setState:@"verify" message:[NSString stringWithFormat:@"A/B verifying %@", culprit] target:target extra:@{ @"jobID": jobID, @"culprit": culprit }];
                NSSet *onlyCulprit = culprit.length ? [NSSet setWithObject:culprit] : [NSSet set];
                NSDictionary *a = [self testTarget:target candidates:candidates enabledNames:onlyCulprit timeout:timeout label:@"culprit-only"];
                [timeline addObject:a];
                NSMutableSet *without = [NSMutableSet setWithArray:[candidates valueForKey:@"name"]];
                [without removeObject:culprit];
                NSDictionary *b = [self testTarget:target candidates:candidates enabledNames:without timeout:timeout label:@"culprit-disabled"];
                [timeline addObject:b];
                BOOL aDies = ![a[@"survived"] boolValue];
                BOOL bLives = [b[@"survived"] boolValue];
                if (aDies && bLives) {
                    result = @"single_tweak_confirmed";
                    confidence = @"high";
                } else if (aDies) {
                    result = @"multiple_failures_suspected";
                    confidence = @"medium";
                } else {
                    result = @"interaction_suspected";
                    confidence = @"medium";
                    NSUInteger cap = MIN((NSUInteger)12, candidates.count);
                    for (NSUInteger i = 0; i < cap; i++) {
                        NSDictionary *other = candidates[i];
                        NSString *otherName = other[@"name"];
                        if ([otherName isEqualToString:culprit]) continue;
                        NSSet *pair = [NSSet setWithObjects:culprit, otherName, nil];
                        NSDictionary *pairTest = [self testTarget:target candidates:candidates enabledNames:pair timeout:timeout label:[NSString stringWithFormat:@"pair-%@-%@", culprit, otherName]];
                        [timeline addObject:pairTest];
                        if (![pairTest[@"survived"] boolValue]) {
                            culprit = [NSString stringWithFormat:@"%@ + %@", culprit, otherName];
                            NSString *p2 = other[@"package"] ?: @"";
                            if (p2.length && package.length) package = [NSString stringWithFormat:@"%@ + %@", package, p2];
                            else if (p2.length) package = p2;
                            confidence = @"high";
                            break;
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        result = @"internal_error";
        confidence = @"none";
        [timeline addObject:@{ @"label": @"exception", @"error": exception.reason ?: exception.name ?: @"unknown" }];
    } @finally {
        [self restoreStagingInternal];
        TMKillTarget(target);
    }

    NSDictionary *report = @{ @"jobID": jobID,
                               @"started": started,
                               @"finished": TMISODate(),
                               @"targetName": target[@"name"] ?: @"",
                               @"bundleID": target[@"bundleID"] ?: @"",
                               @"executable": target[@"executable"] ?: @"",
                               @"result": result,
                               @"culprit": culprit,
                               @"package": package,
                               @"confidence": confidence,
                               @"candidateCount": @(candidates.count),
                               @"candidates": [candidates valueForKey:@"name"] ?: @[],
                               @"timeline": timeline };
    [self saveReport:report jobID:jobID];
    [self setState:@"complete" message:culprit.length ? [NSString stringWithFormat:@"Culprit: %@ (%@ confidence)", culprit, confidence] : result target:target extra:@{ @"jobID": jobID, @"culprit": culprit, @"result": result }];
    @synchronized (self) { self.running = NO; }
    sleep(1);
    TMLaunchBundle(TMSelfBundleID);
}

- (NSDictionary *)setTweak:(NSString *)name disabled:(BOOL)disabled {
    if (!name.length || [name containsString:@"/"]) return @{ @"ok": @NO, @"error": @"Invalid tweak name." };
    TMEnsureDirectories();
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *active = [TMTweakDir stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"plist"]];
    NSString *stored = [TMDisabledRoot stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"plist"]];
    NSError *error = nil;
    if (disabled) {
        if (![fm fileExistsAtPath:active]) return @{ @"ok": @NO, @"error": @"Active tweak filter not found." };
        [fm removeItemAtPath:stored error:nil];
        if (![fm moveItemAtPath:active toPath:stored error:&error]) return @{ @"ok": @NO, @"error": error.localizedDescription ?: @"Move failed." };
    } else {
        if (![fm fileExistsAtPath:stored]) return @{ @"ok": @NO, @"error": @"Disabled tweak filter not found." };
        if ([fm fileExistsAtPath:active]) return @{ @"ok": @NO, @"error": @"An active filter already exists." };
        if (![fm moveItemAtPath:stored toPath:active error:&error]) return @{ @"ok": @NO, @"error": error.localizedDescription ?: @"Move failed." };
    }
    return @{ @"ok": @YES, @"tweak": name, @"disabled": @(disabled) };
}

- (NSDictionary *)uninstallPackage:(NSString *)package {
    if (!package.length) return @{ @"ok": @NO, @"error": @"Missing package." };
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.+-_"];
    if ([[package stringByTrimmingCharactersInSet:allowed] length] != 0) return @{ @"ok": @NO, @"error": @"Invalid package identifier." };
    NSString *apt = @"/var/jb/usr/bin/apt-get";
    NSString *dpkg = @"/var/jb/usr/bin/dpkg";
    int rc;
    if ([NSFileManager.defaultManager isExecutableFileAtPath:apt]) rc = TMRunProgram(apt, @[@"remove", @"-y", package]);
    else rc = TMRunProgram(dpkg, @[@"--remove", package]);
    return rc == 0 ? @{ @"ok": @YES, @"package": package } : @{ @"ok": @NO, @"package": package, @"error": [NSString stringWithFormat:@"Package manager exited %d", rc] };
}

@end

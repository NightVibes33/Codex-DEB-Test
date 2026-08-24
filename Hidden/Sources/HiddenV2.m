#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface HIDFinding : NSObject
@property(nonatomic,copy) NSString *target;
@property(nonatomic,copy) NSString *category;
@property(nonatomic,copy) NSString *evidence;
@property(nonatomic,copy) NSString *path;
@property(nonatomic,copy) NSString *reason;
@property(nonatomic,assign) NSInteger score;
@end
@implementation HIDFinding
@end

static NSString * const HIDReportDirectory = @"/var/mobile/Library/Hidden";
static NSString * const HIDReportPath = @"/var/mobile/Library/Hidden/latest-scan.json";

static BOOL HIDWriteReport(NSArray<HIDFinding *> *findings, NSTimeInterval elapsed, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:HIDReportDirectory withIntermediateDirectories:YES attributes:nil error:error]) return NO;

    NSMutableDictionary<NSString *, NSNumber *> *categoryCounts = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *targetCounts = [NSMutableDictionary dictionary];
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    NSUInteger limit = MIN(findings.count, (NSUInteger)1000);

    for (NSUInteger i = 0; i < findings.count; i++) {
        HIDFinding *f = findings[i];
        categoryCounts[f.category] = @([categoryCounts[f.category] unsignedIntegerValue] + 1);
        targetCounts[f.target] = @([targetCounts[f.target] unsignedIntegerValue] + 1);
        if (i < limit) {
            [rows addObject:@{
                @"target": f.target ?: @"System",
                @"category": f.category ?: @"Unknown",
                @"evidence": f.evidence ?: @"",
                @"path": f.path ?: @"",
                @"reason": f.reason ?: @"",
                @"score": @(f.score)
            }];
        }
    }

    NSArray *sortedTargets = [targetCounts keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        if (a.unsignedIntegerValue > b.unsignedIntegerValue) return NSOrderedAscending;
        if (a.unsignedIntegerValue < b.unsignedIntegerValue) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    if (sortedTargets.count > 50) sortedTargets = [sortedTargets subarrayWithRange:NSMakeRange(0, 50)];

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";

    NSDictionary *report = @{
        @"schema": @4,
        @"mode": @"high-signal-system",
        @"generatedAt": [formatter stringFromDate:NSDate.date],
        @"elapsedSeconds": @(elapsed),
        @"os": NSProcessInfo.processInfo.operatingSystemVersionString ?: @"unknown",
        @"totalFindings": @(findings.count),
        @"reportedFindings": @(rows.count),
        @"categoryCounts": categoryCounts,
        @"topTargets": sortedTargets,
        @"scopes": @[
            @"Apple system applications",
            @"/System/Library/PrivateFrameworks",
            @"/System/Library/PreferenceBundles",
            @"/System/Library/PreferenceManifestsInternal"
        ],
        @"findings": rows
    };

    NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:error];
    if (!json) return NO;
    return [json writeToFile:HIDReportPath options:NSDataWritingAtomic error:error];
}

@interface HIDScanner : NSObject
@property(nonatomic,strong) NSMutableSet<NSString *> *dedupe;
@property(nonatomic,strong) NSMutableArray<HIDFinding *> *findings;
- (NSArray<HIDFinding *> *)scanWithProgress:(void (^)(NSString *status))progress;
@end

@implementation HIDScanner

- (instancetype)init {
    self = [super init];
    if (self) {
        _dedupe = [NSMutableSet set];
        _findings = [NSMutableArray array];
    }
    return self;
}

- (BOOL)string:(NSString *)value containsAny:(NSArray<NSString *> *)needles {
    NSString *lower = value.lowercaseString ?: @"";
    for (NSString *needle in needles) if ([lower containsString:needle]) return YES;
    return NO;
}

- (NSArray<NSString *> *)highSignalTerms {
    static NSArray<NSString *> *terms;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        terms = @[@"internal", @"prototype", @"experimental", @"experiment", @"debugmenu", @"debug_menu",
                  @"developmentmenu", @"developer mode", @"developermode", @"diagnostic", @"hidden",
                  @"featureflag", @"feature_flag", @"featuregate", @"feature_gate", @"featureoverride",
                  @"unsupported", @"eligibilityoverride", @"forceenable", @"force_enable", @"overrideenabled"];
    });
    return terms;
}

- (NSArray<NSString *> *)gateTerms {
    static NSArray<NSString *> *terms;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        terms = @[@"requiredcapabil", @"requireddevice", @"devicecapabil", @"hardwarecapabil", @"supports",
                  @"eligible", @"eligibility", @"availability", @"supporteddevice", @"devicefamily",
                  @"minimumos", @"minos", @"predicate", @"condition", @"visibility", @"restriction",
                  @"rollout", @"variant", @"trial", @"gestalt", @"sirimode", @"stagemanager",
                  @"alwaysondisplay", @"always_on", @"controlcenter", @"carplay"];
    });
    return terms;
}

- (BOOL)isNoise:(NSString *)s {
    NSString *l = s.lowercaseString ?: @"";
    NSArray *noise = @[@"dtsdkname", @"dtplatformname", @"dtplatformversion", @"dtcompiler", @"dtxcode",
                       @"uistatusbarhidden", @"unnotificationextensiondefaultcontenthidden",
                       @"nshidden", @"ishidden", @"hiddenextension", @"hiddenfiles"];
    return [self string:l containsAny:noise];
}

- (BOOL)isHighSignal:(NSString *)s {
    return [self string:s containsAny:[self highSignalTerms]];
}

- (BOOL)isGateSignal:(NSString *)s {
    return [self string:s containsAny:[self gateTerms]];
}

- (BOOL)isInteresting:(NSString *)s {
    if (s.length < 6 || s.length > 420 || [self isNoise:s]) return NO;
    if ([self isHighSignal:s] || [self isGateSignal:s]) return YES;
    NSString *l = s.lowercaseString;
    NSArray *systemSignals = @[@"springboard", @"siri", @"assistant", @"camera", @"multitasking",
                               @"lockscreen", @"coversheet", @"control center", @"controlcenter",
                               @"privateframework", @"internalsettings", @"developersettings"];
    return [self string:l containsAny:systemSignals] &&
           [self string:l containsAny:@[@"enable", @"disable", @"feature", @"setting", @"mode", @"gate", @"support"]];
}

- (NSString *)categoryForEvidence:(NSString *)s path:(NSString *)path {
    NSString *l = s.lowercaseString;
    NSString *p = path.lowercaseString;
    if ([p containsString:@"preferencemanifestsinternal"] ||
        [self string:l containsAny:@[@"internal", @"debug", @"diagnostic", @"developer"]]) return @"Internal / Developer";
    if ([self string:l containsAny:@[@"experiment", @"prototype", @"rollout", @"variant", @"trial"]]) return @"Experimental";
    if ([self string:l containsAny:@[@"capabil", @"eligible", @"availability", @"supporteddevice", @"devicefamily", @"gestalt"]]) return @"Capability Gate";
    if ([self string:l containsAny:@[@"predicate", @"condition", @"visibility", @"restriction", @"featureflag", @"feature_gate", @"featuregate"]]) return @"Feature Gate";
    if ([l containsString:@"hidden"]) return @"Hidden UI";
    return @"System Signal";
}

- (NSInteger)scoreForEvidence:(NSString *)s source:(NSString *)source {
    NSString *l = s.lowercaseString;
    NSString *p = source.lowercaseString;
    NSInteger score = 1;

    NSArray *veryHigh = @[@"preferencemanifestsinternal", @"internal", @"prototype", @"experimental", @"debugmenu",
                          @"developmentmenu", @"featureflag", @"feature_gate", @"featuregate", @"forceenable"];
    NSArray *high = @[@"diagnostic", @"developer", @"hidden", @"requiredcapabil", @"requireddevice",
                      @"eligibility", @"unsupported", @"predicate", @"visibility", @"restriction"];
    NSArray *medium = @[@"capabil", @"eligible", @"availability", @"supporteddevice", @"devicefamily",
                        @"rollout", @"variant", @"trial", @"gestalt", @"stagemanager", @"sirimode"];

    for (NSString *k in veryHigh) if ([l containsString:k] || [p containsString:k]) score += 7;
    for (NSString *k in high) if ([l containsString:k]) score += 4;
    for (NSString *k in medium) if ([l containsString:k]) score += 3;

    if ([p containsString:@"/preferencemanifestsinternal/"]) score += 8;
    if ([p containsString:@"developersettings.bundle"]) score += 5;
    if ([p containsString:@"privateframeworks"]) score += 2;
    if ([l hasPrefix:@"gate "]) score += 5;
    if ([l hasPrefix:@"specifier "]) score += 1;
    if ([l containsString:@" key="]) score += 1;
    if ([l containsString:@" get="] || [l containsString:@" set="]) score += 1;

    BOOL highSignal = [self isHighSignal:s];
    BOOL gateSignal = [self isGateSignal:s];
    if ([l hasPrefix:@"specifier "] && !highSignal && !gateSignal) score -= 6;

    return MAX(1, MIN(score, 40));
}

- (NSString *)reasonForEvidence:(NSString *)s path:(NSString *)path {
    NSString *l = s.lowercaseString;
    NSString *p = path.lowercaseString;
    if ([p containsString:@"preferencemanifestsinternal"]) return @"Ships in Apple's internal-only preference manifests";
    if ([l containsString:@"prototype"] || [l containsString:@"experimental"] || [l containsString:@"experiment"]) return @"Explicit experimental/prototype marker";
    if ([l containsString:@"internal"] || [l containsString:@"debug"] || [l containsString:@"diagnostic"] || [l containsString:@"developer"]) return @"Internal, developer, or diagnostics marker";
    if ([self isGateSignal:s]) return @"Conditional device/capability/feature gate";
    if ([l containsString:@"hidden"]) return @"Explicit hidden-state marker";
    return @"System feature signal";
}

- (void)addEvidence:(NSString *)evidence target:(NSString *)target path:(NSString *)path {
    NSString *trim = [evidence stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![self isInteresting:trim]) return;
    NSString *key = [NSString stringWithFormat:@"%@|%@", target ?: @"System", trim];
    if ([self.dedupe containsObject:key]) return;
    [self.dedupe addObject:key];

    HIDFinding *f = [HIDFinding new];
    f.target = target ?: @"System";
    f.category = [self categoryForEvidence:trim path:path ?: @""];
    f.evidence = trim;
    f.path = path ?: @"";
    f.reason = [self reasonForEvidence:trim path:path ?: @""];
    f.score = [self scoreForEvidence:trim source:path ?: @""];
    [self.findings addObject:f];
}

- (id)valueForCaseInsensitiveKey:(NSString *)wanted dictionary:(NSDictionary *)dictionary {
    for (id rawKey in dictionary) {
        NSString *key = [[rawKey description] lowercaseString];
        if ([key isEqualToString:wanted.lowercaseString]) return dictionary[rawKey];
    }
    return nil;
}

- (void)addStructuredSummaryForDictionary:(NSDictionary *)dictionary target:(NSString *)target path:(NSString *)path prefix:(NSString *)prefix {
    NSArray<NSString *> *fields = @[@"label", @"key", @"get", @"set", @"defaults", @"identifier", @"id",
                                    @"requiredCapabilities", @"requiredDeviceCapabilities", @"condition", @"predicate",
                                    @"visibility", @"restriction", @"isInternal", @"internal", @"developer", @"debug",
                                    @"supportedDevices", @"deviceFamilies", @"minimumOSVersion", @"featureFlag", @"enabled"];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    BOOL signal = NO;
    BOOL gateField = NO;
    NSSet *gateFieldNames = [NSSet setWithArray:@[@"requiredcapabilities", @"requireddevicecapabilities", @"condition", @"predicate",
                                                   @"visibility", @"restriction", @"isinternal", @"internal", @"developer", @"debug",
                                                   @"supporteddevices", @"devicefamilies", @"minimumosversion", @"featureflag"]];

    for (NSString *field in fields) {
        id value = [self valueForCaseInsensitiveKey:field dictionary:dictionary];
        if (!value) continue;
        NSString *text = [value description];
        if (text.length > 120) text = [text substringToIndex:120];
        if ([self isInteresting:text] || [gateFieldNames containsObject:field.lowercaseString]) signal = YES;
        if ([gateFieldNames containsObject:field.lowercaseString]) gateField = YES;
        [parts addObject:[NSString stringWithFormat:@"%@=%@", field, text]];
    }
    if (!signal || parts.count == 0) return;
    NSString *kind = gateField ? @"Gate" : @"Specifier";
    NSString *summary = [NSString stringWithFormat:@"%@ %@ | %@", kind, prefix.length ? prefix : @"item", [parts componentsJoinedByString:@" | "]];
    if (summary.length > 420) summary = [summary substringToIndex:420];
    [self addEvidence:summary target:target path:path];
}

- (void)scanStructuredObject:(id)obj target:(NSString *)target path:(NSString *)path prefix:(NSString *)prefix depth:(NSUInteger)depth {
    if (!obj || depth > 7) return;
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = (NSDictionary *)obj;
        [self addStructuredSummaryForDictionary:dictionary target:target path:path prefix:prefix];
        [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            NSString *k = [key description];
            NSString *full = prefix.length ? [NSString stringWithFormat:@"%@.%@", prefix, k] : k;
            if ([self isInteresting:k]) [self addEvidence:full target:target path:path];
            if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]) {
                NSString *joined = [NSString stringWithFormat:@"%@ = %@", full, value];
                if ([self isInteresting:joined]) [self addEvidence:joined target:target path:path];
            } else {
                [self scanStructuredObject:value target:target path:path prefix:full depth:depth + 1];
            }
        }];
    } else if ([obj isKindOfClass:NSArray.class]) {
        NSUInteger i = 0;
        for (id value in (NSArray *)obj) {
            [self scanStructuredObject:value target:target path:path prefix:[NSString stringWithFormat:@"%@[%lu]", prefix, (unsigned long)i] depth:depth + 1];
            if (++i >= 120) break;
        }
    }
}

- (void)scanPlistAtPath:(NSString *)path target:(NSString *)target {
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attrs fileSize] > (4ULL * 1024ULL * 1024ULL)) return;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data.length) return;
    NSPropertyListFormat format;
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:nil];
    if (obj) [self scanStructuredObject:obj target:target path:path prefix:@"" depth:0];
}

- (void)scanJSONAtPath:(NSString *)path target:(NSString *)target {
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attrs fileSize] > (4ULL * 1024ULL * 1024ULL)) return;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data.length) return;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (obj) [self scanStructuredObject:obj target:target path:path prefix:@"" depth:0];
}

- (void)scanASCIIData:(NSData *)data range:(NSRange)range target:(NSString *)target path:(NSString *)path emitted:(NSUInteger *)emitted {
    const unsigned char *bytes = data.bytes;
    NSMutableData *token = [NSMutableData dataWithCapacity:128];
    NSUInteger end = NSMaxRange(range);
    for (NSUInteger i = range.location; i < end && *emitted < 60; i++) {
        unsigned char c = bytes[i];
        BOOL printable = (c >= 0x20 && c <= 0x7e);
        if (printable && token.length < 421) {
            [token appendBytes:&c length:1];
        } else {
            if (token.length >= 6) {
                NSString *s = [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding];
                if (s && [self isInteresting:s]) { [self addEvidence:s target:target path:path]; (*emitted)++; }
            }
            [token setLength:0];
        }
    }
    if (token.length >= 6 && *emitted < 60) {
        NSString *s = [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding];
        if (s && [self isInteresting:s]) { [self addEvidence:s target:target path:path]; (*emitted)++; }
    }
}

- (void)scanTextAtPath:(NSString *)path target:(NSString *)target {
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attrs fileSize];
    if (size == 0 || size > (96ULL * 1024ULL * 1024ULL)) return;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data.length) return;
    const NSUInteger slice = 1U * 1024U * 1024U;
    NSUInteger emitted = 0;
    if (data.length <= slice * 2) {
        [self scanASCIIData:data range:NSMakeRange(0, data.length) target:target path:path emitted:&emitted];
    } else {
        [self scanASCIIData:data range:NSMakeRange(0, slice) target:target path:path emitted:&emitted];
        if (emitted < 60) [self scanASCIIData:data range:NSMakeRange(data.length - slice, slice) target:target path:path emitted:&emitted];
    }
}

- (BOOL)shouldScanSystemAppName:(NSString *)name {
    NSArray *priority = @[@"springboard", @"preferences", @"settings", @"camera", @"photo", @"mobilesms", @"message",
                          @"facetime", @"phone", @"appstore", @"store", @"files", @"mobilefile", @"safari", @"shortcuts",
                          @"home", @"health", @"music", @"tips", @"findmy", @"compass", @"weather"];
    return [self string:name containsAny:priority];
}

- (BOOL)shouldScanPrivateFrameworkName:(NSString *)name {
    NSArray *priority = @[@"springboard", @"controlcenter", @"preference", @"settings", @"camera", @"photo", @"siri", @"assistant",
                          @"intelligence", @"gestalt", @"frontboard", @"backboard", @"boardservices", @"chat", @"message", @"telephony",
                          @"call", @"carplay", @"multitask", @"homescreen", @"home", @"appstore", @"storekit", @"trial", @"feature",
                          @"proactive", @"coreduet", @"lockscreen", @"coversheet", @"chrono", @"sharing", @"accessibility", @"account",
                          @"display", @"battery", @"thermal", @"wifi"];
    return [self string:name containsAny:priority];
}

- (void)scanBundle:(NSString *)bundlePath target:(NSString *)target {
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    if (info) [self scanStructuredObject:info target:target path:infoPath prefix:@"Info" depth:0];

    NSString *exe = info[@"CFBundleExecutable"];
    NSString *exePath = nil;
    if (exe.length) exePath = [bundlePath stringByAppendingPathComponent:exe];
    else {
        NSString *candidateName = bundlePath.lastPathComponent.stringByDeletingPathExtension;
        NSString *candidate = [bundlePath stringByAppendingPathComponent:candidateName];
        if ([NSFileManager.defaultManager isReadableFileAtPath:candidate]) exePath = candidate;
    }
    if (exePath.length) [self scanTextAtPath:exePath target:target];

    NSDirectoryEnumerator *en = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:bundlePath]
                                                    includingPropertiesForKeys:@[NSURLIsRegularFileKey]
                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                  errorHandler:nil];
    NSUInteger resourceCount = 0;
    for (NSURL *url in en) {
        NSString *ext = url.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"json"]) { [self scanJSONAtPath:url.path target:target]; resourceCount++; }
        else if ([ext isEqualToString:@"plist"] || [ext isEqualToString:@"strings"]) { [self scanPlistAtPath:url.path target:target]; resourceCount++; }
        if (resourceCount >= 16) break;
    }
}

- (NSArray<HIDFinding *> *)scanWithProgress:(void (^)(NSString *))progress {
    [self.findings removeAllObjects];
    [self.dedupe removeAllObjects];
    NSFileManager *fm = NSFileManager.defaultManager;

    NSArray<NSString *> *appRoots = @[@"/System/Applications", @"/Applications", @"/System/Library/CoreServices"];
    NSUInteger appCount = 0;
    for (NSString *root in appRoots) {
        for (NSString *name in [fm contentsOfDirectoryAtPath:root error:nil]) {
            if (![name.pathExtension.lowercaseString isEqualToString:@"app"] || ![self shouldScanSystemAppName:name]) continue;
            NSString *path = [root stringByAppendingPathComponent:name];
            NSString *target = name.stringByDeletingPathExtension;
            if (progress) progress([NSString stringWithFormat:@"Scanning %@…", target]);
            @autoreleasepool { [self scanBundle:path target:target]; }
            if (++appCount >= 20) break;
        }
    }

    NSString *pfRoot = @"/System/Library/PrivateFrameworks";
    NSUInteger fwCount = 0;
    for (NSString *name in [fm contentsOfDirectoryAtPath:pfRoot error:nil]) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"framework"] || ![self shouldScanPrivateFrameworkName:name]) continue;
        NSString *path = [pfRoot stringByAppendingPathComponent:name];
        NSString *target = [NSString stringWithFormat:@"%@ (PrivateFramework)", name.stringByDeletingPathExtension];
        if (progress && fwCount % 8 == 0) progress([NSString stringWithFormat:@"Scanning PrivateFrameworks… %lu", (unsigned long)fwCount]);
        @autoreleasepool { [self scanBundle:path target:target]; }
        if (++fwCount >= 48) break;
    }

    NSArray<NSString *> *prefRoots = @[@"/System/Library/PreferenceBundles", @"/System/Library/PreferenceManifestsInternal"];
    for (NSString *root in prefRoots) {
        if (progress) progress([NSString stringWithFormat:@"Scanning %@…", root.lastPathComponent]);
        NSUInteger prefCount = 0;
        for (NSString *name in [fm contentsOfDirectoryAtPath:root error:nil]) {
            NSString *path = [root stringByAppendingPathComponent:name];
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:path isDirectory:&isDir]) continue;
            if (isDir) [self scanBundle:path target:[NSString stringWithFormat:@"Settings/%@", name.stringByDeletingPathExtension]];
            else if ([name.pathExtension.lowercaseString isEqualToString:@"plist"]) [self scanPlistAtPath:path target:@"Settings"];
            else if ([name.pathExtension.lowercaseString isEqualToString:@"json"]) [self scanJSONAtPath:path target:@"Settings"];
            if (++prefCount >= 100) break;
        }
    }

    [self.findings sortUsingComparator:^NSComparisonResult(HIDFinding *a, HIDFinding *b) {
        if (a.score != b.score) return a.score > b.score ? NSOrderedAscending : NSOrderedDescending;
        NSComparisonResult targetOrder = [a.target compare:b.target options:NSCaseInsensitiveSearch];
        if (targetOrder != NSOrderedSame) return targetOrder;
        return [a.evidence compare:b.evidence options:NSCaseInsensitiveSearch];
    }];
    return self.findings.copy;
}
@end

@interface HIDViewController : UITableViewController <UISearchResultsUpdating>
@property(nonatomic,strong) NSArray<HIDFinding *> *allFindings;
@property(nonatomic,strong) NSArray<HIDFinding *> *visibleFindings;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UISearchController *searchController;
@property(nonatomic,strong) UISegmentedControl *filterControl;
@property(nonatomic,assign) BOOL scanRunning;
@end

@implementation HIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Hidden";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.tableView.rowHeight = 88.0;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search Apple internals…";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Scan" style:UIBarButtonItemStyleDone target:self action:@selector(runScan)];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 122)];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 8, 700, 54)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"Apple system internals only\nHigh-signal discovery engine";
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [header addSubview:self.statusLabel];

    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"Top", @"Gates", @"Internal", @"Experimental", @"All"]];
    self.filterControl.frame = CGRectMake(20, 72, 700, 34);
    self.filterControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.filterControl.selectedSegmentIndex = 0;
    [self.filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [header addSubview:self.filterControl];
    self.tableView.tableHeaderView = header;

    self.allFindings = @[];
    self.visibleFindings = @[];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf runScan]; });
}

- (BOOL)finding:(HIDFinding *)finding matchesSelectedFilter:(NSInteger)filter {
    switch (filter) {
        case 0: return finding.score >= 14;
        case 1: return [finding.category isEqualToString:@"Capability Gate"] || [finding.category isEqualToString:@"Feature Gate"];
        case 2: return [finding.category isEqualToString:@"Internal / Developer"];
        case 3: return [finding.category isEqualToString:@"Experimental"];
        default: return YES;
    }
}

- (void)refreshVisibleFindings {
    NSString *query = self.searchController.searchBar.text.lowercaseString ?: @"";
    NSInteger filter = self.filterControl.selectedSegmentIndex;
    self.visibleFindings = [self.allFindings filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HIDFinding *f, NSDictionary *bindings) {
        (void)bindings;
        if (![self finding:f matchesSelectedFilter:filter]) return NO;
        if (query.length == 0) return YES;
        NSString *haystack = [[NSString stringWithFormat:@"%@ %@ %@ %@ %@", f.target, f.category, f.evidence, f.path, f.reason] lowercaseString];
        return [haystack containsString:query];
    }]];
    [self.tableView reloadData];
}

- (void)filterChanged { [self refreshVisibleFindings]; }

- (void)runScan {
    if (self.scanRunning) return;
    self.scanRunning = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.statusLabel.text = @"Scanning Apple system internals…";
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDate *started = NSDate.date;
        HIDScanner *scanner = [HIDScanner new];
        NSArray *results = [scanner scanWithProgress:^(NSString *status) {
            dispatch_async(dispatch_get_main_queue(), ^{ weakSelf.statusLabel.text = status; });
        }];
        NSTimeInterval elapsed = -[started timeIntervalSinceNow];
        NSError *reportError = nil;
        BOOL reportSaved = HIDWriteReport(results, elapsed, &reportError);
        NSUInteger topCount = 0;
        for (HIDFinding *f in results) if (f.score >= 14) topCount++;
        NSString *reportStatus = reportSaved ? @"Report saved." : [NSString stringWithFormat:@"Report error: %@", reportError.localizedDescription ?: @"unknown"];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.allFindings = results;
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"%lu high-signal / %lu total • %.1fs\n%@", (unsigned long)topCount, (unsigned long)results.count, elapsed, reportStatus];
            weakSelf.scanRunning = NO;
            weakSelf.navigationItem.rightBarButtonItem.enabled = YES;
            [weakSelf refreshVisibleFindings];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController { (void)searchController; [self refreshVisibleFindings]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.visibleFindings.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"finding";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    HIDFinding *f = self.visibleFindings[indexPath.row];
    cell.textLabel.text = f.evidence;
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@ • %ld", f.target, f.category, (long)f.score];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HIDFinding *f = self.visibleFindings[indexPath.row];
    NSString *msg = [NSString stringWithFormat:@"%@\n\nConfidence score: %ld\n\nEvidence:\n%@\n\nSource:\n%@", f.reason, (long)f.score, f.evidence, f.path];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ • %@", f.target, f.category] message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Copy Evidence" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { UIPasteboard.generalPasteboard.string = f.evidence; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Copy Path" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { UIPasteboard.generalPasteboard.string = f.path; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@interface HIDAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation HIDAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    HIDViewController *vc = [[HIDViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:vc];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(HIDAppDelegate.class)); }
}

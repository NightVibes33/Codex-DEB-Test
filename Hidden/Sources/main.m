#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface HIDFinding : NSObject
@property(nonatomic,copy) NSString *target;
@property(nonatomic,copy) NSString *category;
@property(nonatomic,copy) NSString *evidence;
@property(nonatomic,copy) NSString *path;
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
        @"schema": @3,
        @"mode": @"fast-system",
        @"generatedAt": [formatter stringFromDate:NSDate.date],
        @"elapsedSeconds": @(elapsed),
        @"os": NSProcessInfo.processInfo.operatingSystemVersionString ?: @"unknown",
        @"totalFindings": @(findings.count),
        @"reportedFindings": @(rows.count),
        @"categoryCounts": categoryCounts,
        @"topTargets": sortedTargets,
        @"scopes": @[
            @"priority Apple system applications",
            @"priority /System/Library/PrivateFrameworks",
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
    NSString *lower = value.lowercaseString;
    for (NSString *needle in needles) if ([lower containsString:needle]) return YES;
    return NO;
}

- (BOOL)isNoise:(NSString *)s {
    NSString *l = s.lowercaseString;
    NSArray *noise = @[@"dtsdkname", @"dtplatformname", @"dtplatformversion", @"dtcompiler", @"dtxcode",
                       @"uistatusbarhidden", @"unnotificationextensiondefaultcontenthidden"];
    return [self string:l containsAny:noise];
}

- (NSString *)categoryForString:(NSString *)s {
    NSString *l = s.lowercaseString;
    if ([self string:l containsAny:@[@"debug", @"diagnostic", @"developer", @"internalmenu", @"devmenu"]]) return @"Developer / Diagnostics";
    if ([self string:l containsAny:@[@"experiment", @"prototype", @"trialfeature", @"variant", @"rollout"]]) return @"Experimental";
    if ([self string:l containsAny:@[@"capability", @"eligible", @"availability", @"deviceclass", @"hardware", @"supports"]]) return @"Capability Gate";
    if ([self string:l containsAny:@[@"controller", @"viewcontroller", @"hidden", @"menu", @"specifier", @"preference"]]) return @"Hidden UI";
    return @"Feature Flag";
}

- (NSInteger)scoreForString:(NSString *)s source:(NSString *)source {
    NSString *l = s.lowercaseString;
    NSInteger score = 1;
    NSArray *high = @[@"experimental", @"prototype", @"internal", @"diagnostic", @"debugmenu", @"developer", @"hidden", @"featureflag"];
    NSArray *medium = @[@"feature", @"enabled", @"enable", @"disabled", @"supports", @"capability", @"eligible", @"variant", @"specifier", @"preference"];
    for (NSString *k in high) if ([l containsString:k]) score += 5;
    for (NSString *k in medium) if ([l containsString:k]) score += 2;
    if ([l hasPrefix:@"specifier "]) score += 4;
    if ([l containsString:@" key="]) score += 2;
    if ([l containsString:@" set="] || [l containsString:@" get="]) score += 2;
    NSString *ext = source.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"plist"] || [ext isEqualToString:@"json"] || [ext isEqualToString:@"strings"]) score += 2;
    if ([s rangeOfString:@" "].location == NSNotFound && s.length < 90) score += 1;
    return MIN(score, 20);
}

- (BOOL)isInteresting:(NSString *)s {
    if (s.length < 6 || s.length > 320 || [self isNoise:s]) return NO;
    static NSArray<NSString *> *terms;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        terms = @[@"experimental", @"experiment", @"prototype", @"internal", @"debug", @"diagnostic", @"developer",
                  @"hidden", @"featureflag", @"feature_flag", @"featureenabled", @"enablefeature", @"disablefeature",
                  @"capability", @"eligible", @"availability", @"supports", @"unsupported", @"specifier", @"viewcontroller",
                  @"controlcenter", @"springboard", @"stage manager", @"stagemanager", @"siri", @"assistant", @"camera",
                  @"multitasking", @"alwayson", @"always_on", @"carplay", @"internalsettings", @"developmentmenu",
                  @"featureoverride", @"featuregate", @"feature_gate", @"rollout", @"trial", @"hardwarecapability"];
    });
    return [self string:s containsAny:terms];
}

- (void)addEvidence:(NSString *)evidence target:(NSString *)target path:(NSString *)path {
    if (![self isInteresting:evidence]) return;
    NSString *trim = [evidence stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trim.length == 0) return;
    NSString *key = [NSString stringWithFormat:@"%@|%@", target ?: @"System", trim];
    if ([self.dedupe containsObject:key]) return;
    [self.dedupe addObject:key];

    HIDFinding *f = [HIDFinding new];
    f.target = target ?: @"System";
    f.category = [self categoryForString:trim];
    f.evidence = trim;
    f.path = path ?: @"";
    f.score = [self scoreForString:trim source:path ?: @""];
    [self.findings addObject:f];
}

- (id)valueForCaseInsensitiveKey:(NSString *)wanted dictionary:(NSDictionary *)dictionary {
    for (id rawKey in dictionary) {
        NSString *key = [[rawKey description] lowercaseString];
        if ([key isEqualToString:wanted.lowercaseString]) return dictionary[rawKey];
    }
    return nil;
}

- (void)addSpecifierSummaryForDictionary:(NSDictionary *)dictionary target:(NSString *)target path:(NSString *)path prefix:(NSString *)prefix {
    NSArray<NSString *> *fieldNames = @[@"label", @"key", @"get", @"set", @"defaults", @"identifier", @"id", @"postnotification"];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    BOOL useful = NO;
    for (NSString *field in fieldNames) {
        id value = [self valueForCaseInsensitiveKey:field dictionary:dictionary];
        if (![value isKindOfClass:NSString.class] && ![value isKindOfClass:NSNumber.class]) continue;
        NSString *text = [value description];
        if ([self isInteresting:text]) useful = YES;
        if (text.length > 100) text = [text substringToIndex:100];
        [parts addObject:[NSString stringWithFormat:@"%@=%@", field, text]];
    }
    if (!useful || parts.count < 2) return;
    NSString *summary = [NSString stringWithFormat:@"Specifier %@ | %@", prefix.length ? prefix : @"item", [parts componentsJoinedByString:@" | "]];
    if (summary.length > 320) summary = [summary substringToIndex:320];
    [self addEvidence:summary target:target path:path];
}

- (void)scanStructuredObject:(id)obj target:(NSString *)target path:(NSString *)path prefix:(NSString *)prefix depth:(NSUInteger)depth {
    if (!obj || depth > 7) return;
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = (NSDictionary *)obj;
        [self addSpecifierSummaryForDictionary:dictionary target:target path:path prefix:prefix];
        [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            NSString *k = [key description];
            NSString *full = prefix.length ? [NSString stringWithFormat:@"%@.%@", prefix, k] : k;
            [self addEvidence:full target:target path:path];
            if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]) {
                [self addEvidence:[NSString stringWithFormat:@"%@ = %@", full, value] target:target path:path];
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
    for (NSUInteger i = range.location; i < end && *emitted < 100; i++) {
        unsigned char c = bytes[i];
        BOOL printable = (c >= 0x20 && c <= 0x7e);
        if (printable && token.length < 321) {
            [token appendBytes:&c length:1];
        } else {
            if (token.length >= 6) {
                NSString *s = [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding];
                if (s && [self isInteresting:s]) {
                    [self addEvidence:s target:target path:path];
                    (*emitted)++;
                }
            }
            [token setLength:0];
        }
    }
    if (token.length >= 6 && *emitted < 100) {
        NSString *s = [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding];
        if (s && [self isInteresting:s]) {
            [self addEvidence:s target:target path:path];
            (*emitted)++;
        }
    }
}

- (void)scanTextAtPath:(NSString *)path target:(NSString *)target {
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attrs fileSize];
    if (size == 0 || size > (160ULL * 1024ULL * 1024ULL)) return;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data.length) return;

    const NSUInteger slice = 8U * 1024U * 1024U;
    NSUInteger emitted = 0;
    if (data.length <= slice * 2) {
        [self scanASCIIData:data range:NSMakeRange(0, data.length) target:target path:path emitted:&emitted];
    } else {
        [self scanASCIIData:data range:NSMakeRange(0, slice) target:target path:path emitted:&emitted];
        if (emitted < 100) [self scanASCIIData:data range:NSMakeRange(data.length - slice, slice) target:target path:path emitted:&emitted];
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
                          @"mobileactivation", @"mobilekeybag", @"biometric", @"passcode", @"display", @"battery", @"thermal", @"wifi"];
    return [self string:name containsAny:priority];
}

- (void)scanBundle:(NSString *)bundlePath target:(NSString *)target {
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    if (info) [self scanStructuredObject:info target:target path:infoPath prefix:@"Info" depth:0];

    NSString *exe = info[@"CFBundleExecutable"];
    NSString *exePath = nil;
    if (exe.length) {
        exePath = [bundlePath stringByAppendingPathComponent:exe];
    } else {
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
        if ([ext isEqualToString:@"json"]) {
            [self scanJSONAtPath:url.path target:target];
            resourceCount++;
        } else if ([ext isEqualToString:@"plist"] || [ext isEqualToString:@"strings"]) {
            [self scanPlistAtPath:url.path target:target];
            resourceCount++;
        }
        if (resourceCount >= 32) break;
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
            if (++appCount >= 28) break;
        }
    }

    NSString *pfRoot = @"/System/Library/PrivateFrameworks";
    NSUInteger fwCount = 0;
    for (NSString *name in [fm contentsOfDirectoryAtPath:pfRoot error:nil]) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"framework"] || ![self shouldScanPrivateFrameworkName:name]) continue;
        NSString *path = [pfRoot stringByAppendingPathComponent:name];
        NSString *target = [NSString stringWithFormat:@"%@ (PrivateFramework)", name.stringByDeletingPathExtension];
        if (progress && fwCount % 8 == 0) progress([NSString stringWithFormat:@"Scanning priority PrivateFrameworks… %lu", (unsigned long)fwCount]);
        @autoreleasepool { [self scanBundle:path target:target]; }
        if (++fwCount >= 90) break;
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
            if (++prefCount >= 180) break;
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
    self.tableView.rowHeight = 78.0;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search SpringBoard, Siri, Camera…";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Scan" style:UIBarButtonItemStyleDone target:self action:@selector(runScan)];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 116)];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 8, 700, 50)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"Apple system discovery engine\nPreparing fast system scan…";
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [header addSubview:self.statusLabel];

    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"Top", @"Gates", @"Experimental", @"Dev", @"All"]];
    self.filterControl.frame = CGRectMake(20, 68, 700, 34);
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
        case 0: return finding.score >= 10;
        case 1: return [finding.category isEqualToString:@"Capability Gate"] || [finding.evidence.lowercaseString containsString:@" key="] || [finding.evidence.lowercaseString containsString:@" set="];
        case 2: return [finding.category isEqualToString:@"Experimental"];
        case 3: return [finding.category isEqualToString:@"Developer / Diagnostics"];
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
        NSString *haystack = [[NSString stringWithFormat:@"%@ %@ %@ %@", f.target, f.category, f.evidence, f.path] lowercaseString];
        return [haystack containsString:query];
    }]];
    [self.tableView reloadData];
}

- (void)filterChanged {
    [self refreshVisibleFindings];
}

- (void)runScan {
    if (self.scanRunning) return;
    self.scanRunning = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.statusLabel.text = @"Starting fast system scan…";
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDate *started = NSDate.date;
        HIDScanner *scanner = [HIDScanner new];
        NSArray *results = [scanner scanWithProgress:^(NSString *status) {
            dispatch_async(dispatch_get_main_queue(), ^{ weakSelf.statusLabel.text = status; });
        }];
        NSTimeInterval elapsed = -[started timeIntervalSinceNow];
        NSError *reportError = nil;
        BOOL reportSaved = HIDWriteReport(results, elapsed, &reportError);
        NSString *reportStatus = reportSaved ? [NSString stringWithFormat:@"Completed in %.1fs. Report saved.", elapsed] : [NSString stringWithFormat:@"Report error: %@", reportError.localizedDescription ?: @"unknown"];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.allFindings = results;
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"%lu discoveries ranked by confidence.\n%@", (unsigned long)results.count, reportStatus];
            weakSelf.scanRunning = NO;
            weakSelf.navigationItem.rightBarButtonItem.enabled = YES;
            [weakSelf refreshVisibleFindings];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    (void)searchController;
    [self refreshVisibleFindings];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.visibleFindings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"finding";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    HIDFinding *f = self.visibleFindings[indexPath.row];
    cell.textLabel.text = f.evidence;
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  •  %@  •  score %ld", f.target, f.category, (long)f.score];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HIDFinding *f = self.visibleFindings[indexPath.row];
    NSString *msg = [NSString stringWithFormat:@"Category: %@\nScore: %ld\n\nEvidence / gate:\n%@\n\nSource:\n%@", f.category, (long)f.score, f.evidence, f.path];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:f.target message:msg preferredStyle:UIAlertControllerStyleAlert];
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

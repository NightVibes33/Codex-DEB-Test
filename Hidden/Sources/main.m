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

- (NSString *)categoryForString:(NSString *)s {
    NSString *l = s.lowercaseString;
    if ([l containsString:@"debug"] || [l containsString:@"diagnostic"] || [l containsString:@"developer"] || [l containsString:@"internalmenu"]) return @"Developer / Diagnostics";
    if ([l containsString:@"experiment"] || [l containsString:@"prototype"] || [l containsString:@"trialfeature"] || [l containsString:@"variant"]) return @"Experimental";
    if ([l containsString:@"support"] || [l containsString:@"capability"] || [l containsString:@"eligible"] || [l containsString:@"availability"] || [l containsString:@"deviceclass"]) return @"Capability Gate";
    if ([l containsString:@"controller"] || [l containsString:@"viewcontroller"] || [l containsString:@"hidden"] || [l containsString:@"menu"] || [l containsString:@"specifier"]) return @"Hidden UI";
    return @"Feature Flag";
}

- (NSInteger)scoreForString:(NSString *)s source:(NSString *)source {
    NSString *l = s.lowercaseString;
    NSInteger score = 1;
    NSArray *high = @[@"experimental", @"prototype", @"internal", @"diagnostic", @"debugmenu", @"developer", @"hidden"];
    NSArray *medium = @[@"feature", @"enabled", @"enable", @"disabled", @"supports", @"capability", @"eligible", @"variant", @"specifier"];
    for (NSString *k in high) if ([l containsString:k]) score += 5;
    for (NSString *k in medium) if ([l containsString:k]) score += 2;
    if ([source.pathExtension.lowercaseString isEqualToString:@"plist"] || [source.pathExtension.lowercaseString isEqualToString:@"json"]) score += 2;
    if ([s rangeOfString:@" "].location == NSNotFound && s.length < 90) score += 1;
    return MIN(score, 20);
}

- (BOOL)isInteresting:(NSString *)s {
    if (s.length < 6 || s.length > 180) return NO;
    NSString *l = s.lowercaseString;
    static NSArray<NSString *> *terms;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        terms = @[@"experimental", @"experiment", @"prototype", @"internal", @"debug", @"diagnostic", @"developer",
                  @"hidden", @"featureflag", @"feature_flag", @"featureenabled", @"enablefeature", @"disablefeature",
                  @"capability", @"eligible", @"availability", @"supports", @"unsupported", @"specifier", @"viewcontroller",
                  @"controlcenter", @"springboard", @"stage manager", @"stagemanager", @"siri", @"assistant", @"camera",
                  @"multitasking", @"alwayson", @"always_on", @"carplay", @"internalsettings", @"developmentmenu"];
    });
    for (NSString *term in terms) if ([l containsString:term]) return YES;
    return NO;
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
    f.path = path;
    f.score = [self scoreForString:trim source:path];
    [self.findings addObject:f];
}

- (void)scanStructuredObject:(id)obj target:(NSString *)target path:(NSString *)path prefix:(NSString *)prefix depth:(NSUInteger)depth {
    if (!obj || depth > 8) return;
    if ([obj isKindOfClass:NSDictionary.class]) {
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
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
            i++;
            if (i > 200) break;
        }
    }
}

- (void)scanPlistAtPath:(NSString *)path target:(NSString *)target {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data.length) return;
    NSPropertyListFormat fmt;
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&fmt error:nil];
    if (obj) [self scanStructuredObject:obj target:target path:path prefix:@"" depth:0];
}

- (void)scanTextAtPath:(NSString *)path target:(NSString *)target {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attrs fileSize];
    if (size == 0 || size > (80ULL * 1024ULL * 1024ULL)) return;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data.length) return;
    const unsigned char *bytes = data.bytes;
    NSMutableData *token = [NSMutableData dataWithCapacity:128];
    NSUInteger emitted = 0;
    for (NSUInteger i = 0; i < data.length; i++) {
        unsigned char c = bytes[i];
        BOOL printable = (c >= 0x20 && c <= 0x7e);
        if (printable && token.length < 181) {
            [token appendBytes:&c length:1];
        } else {
            if (token.length >= 6) {
                NSString *s = [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding];
                if (s && [self isInteresting:s]) {
                    [self addEvidence:s target:target path:path];
                    emitted++;
                    if (emitted >= 160) break;
                }
            }
            [token setLength:0];
        }
    }
}

- (void)scanBundle:(NSString *)bundlePath target:(NSString *)target {
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    if (info) [self scanStructuredObject:info target:target path:infoPath prefix:@"Info" depth:0];

    NSString *exe = info[@"CFBundleExecutable"];
    if (exe.length) {
        NSString *exePath = [bundlePath stringByAppendingPathComponent:exe];
        [self scanTextAtPath:exePath target:target];
    }

    NSDirectoryEnumerator *en = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:bundlePath]
                                                     includingPropertiesForKeys:@[NSURLIsRegularFileKey]
                                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                   errorHandler:nil];
    NSUInteger resourceCount = 0;
    for (NSURL *url in en) {
        NSString *ext = url.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"plist"] || [ext isEqualToString:@"strings"] || [ext isEqualToString:@"json"]) {
            [self scanPlistAtPath:url.path target:target];
            resourceCount++;
            if (resourceCount > 120) break;
        }
    }
}

- (NSArray<HIDFinding *> *)scanWithProgress:(void (^)(NSString *))progress {
    [self.findings removeAllObjects];
    [self.dedupe removeAllObjects];
    NSFileManager *fm = NSFileManager.defaultManager;

    NSArray<NSString *> *appRoots = @[@"/System/Applications", @"/Applications", @"/System/Library/CoreServices"];
    for (NSString *root in appRoots) {
        NSArray<NSString *> *children = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *name in children) {
            if (![name.pathExtension.lowercaseString isEqualToString:@"app"]) continue;
            NSString *path = [root stringByAppendingPathComponent:name];
            NSString *target = name.stringByDeletingPathExtension;
            if (progress) progress([NSString stringWithFormat:@"Scanning %@…", target]);
            @autoreleasepool { [self scanBundle:path target:target]; }
        }
    }

    NSString *pfRoot = @"/System/Library/PrivateFrameworks";
    NSArray<NSString *> *frameworks = [fm contentsOfDirectoryAtPath:pfRoot error:nil];
    NSUInteger fwCount = 0;
    for (NSString *name in frameworks) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"framework"]) continue;
        NSString *path = [pfRoot stringByAppendingPathComponent:name];
        NSString *target = [NSString stringWithFormat:@"%@ (PrivateFramework)", name.stringByDeletingPathExtension];
        if (progress && fwCount % 20 == 0) progress([NSString stringWithFormat:@"Scanning PrivateFrameworks… %lu", (unsigned long)fwCount]);
        @autoreleasepool { [self scanBundle:path target:target]; }
        fwCount++;
        if (fwCount >= 260) break;
    }

    NSArray<NSString *> *prefRoots = @[@"/System/Library/PreferenceBundles", @"/System/Library/PreferenceManifestsInternal"];
    for (NSString *root in prefRoots) {
        NSArray<NSString *> *children = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *name in children) {
            NSString *path = [root stringByAppendingPathComponent:name];
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:path isDirectory:&isDir]) continue;
            if (isDir) [self scanBundle:path target:[NSString stringWithFormat:@"Settings/%@", name.stringByDeletingPathExtension]];
            else if ([name.pathExtension.lowercaseString isEqualToString:@"plist"]) [self scanPlistAtPath:path target:@"Settings"];
        }
    }

    [self.findings sortUsingComparator:^NSComparisonResult(HIDFinding *a, HIDFinding *b) {
        if (a.score != b.score) return a.score > b.score ? NSOrderedAscending : NSOrderedDescending;
        NSComparisonResult target = [a.target compare:b.target options:NSCaseInsensitiveSearch];
        if (target != NSOrderedSame) return target;
        return [a.evidence compare:b.evidence options:NSCaseInsensitiveSearch];
    }];
    return self.findings.copy;
}
@end

@interface HIDViewController : UITableViewController <UISearchResultsUpdating>
@property(nonatomic,strong) NSArray<HIDFinding *> *allFindings;
@property(nonatomic,strong) NSArray<HIDFinding *> *visibleFindings;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) UISearchController *searchController;
@end

@implementation HIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Hidden";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.tableView.rowHeight = 72.0;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search SpringBoard, Siri, Camera…";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Scan" style:UIBarButtonItemStyleDone target:self action:@selector(runScan)];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 74)];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, 700, 48)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"Apple system discovery engine\nTap Scan to inspect system apps and private frameworks.";
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [header addSubview:self.statusLabel];
    self.tableView.tableHeaderView = header;

    self.allFindings = @[];
    self.visibleFindings = @[];
}

- (void)runScan {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.statusLabel.text = @"Starting system scan…";
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        HIDScanner *scanner = [HIDScanner new];
        NSArray *results = [scanner scanWithProgress:^(NSString *status) {
            dispatch_async(dispatch_get_main_queue(), ^{ weakSelf.statusLabel.text = status; });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.allFindings = results;
            weakSelf.visibleFindings = results;
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"%lu discoveries ranked by confidence.\nTap any result for its exact source path and evidence.", (unsigned long)results.count];
            weakSelf.navigationItem.rightBarButtonItem.enabled = YES;
            [weakSelf.tableView reloadData];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *q = searchController.searchBar.text.lowercaseString;
    if (q.length == 0) self.visibleFindings = self.allFindings;
    else {
        self.visibleFindings = [self.allFindings filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HIDFinding *f, NSDictionary *bindings) {
            (void)bindings;
            NSString *haystack = [[NSString stringWithFormat:@"%@ %@ %@ %@", f.target, f.category, f.evidence, f.path] lowercaseString];
            return [haystack containsString:q];
        }]];
    }
    [self.tableView reloadData];
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
    NSString *msg = [NSString stringWithFormat:@"Category: %@\nScore: %ld\n\nEvidence:\n%@\n\nSource:\n%@", f.category, (long)f.score, f.evidence, f.path];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:f.target message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Copy Evidence" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = f.evidence;
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Copy Path" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = f.path;
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
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
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(HIDAppDelegate.class));
    }
}

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

@interface HIDViewController : UITableViewController
@end

@interface HIDGateDetailViewController : UIViewController
@property(nonatomic,copy) NSString *detailTitle;
@property(nonatomic,copy) NSString *body;
@property(nonatomic,copy) NSString *sourcePath;
@property(nonatomic,copy) NSString *rawEvidence;
@end

@implementation HIDGateDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.detailTitle.length ? self.detailTitle : @"Gate Inspector";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UITextView *text = [[UITextView alloc] initWithFrame:CGRectZero];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.editable = NO;
    text.selectable = YES;
    text.alwaysBounceVertical = YES;
    text.backgroundColor = UIColor.systemBackgroundColor;
    text.textColor = UIColor.labelColor;
    text.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    text.text = self.body ?: @"";
    text.textContainerInset = UIEdgeInsetsMake(18, 16, 24, 16);
    [self.view addSubview:text];
    [NSLayoutConstraint activateConstraints:@[
        [text.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [text.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [text.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [text.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIBarButtonItem *copy = [[UIBarButtonItem alloc] initWithTitle:@"Copy" style:UIBarButtonItemStylePlain target:self action:@selector(copyDetails)];
    self.navigationItem.rightBarButtonItem = copy;
}

- (void)copyDetails {
    UIPasteboard.generalPasteboard.string = self.body ?: @"";
    UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
}

@end

static id HIDSafeValue(id object, NSString *key) {
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *HIDStringValue(id object, NSString *key) {
    id value = HIDSafeValue(object, key);
    return [value isKindOfClass:NSString.class] ? value : (value ? [value description] : @"");
}

static NSArray<NSString *> *HIDCandidateGateTokens(NSString *evidence) {
    if (!evidence.length) return @[];
    NSMutableOrderedSet<NSString *> *tokens = [NSMutableOrderedSet orderedSet];

    NSArray<NSString *> *fieldNames = @[
        @"requiredCapabilities", @"requiredDeviceCapabilities", @"featureFlag", @"identifier",
        @"predicate", @"condition", @"visibility", @"restriction", @"supportedDevices",
        @"deviceFamilies", @"minimumOSVersion", @"key"
    ];

    for (NSString *field in fieldNames) {
        NSRange range = [evidence rangeOfString:[field stringByAppendingString:@"="] options:NSCaseInsensitiveSearch];
        if (range.location == NSNotFound) continue;
        NSUInteger start = NSMaxRange(range);
        NSRange tail = NSMakeRange(start, evidence.length - start);
        NSRange end = [evidence rangeOfString:@" | " options:0 range:tail];
        NSUInteger length = end.location == NSNotFound ? MIN((NSUInteger)220, evidence.length - start) : end.location - start;
        NSString *chunk = [evidence substringWithRange:NSMakeRange(start, length)];

        NSError *error = nil;
        NSRegularExpression *tokenRegex = [NSRegularExpression regularExpressionWithPattern:@"[A-Za-z0-9_+./:-]{3,96}" options:0 error:&error];
        if (error) continue;
        NSArray<NSTextCheckingResult *> *matches = [tokenRegex matchesInString:chunk options:0 range:NSMakeRange(0, chunk.length)];
        for (NSTextCheckingResult *match in matches) {
            NSString *token = [chunk substringWithRange:match.range];
            NSString *lower = token.lowercaseString;
            NSSet *noise = [NSSet setWithArray:@[@"requiredcapabilities", @"requireddevicecapabilities", @"featureflag", @"identifier", @"predicate", @"condition", @"visibility", @"restriction", @"supporteddevices", @"devicefamilies", @"minimumosversion", @"true", @"false"]];
            if (![noise containsObject:lower] && token.length >= 3) [tokens addObject:token];
            if (tokens.count >= 16) break;
        }
    }

    NSError *opaqueError = nil;
    NSRegularExpression *opaque = [NSRegularExpression regularExpressionWithPattern:@"(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{16,48}={0,2}(?![A-Za-z0-9+/])" options:0 error:&opaqueError];
    if (!opaqueError) {
        for (NSTextCheckingResult *match in [opaque matchesInString:evidence options:0 range:NSMakeRange(0, evidence.length)]) {
            [tokens addObject:[evidence substringWithRange:match.range]];
            if (tokens.count >= 20) break;
        }
    }

    return tokens.array;
}

static id HIDMobileGestaltAnswer(NSString *key) {
    if (!key.length) return nil;
    typedef CFTypeRef (*MGCopyAnswerFunction)(CFStringRef);
    static MGCopyAnswerFunction function = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (!handle) handle = dlopen("/System/Library/PrivateFrameworks/MobileGestalt.framework/MobileGestalt", RTLD_LAZY | RTLD_LOCAL);
        if (handle) function = (MGCopyAnswerFunction)dlsym(handle, "MGCopyAnswer");
    });
    if (!function) return nil;
    CFTypeRef result = function((__bridge CFStringRef)key);
    return result ? CFBridgingRelease(result) : nil;
}

static NSString *HIDPrintableValue(id value) {
    if (!value) return @"not resolved";
    if ([value isKindOfClass:NSData.class]) return [NSString stringWithFormat:@"<NSData %lu bytes>", (unsigned long)[(NSData *)value length]];
    NSString *text = [value description] ?: @"";
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    if (text.length > 180) text = [[text substringToIndex:180] stringByAppendingString:@"…"];
    return text;
}

static NSString *HIDGateKind(NSString *token) {
    if (token.length >= 16 && [token rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location == NSNotFound) {
        return @"possible hashed capability / Gestalt key";
    }
    if ([token containsString:@"-"] || [token.lowercaseString isEqualToString:@"ipad"] || [token.lowercaseString isEqualToString:@"iphone"]) {
        return @"manifest/device capability";
    }
    return @"candidate gate token";
}

@implementation HIDViewController (HiddenGateInspector)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(tableView:didSelectRowAtIndexPath:));
        Method replacement = class_getInstanceMethod(self, @selector(hid_gate_tableView:didSelectRowAtIndexPath:));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (void)hid_gate_tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSArray *visible = HIDSafeValue(self, @"visibleFindings");
    if (![visible isKindOfClass:NSArray.class] || indexPath.row >= (NSInteger)visible.count) {
        [self hid_gate_tableView:tableView didSelectRowAtIndexPath:indexPath];
        return;
    }

    id finding = visible[indexPath.row];
    NSString *target = HIDStringValue(finding, @"target");
    NSString *category = HIDStringValue(finding, @"category");
    NSString *evidence = HIDStringValue(finding, @"evidence");
    NSString *path = HIDStringValue(finding, @"path");
    NSString *reason = HIDStringValue(finding, @"reason");
    NSNumber *score = HIDSafeValue(finding, @"score");

    NSArray<NSString *> *tokens = HIDCandidateGateTokens(evidence);
    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"TARGET\n%@\n\n", target.length ? target : @"System"];
    [body appendFormat:@"CATEGORY\n%@\n\n", category.length ? category : @"Unknown"];
    [body appendFormat:@"SCORE\n%@\n\n", score ?: @"?"];
    if (reason.length) [body appendFormat:@"WHY HIDDEN FLAGGED IT\n%@\n\n", reason];

    [body appendString:@"GATE INSPECTOR\n"];
    if (tokens.count == 0) {
        [body appendString:@"No structured capability token extracted from this finding.\n"];
    } else {
        for (NSString *token in tokens) {
            id value = HIDMobileGestaltAnswer(token);
            [body appendFormat:@"• %@\n  type: %@\n  current: %@\n", token, HIDGateKind(token), HIDPrintableValue(value)];
        }
    }

    [body appendFormat:@"\nEVIDENCE\n%@\n\nSOURCE\n%@\n", evidence.length ? evidence : @"(none)", path.length ? path : @"(unknown)"];

    HIDGateDetailViewController *detail = [HIDGateDetailViewController new];
    detail.detailTitle = target.length ? target : @"Gate Inspector";
    detail.body = body;
    detail.sourcePath = path;
    detail.rawEvidence = evidence;
    [self.navigationController pushViewController:detail animated:YES];
}

@end

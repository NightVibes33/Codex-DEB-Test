#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "BTClient.h"

static NSInteger const kBTButtonTag = 0x42543136;

static UIWindow *BTKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static UIViewController *BTTopController(void) {
    UIViewController *vc = BTKeyWindow().rootViewController;
    while (vc) {
        if (vc.presentedViewController) { vc = vc.presentedViewController; continue; }
        if ([vc isKindOfClass:UINavigationController.class]) { vc = ((UINavigationController *)vc).visibleViewController; continue; }
        if ([vc isKindOfClass:UITabBarController.class]) { vc = ((UITabBarController *)vc).selectedViewController; continue; }
        break;
    }
    return vc;
}

static void BTShowAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = BTTopController();
        if (!vc) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:alert animated:YES completion:nil];
    });
}

@interface BTDocumentPickerProxy : NSObject <UIDocumentPickerDelegate>
@end

@implementation BTDocumentPickerProxy

- (void)importURLAtIndex:(NSUInteger)index urls:(NSArray<NSURL *> *)urls successes:(NSMutableArray<NSString *> *)successes failures:(NSMutableArray<NSString *> *)failures {
    if (index >= urls.count) {
        NSString *message = [NSString stringWithFormat:@"Imported: %lu\nFailed: %lu%@", (unsigned long)successes.count, (unsigned long)failures.count, failures.count ? [@"\n\n" stringByAppendingString:[failures componentsJoinedByString:@"\n"]] : @""];
        BTShowAlert(failures.count ? @"ByeTunes16 finished with errors" : @"ByeTunes16 import complete", message);
        if (successes.count) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
        }
        return;
    }

    NSURL *url = urls[index];
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSString *ext = url.pathExtension.length ? url.pathExtension.lowercaseString : @"bin";
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ByeTunes16"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *dest = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, ext]];
    NSError *copyError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
    BOOL copied = [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:dest error:&copyError];
    if (scoped) [url stopAccessingSecurityScopedResource];

    if (!copied) {
        [failures addObject:[NSString stringWithFormat:@"%@: %@", url.lastPathComponent, copyError.localizedDescription ?: @"copy failed"]];
        [self importURLAtIndex:index + 1 urls:urls successes:successes failures:failures];
        return;
    }

    NSDictionary *request = @{ @"op": @"import", @"path": dest, @"sourceName": url.lastPathComponent ?: @"Imported Audio" };
    [[BTClient sharedClient] sendRequest:request completion:^(NSDictionary *response, NSError *error) {
        BOOL ok = [response[@"ok"] boolValue];
        if (ok) {
            [successes addObject:response[@"title"] ?: url.lastPathComponent];
        } else {
            NSString *reason = error.localizedDescription ?: response[@"error"] ?: @"unknown error";
            [failures addObject:[NSString stringWithFormat:@"%@: %@", url.lastPathComponent, reason]];
        }
        [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
        [self importURLAtIndex:index + 1 urls:urls successes:successes failures:failures];
    }];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (!urls.count) return;
    [self importURLAtIndex:0 urls:urls successes:[NSMutableArray array] failures:[NSMutableArray array]];
}

@end

static BTDocumentPickerProxy *gPickerProxy;

static void BTImportAudio(void) {
    UIViewController *vc = BTTopController();
    if (!vc) return;
    gPickerProxy = [BTDocumentPickerProxy new];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeAudio] asCopy:YES];
    picker.delegate = gPickerProxy;
    picker.allowsMultipleSelection = YES;
    [vc presentViewController:picker animated:YES completion:nil];
}

static void BTProbe(void) {
    [[BTClient sharedClient] sendRequest:@{ @"op": @"probe" } completion:^(NSDictionary *response, NSError *error) {
        if (error) { BTShowAlert(@"ByeTunes16 helper error", error.localizedDescription); return; }
        NSData *data = [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:nil];
        NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : response.description;
        BTShowAlert(@"ByeTunes16 diagnostics", text);
    }];
}

static void BTRestore(void) {
    UIViewController *vc = BTTopController();
    if (!vc) return;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Restore media library?" message:@"Restores the newest automatic ByeTunes16 database backup, then Music restarts." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[BTClient sharedClient] sendRequest:@{ @"op": @"restore" } completion:^(NSDictionary *response, NSError *error) {
            if (error || ![response[@"ok"] boolValue]) {
                BTShowAlert(@"Restore failed", error.localizedDescription ?: response[@"error"] ?: @"Unknown error");
                return;
            }
            BTShowAlert(@"Restored", response[@"message"] ?: @"Media library restored.");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
        }];
    }]];
    [vc presentViewController:confirm animated:YES completion:nil];
}

static void BTShowMenu(void) {
    UIViewController *vc = BTTopController();
    if (!vc) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"ByeTunes16" message:@"Inject local audio directly into the iOS 16 Music library." preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Import Audio" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { BTImportAudio(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Diagnose Library" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { BTProbe(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Restore Last Backup" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { BTRestore(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (menu.popoverPresentationController) {
        menu.popoverPresentationController.sourceView = BTKeyWindow();
        menu.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(BTKeyWindow().bounds), CGRectGetMaxY(BTKeyWindow().bounds) - 80, 1, 1);
    }
    [vc presentViewController:menu animated:YES completion:nil];
}

static void BTInstallButton(void) {
    UIWindow *window = BTKeyWindow();
    if (!window || [window viewWithTag:kBTButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kBTButtonTag;
    button.frame = CGRectMake(CGRectGetWidth(window.bounds) - 66, CGRectGetHeight(window.bounds) - 158, 50, 50);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    button.layer.cornerRadius = 25;
    button.layer.shadowOpacity = 0.22;
    button.layer.shadowRadius = 8;
    button.layer.shadowOffset = CGSizeMake(0, 2);
    button.backgroundColor = [UIColor colorWithRed:0.98 green:0.18 blue:0.30 alpha:0.96];
    [button setTitle:@"BT" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [button addTarget:NSBlockOperation.class action:@selector(description) forControlEvents:0];

    UIAction *action = [UIAction actionWithHandler:^(__kindof UIAction * _Nonnull ignored) { (void)ignored; BTShowMenu(); }];
    [button addAction:action forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
}

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ BTInstallButton(); });
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ BTInstallButton(); });
        });
    }
}

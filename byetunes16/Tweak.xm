#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "BTClient.h"
#import "BTManager.h"

static NSInteger const kBTButtonTag = 0x42543136;

static UIWindow *BTKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow) return window;
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

static void BTRestartMusicSoon(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
}

@interface BTDocumentPickerProxy : NSObject <UIDocumentPickerDelegate>
@end

@implementation BTDocumentPickerProxy

- (void)importURLAtIndex:(NSUInteger)index urls:(NSArray<NSURL *> *)urls successes:(NSMutableArray<NSString *> *)successes failures:(NSMutableArray<NSString *> *)failures {
    if (index >= urls.count) {
        NSString *message = [NSString stringWithFormat:@"Imported: %lu\nFailed: %lu%@", (unsigned long)successes.count, (unsigned long)failures.count, failures.count ? [@"\n\n" stringByAppendingString:[failures componentsJoinedByString:@"\n"]] : @""];
        BTShowAlert(failures.count ? @"ByeTunes16 finished with errors" : @"ByeTunes16 import complete", message);
        if (successes.count) BTRestartMusicSoon();
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
        if (ok) [successes addObject:response[@"title"] ?: url.lastPathComponent];
        else [failures addObject:[NSString stringWithFormat:@"%@: %@", url.lastPathComponent, error.localizedDescription ?: response[@"error"] ?: @"unknown error"]];
        [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
        [self importURLAtIndex:index + 1 urls:urls successes:successes failures:failures];
    }];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    if (urls.count) [self importURLAtIndex:0 urls:urls successes:[NSMutableArray array] failures:[NSMutableArray array]];
}
@end

static BTDocumentPickerProxy *gPickerProxy;

static void BTImportAudio(void) {
    UIViewController *vc = BTTopController(); if (!vc) return;
    gPickerProxy = [BTDocumentPickerProxy new];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeAudio] asCopy:YES];
    picker.delegate = gPickerProxy; picker.allowsMultipleSelection = YES;
    [vc presentViewController:picker animated:YES completion:nil];
}

static void BTOpenLibraryManager(void) {
    UIViewController *vc = BTTopController(); if (!vc) return;
    BTManagerViewController *manager = [[BTManagerViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:manager];
    manager.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:nav action:@selector(dismissViewControllerAnimated:completion:)];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [vc presentViewController:nav animated:YES completion:nil];
}

static void BTProbe(void) {
    [[BTClient sharedClient] sendRequest:@{ @"op": @"probe" } completion:^(NSDictionary *response, NSError *error) {
        if (error) { BTShowAlert(@"ByeTunes16 helper error", error.localizedDescription); return; }
        NSData *data = [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:nil];
        BTShowAlert(@"ByeTunes16 diagnostics", data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : response.description);
    }];
}

static void BTBackupNow(void) {
    [[BTClient sharedClient] sendRequest:@{ @"op": @"backup" } completion:^(NSDictionary *response, NSError *error) {
        if (error || ![response[@"ok"] boolValue]) { BTShowAlert(@"Backup failed", error.localizedDescription ?: response[@"error"] ?: @"Unknown error"); return; }
        BTShowAlert(@"Backup created", response[@"backup"] ?: @"Media library backed up.");
    }];
}

static void BTRepair(void) {
    UIViewController *vc = BTTopController(); if (!vc) return;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Repair library?" message:@"ByeTunes16 will make a backup, checkpoint the database, repair missing sync IDs and orphan playlist rows, then verify quick_check." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Repair" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        [[BTClient sharedClient] sendRequest:@{ @"op": @"repair" } completion:^(NSDictionary *response, NSError *error) {
            if (error || ![response[@"ok"] boolValue]) { BTShowAlert(@"Repair failed", error.localizedDescription ?: response[@"error"] ?: @"Unknown error"); return; }
            BTShowAlert(@"Repair complete", @"MediaLibrary.sqlitedb passed quick_check after repair."); BTRestartMusicSoon();
        }];
    }]];
    [vc presentViewController:confirm animated:YES completion:nil];
}

static void BTCreatePlaylist(void) {
    UIViewController *vc = BTTopController(); if (!vc) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"New Playlist" message:@"Creates an editable Apple Music playlist directly in MediaLibrary.sqlitedb." preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Playlist name"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = a.textFields.firstObject.text; if (!name.length) return;
        [[BTClient sharedClient] sendRequest:@{ @"op": @"createPlaylist", @"name": name, @"itemPIDs": @[] } completion:^(NSDictionary *response, NSError *error) {
            if (error || ![response[@"ok"] boolValue]) { BTShowAlert(@"Playlist failed", error.localizedDescription ?: response[@"error"] ?: @"Unknown error"); return; }
            BTShowAlert(@"Playlist created", name); BTRestartMusicSoon();
        }];
    }]];
    [vc presentViewController:a animated:YES completion:nil];
}

static void BTRestore(void) {
    UIViewController *vc = BTTopController(); if (!vc) return;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Restore media library?" message:@"Restores the newest automatic ByeTunes16 database backup. Imported audio files are never deleted by restore." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[BTClient sharedClient] sendRequest:@{ @"op": @"restore" } completion:^(NSDictionary *response, NSError *error) {
            if (error || ![response[@"ok"] boolValue]) { BTShowAlert(@"Restore failed", error.localizedDescription ?: response[@"error"] ?: @"Unknown error"); return; }
            BTShowAlert(@"Restored", response[@"message"] ?: @"Media library restored."); BTRestartMusicSoon();
        }];
    }]];
    [vc presentViewController:confirm animated:YES completion:nil];
}

static void BTShowMenu(void) {
    UIViewController *vc = BTTopController(); if (!vc) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"ByeTunes16" message:@"Direct rootless Music injection — no pairing file, LocalDevVPN, AFC bridge, or PC sync." preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Import Audio" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { BTImportAudio(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Manage Music / Metadata" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { BTOpenLibraryManager(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Create Playlist" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { BTCreatePlaylist(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Backup Library" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { BTBackupNow(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Repair Library" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { BTRepair(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Diagnostics" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { BTProbe(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Restore Last Backup" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) { BTRestore(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (menu.popoverPresentationController) { menu.popoverPresentationController.sourceView = BTKeyWindow(); menu.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(BTKeyWindow().bounds), CGRectGetMaxY(BTKeyWindow().bounds)-80,1,1); }
    [vc presentViewController:menu animated:YES completion:nil];
}

static void BTInstallButton(void) {
    UIWindow *window = BTKeyWindow(); if (!window || [window viewWithTag:kBTButtonTag]) return;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kBTButtonTag; button.frame = CGRectMake(CGRectGetWidth(window.bounds)-66, CGRectGetHeight(window.bounds)-158, 50, 50);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    button.layer.cornerRadius = 25; button.layer.shadowOpacity = 0.22; button.layer.shadowRadius = 8; button.layer.shadowOffset = CGSizeMake(0,2);
    button.backgroundColor = [UIColor colorWithRed:0.98 green:0.18 blue:0.30 alpha:0.96];
    [button setTitle:@"BT" forState:UIControlStateNormal]; [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) { (void)action; BTShowMenu(); }] forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
}

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.7*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ BTInstallButton(); });
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ BTInstallButton(); });
        });
    }
}

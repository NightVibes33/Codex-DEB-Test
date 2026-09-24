#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

static IMP gOriginalCreateDisplayNameList = NULL;
static BOOL gInstalled = NO;

static id SendId(id obj, SEL sel) {
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static id SendId1(id obj, SEL sel, id arg) {
    return ((id (*)(id, SEL, id))objc_msgSend)(obj, sel, arg);
}

static void SendVoid1(id obj, SEL sel, id arg) {
    ((void (*)(id, SEL, id))objc_msgSend)(obj, sel, arg);
}

static NSArray<NSString *> *SanitizedSelection(id controller) {
    SEL getSelected = sel_registerName("selectedAppList");
    if (![controller respondsToSelector:getSelected]) return nil;

    id raw = SendId(controller, getSelected);
    if (![raw isKindOfClass:[NSArray class]]) return nil;

    Class appControllerClass = objc_getClass("SBApplicationController");
    SEL sharedSel = sel_registerName("sharedInstance");
    SEL appSel = sel_registerName("applicationWithBundleIdentifier:");
    SEL nameSel = sel_registerName("displayName");

    id appController = nil;
    if (appControllerClass && [appControllerClass respondsToSelector:sharedSel]) {
        appController = SendId((id)appControllerClass, sharedSel);
    }

    NSMutableArray<NSString *> *valid = [NSMutableArray array];
    for (id item in (NSArray *)raw) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *bundleID = (NSString *)item;
        if (bundleID.length == 0) continue;

        BOOL usable = NO;
        @try {
            id app = appController ? SendId1(appController, appSel, bundleID) : nil;
            if (app) {
                id displayName = [app respondsToSelector:nameSel] ? SendId(app, nameSel) : nil;
                usable = (displayName != nil);
            }
        } @catch (__unused NSException *exception) {
            usable = NO;
        }

        if (usable) [valid addObject:bundleID];
    }

    return valid;
}

static void PersistSelection(NSArray<NSString *> *selection) {
    if (!selection) return;
    CFStringRef appID = CFSTR("com.sugiuta.circleapps15");
    CFPreferencesSetAppValue(CFSTR("selectedApplications"),
                             (__bridge CFPropertyListRef)selection,
                             appID);
    CFPreferencesAppSynchronize(appID);
}

static void SafeCreateDisplayNameList(id self, SEL _cmd) {
    @autoreleasepool {
        @try {
            NSArray<NSString *> *valid = SanitizedSelection(self);
            if (valid) {
                SEL setSelected = sel_registerName("setSelectedAppList:");
                if ([self respondsToSelector:setSelected]) {
                    SendVoid1(self, setSelected, valid);
                    PersistSelection(valid);
                }
            }

            if (gOriginalCreateDisplayNameList) {
                ((void (*)(id, SEL))gOriginalCreateDisplayNameList)(self, _cmd);
            }
        } @catch (NSException *exception) {
            NSLog(@"[ZZCircleAppsCompat] prevented CircleApps startup exception: %@", exception);
        }
    }
}

static void InstallCircleAppsGuard(void) {
    if (gInstalled) return;

    Class cls = objc_getClass("CircleApplicationViewController");
    if (!cls) return;

    SEL sel = sel_registerName("createDisplayNameList");
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP current = method_getImplementation(method);
    if (current == (IMP)SafeCreateDisplayNameList) {
        gInstalled = YES;
        return;
    }

    gOriginalCreateDisplayNameList = current;
    method_setImplementation(method, (IMP)SafeCreateDisplayNameList);
    gInstalled = YES;
    NSLog(@"[ZZCircleAppsCompat] installed stale-app guard");
}

__attribute__((constructor))
static void ZZCircleAppsCompatInit(void) {
    @autoreleasepool {
        InstallCircleAppsGuard();

        if (!gInstalled) {
            // TweakLoader normally loads alphabetically, so ZZ loads after CircleApps.
            // This fallback handles loaders with a different order.
            dispatch_async(dispatch_get_main_queue(), ^{
                InstallCircleAppsGuard();
            });
        }
    }
}

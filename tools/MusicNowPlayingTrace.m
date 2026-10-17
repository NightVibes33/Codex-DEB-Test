// MusicNowPlayingTrace.m
// FlekDeck Apple Music guest: original Now Playing lifecycle/transport trace.
// This changes no playback, audio session, Now Playing metadata, or UI.
// Only records original controls and public MPMusicPlayerController state.
// No timers/polling. This is NOT a completed repair.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <stdio.h>
#import <sys/stat.h>

static IMP oldNowPlayingAppeared = NULL;
static IMP oldControlsAppeared = NULL;
static IMP oldTransportAction = NULL;
static BOOL installedNowPlaying = NO, installedControls = NO, installedTransport = NO;
static NSUInteger probeAttempts = 0;
static const char *const kExpectedGuest = "com.nightvibes33.applemusic27";

static BOOL isGuest(void) {
    return [NSBundle.mainBundle.bundleIdentifier isEqualToString:@(kExpectedGuest)];
}

static void traceLine(NSString *message) {
    const char *home = getenv("HOME");
    if (!home) return;
    NSString *root = [NSString stringWithUTF8String:home];
    NSString *dir = [root stringByAppendingPathComponent:@"Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *file = [dir stringByAppendingPathComponent:@"MusicNowPlayingTrace.log"];
    FILE *stream = fopen(file.fileSystemRepresentation, "a");
    if (!stream) return;
    fprintf(stream, "%s %s\n", NSDate.date.description.UTF8String, message.UTF8String);
    fclose(stream);
}
static NSString *itemDescription(MPMediaItem *item) {
    if (!item) return @"none";
    NSString *name = [item valueForProperty:MPMediaItemPropertyTitle] ?: @"unknown";
    NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist] ?: @"unknown";
    uint64_t pid = item.persistentID;
    NSString *storeID = item.playbackStoreID ?: @"";
    return [NSString stringWithFormat:@"title=%@ artist=%@ persistentID=%llu storeID=%@",
            name,artist,(unsigned long long)pid,storeID];
}
static NSString *stateString(MPMusicPlaybackState status) {
    switch(status) {
        case MPMusicPlaybackStatePlaying:return @"playing";
        case MPMusicPlaybackStatePaused:return @"paused";
        case MPMusicPlaybackStateStopped:return @"stopped";
        case MPMusicPlaybackStateInterrupted:return @"interrupted";
        case MPMusicPlaybackStateSeekingForward:return @"seekForward";
        case MPMusicPlaybackStateSeekingBackward:return @"seekBackward";
        default:return @"unknown";
    }
}
static BOOL entitlementPresent(CFTypeRef task, NSString *key) {
    if (!task) return NO;
    CFTypeRef (*copyEntitlement)(CFTypeRef,CFStringRef,CFErrorRef*) = (void*)dlsym(RTLD_DEFAULT,"SecTaskCopyValueForEntitlement");
    if(!copyEntitlement)return NO;
    CFTypeRef v=copyEntitlement(task,(__bridge CFStringRef)key,NULL);
    BOOL answer=NO;
    if (v) {
        if(CFGetTypeID(v)==CFBooleanGetTypeID()) answer=CFBooleanGetValue(v);
        else if(CFGetTypeID(v)==CFStringGetTypeID()) answer=CFStringGetLength(v)>0;
        else answer=YES;
        CFRelease(v);
    }
    return answer;
}
static void snapshot(NSString *reason) {
    if(!isGuest())return;
    // MediaPlayer is documented as main-thread only.
    if(!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{snapshot(reason);});
        return;
    }
    @try {
        MPMusicPlayerController *app=MPMusicPlayerController.applicationQueuePlayer;
        MPMusicPlayerController *system=MPMusicPlayerController.systemMusicPlayer;
        MPNowPlayingInfoCenter *center=MPNowPlayingInfoCenter.defaultCenter;
        NSDictionary *now=center.nowPlayingInfo;
        NSString *title=now[MPMediaItemPropertyTitle] ?: @"none";
        NSString *libraryStatus=[NSString stringWithFormat:@"%ld",(long)MPMediaLibrary.authorizationStatus];
        NSString *text=[NSString stringWithFormat:
           @"SNAPSHOT reason=%@ appState=%@ appTime=%.3f appTrack=[%@] systemState=%@ systemTime=%.3f systemTrack=[%@] nowPlayingInfo=%@ nowPlayingTitle=%@ libraryAuth=%@ bundle=%@",
           reason,stateString(app.playbackState),app.currentPlaybackTime,itemDescription(app.nowPlayingItem),
           stateString(system.playbackState),system.currentPlaybackTime,itemDescription(system.nowPlayingItem),
           now?@"present":@"absent",title,libraryStatus,NSBundle.mainBundle.bundleIdentifier];
        traceLine(text);
    } @catch(NSException *e) {
        traceLine([NSString stringWithFormat:@"SNAPSHOT_EXCEPTION %@ %@",e.name,e.reason]);
    }
}
static void scanLabels(UIView *root, NSMutableArray<NSString *> *found, NSUInteger depth) {
    if(!root||depth>7||found.count>=24)return;
    if([root isKindOfClass:UILabel.class]){
        NSString *txt=((UILabel*)root).text;
        if(txt.length && txt.length<250)[found addObject:txt];
    }
    for(UIView *sub in root.subviews) {
        if(found.count>=24)break;
        scanLabels(sub,found,depth+1);
    }
}
static void logControllerAPI(Class cls) {
    unsigned int propCount=0,ivarCount=0,methodCount=0;
    objc_property_t *properties=class_copyPropertyList(cls,&propCount);
    Ivar *ivars=class_copyIvarList(cls,&ivarCount);
    Method *methods=class_copyMethodList(cls,&methodCount);
    NSMutableArray<NSString *> *names=[NSMutableArray array];
    for(unsigned int i=0;i<propCount&&i<80;i++){
        const char *name=property_getName(properties[i]);
        if(name)[names addObject:[@"property:" stringByAppendingString:@(name)]];
    }
    for(unsigned int i=0;i<ivarCount&&i<120;i++){
        const char *name=ivar_getName(ivars[i]);
        if(name)[names addObject:[@"ivar:" stringByAppendingString:@(name)]];
    }
    NSMutableArray<NSString *> *selectors=[NSMutableArray array];
    for(unsigned int i=0;i<methodCount&&selectors.count<90;i++){
        NSString *methodName=NSStringFromSelector(method_getName(methods[i]));
        NSString *lower=methodName.lowercaseString;
        if([lower containsString:@"play"] || [lower containsString:@"song"] ||
           [lower containsString:@"track"] || [lower containsString:@"item"] ||
           [lower containsString:@"state"] || [lower containsString:@"queue"] ||
           [lower containsString:@"content"] || [lower containsString:@"model"] ||
           [lower containsString:@"press"] || [lower containsString:@"tap"]){
            [selectors addObject:methodName];
        }
    }
    if(properties)free(properties);
    if(ivars)free(ivars);
    if(methods)free(methods);
    traceLine([NSString stringWithFormat:@"CONTROLLER_API class=%@ ivars=%@ methods=%@",
               NSStringFromClass(cls),names,selectors]);
}
static void logController(id controller, NSString *stage) {
    if(!isGuest())return;
    UIViewController *vc=(UIViewController*)controller;
    static NSMutableSet *reported;
    if(!reported)reported=[NSMutableSet new];
    NSString *type=NSStringFromClass([vc class]);
    if(![reported containsObject:type]) { [reported addObject:type]; logControllerAPI([vc class]); }
    NSMutableArray<NSString*> *labels=[NSMutableArray array];
    scanLabels(vc.view,labels,0);
    traceLine([NSString stringWithFormat:@"VIEW %@ class=%@ visibleLabels=%@",
               stage,NSStringFromClass([vc class]),labels]);
    snapshot(stage);
}
static void hookNowPlayingAppeared(id object,SEL cmd,BOOL animated) {
    if(oldNowPlayingAppeared)((void(*)(id,SEL,BOOL))oldNowPlayingAppeared)(object,cmd,animated);
    logController(object,@"original-NowPlaying-viewDidAppear");
}
static void hookControlsAppeared(id object,SEL cmd,BOOL animated) {
    if(oldControlsAppeared)((void(*)(id,SEL,BOOL))oldControlsAppeared)(object,cmd,animated);
    logController(object,@"original-controls-viewDidAppear");
}
static void hookTransportAction(id object,SEL cmd,SEL action,id target,UIEvent *event) {
    NSString *selectorName=NSStringFromSelector(action) ?: @"unknown";
    NSString *targetName=target?NSStringFromClass([target class]):@"none";
    NSString *senderName=NSStringFromClass([object class]);
    traceLine([NSString stringWithFormat:@"TRANSPORT class=%@ action=%@ target=%@",
               senderName,selectorName,targetName]);
    if(oldTransportAction) {
        ((void(*)(id,SEL,SEL,id,UIEvent*))oldTransportAction)(object,cmd,action,target,event);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),
                   dispatch_get_main_queue(),^{snapshot([@"after-transport-" stringByAppendingString:selectorName]);});
}
static BOOL installClassHook(const char *className,SEL action,IMP replacement,IMP *original) {
    Class cls=objc_getClass(className);
    if(!cls)return NO;
    Method method=class_getInstanceMethod(cls,action);
    if(!method)return NO;
    IMP previous=method_getImplementation(method);
    *original=previous;
    if(!class_addMethod(cls,action,replacement,method_getTypeEncoding(method))){
        *original=method_setImplementation(method,replacement);
    }
    traceLine([NSString stringWithFormat:@"HOOK %@ %@ success",
               @(className),NSStringFromSelector(action)]);
    return YES;
}
static void tryInstall(void) {
    if(!isGuest())return;
    // Swift module and Objective-C classes must have been loaded by dyld.
    if(!installedNowPlaying)
        installedNowPlaying=installClassHook("_TtC16MusicApplication24NowPlayingViewController",
             @selector(viewDidAppear:),(IMP)hookNowPlayingAppeared,&oldNowPlayingAppeared);
    if(!installedControls)
        installedControls=installClassHook("MusicNowPlayingControlsViewController",
             @selector(viewDidAppear:),(IMP)hookControlsAppeared,&oldControlsAppeared);
    if(!installedTransport)
        installedTransport=installClassHook("_TtC16MusicApplication25NowPlayingTransportButton",
             @selector(sendAction:to:forEvent:),(IMP)hookTransportAction,&oldTransportAction);
    if((!installedNowPlaying || !installedControls || !installedTransport) && ++probeAttempts<8){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),
                       dispatch_get_main_queue(),^{tryInstall();});
    }
}
__attribute__((constructor))
static void startup(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(!isGuest())return;
        CFTypeRef (*createTask)(CFAllocatorRef) = (void*)dlsym(RTLD_DEFAULT,"SecTaskCreateFromSelf");
        CFTypeRef sec=createTask?createTask(kCFAllocatorDefault):NULL;
        traceLine([NSString stringWithFormat:@"START hostBundle=%@ musicUsageKey=%d musicUserTokenEntitlement=%d libraryEntitlement=%d",
          NSBundle.mainBundle.bundleIdentifier,
          NSBundle.mainBundle.infoDictionary[@"NSAppleMusicUsageDescription"]!=nil,
          entitlementPresent(sec,@"com.apple.developer.music-user-token"),
          entitlementPresent(sec,@"com.apple.developer.media-library")]);
        if(sec)CFRelease(sec);
        tryInstall();
    });
}

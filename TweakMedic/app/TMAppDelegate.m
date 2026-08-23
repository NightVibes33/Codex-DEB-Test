#import "TMAppDelegate.h"
#import "TMRootViewController.h"

@implementation TMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[TMRootViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    (void)app; (void)options;
    if (![url.scheme.lowercaseString isEqualToString:@"tweakmedic"]) return NO;
    TMRootViewController *root = (TMRootViewController *)self.window.rootViewController;
    if ([url.host.lowercaseString isEqualToString:@"history"]) root.selectedIndex = 2;
    else if ([url.host.lowercaseString isEqualToString:@"scan"]) root.selectedIndex = 1;
    else root.selectedIndex = 0;
    [root refreshVisibleTab];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    (void)application;
    [(TMRootViewController *)self.window.rootViewController refreshVisibleTab];
}

@end

#import <Preferences/PSListController.h>
#import <UIKit/UIKit.h>

@interface TMRootListController : PSListController
@end

@implementation TMRootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (void)openTweakMedic {
    NSURL *url = [NSURL URLWithString:@"tweakmedic://"];
    if ([UIApplication.sharedApplication canOpenURL:url]) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}
@end

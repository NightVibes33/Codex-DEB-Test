#import <Foundation/Foundation.h>

@interface TMScanner : NSObject
+ (instancetype)sharedScanner;
- (NSDictionary *)snapshot;
- (NSDictionary *)status;
- (NSDictionary *)reports;
- (NSDictionary *)startScanForBundleID:(NSString *)bundleID timeout:(NSInteger)timeout;
- (NSDictionary *)restoreStaging;
- (NSDictionary *)setTweak:(NSString *)name disabled:(BOOL)disabled;
- (NSDictionary *)uninstallPackage:(NSString *)package;
@end

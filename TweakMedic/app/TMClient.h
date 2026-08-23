#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMClient : NSObject
+ (NSDictionary *)request:(NSDictionary *)request error:(NSError **)error;
+ (NSDictionary *)ping:(NSError **)error;
+ (NSDictionary *)snapshot:(NSError **)error;
+ (NSDictionary *)status:(NSError **)error;
+ (NSDictionary *)reports:(NSError **)error;
+ (NSDictionary *)startScanForBundleID:(NSString *)bundleID timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSDictionary *)setTweak:(NSString *)name disabled:(BOOL)disabled error:(NSError **)error;
+ (NSDictionary *)uninstallPackage:(NSString *)package error:(NSError **)error;
+ (NSDictionary *)restoreStaging:(NSError **)error;
@end

NS_ASSUME_NONNULL_END

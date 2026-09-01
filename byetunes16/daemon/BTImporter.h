#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BTImporter : NSObject
+ (NSDictionary *)probe;
+ (NSDictionary *)importFileAtPath:(NSString *)path sourceName:(NSString * _Nullable)sourceName;
+ (NSDictionary *)restoreLatestBackup;
@end

NS_ASSUME_NONNULL_END

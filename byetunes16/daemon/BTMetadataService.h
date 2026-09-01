#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BTMetadataService : NSObject
+ (NSDictionary *)search:(NSString *)query;
@end

NS_ASSUME_NONNULL_END

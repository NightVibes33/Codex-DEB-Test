#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^BTClientCompletion)(NSDictionary * _Nullable response, NSError * _Nullable error);

@interface BTClient : NSObject
+ (instancetype)sharedClient;
- (void)sendRequest:(NSDictionary *)request completion:(BTClientCompletion)completion;
@end

NS_ASSUME_NONNULL_END

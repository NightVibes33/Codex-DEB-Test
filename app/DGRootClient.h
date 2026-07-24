#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DGRootClientCompletion)(NSDictionary * _Nullable response, NSError * _Nullable error);

@interface DGRootClient : NSObject
@property(nonatomic, copy) NSString *socketPath;
- (void)sendRequest:(NSDictionary *)request completion:(DGRootClientCompletion)completion;
@end

NS_ASSUME_NONNULL_END

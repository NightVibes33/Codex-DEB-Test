#import "DGRootClient.h"
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>

@implementation DGRootClient

- (instancetype)init {
    self = [super init];
    if (self) {
        _socketPath = @"/var/jb/var/run/darkgpt-rootd.sock";
    }
    return self;
}

- (void)sendRequest:(NSDictionary *)request completion:(DGRootClientCompletion)completion {
    NSDictionary *copiedRequest = [request copy];
    NSString *socketPath = [self.socketPath copy];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *serializationError = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:copiedRequest options:0 error:&serializationError];
        if (!json) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, serializationError); });
            return;
        }

        int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) {
            NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }

        struct sockaddr_un address;
        memset(&address, 0, sizeof(address));
        address.sun_family = AF_UNIX;
        const char *path = socketPath.fileSystemRepresentation;
        if (strlen(path) >= sizeof(address.sun_path)) {
            close(fd);
            NSError *error = [NSError errorWithDomain:@"DarkGPT" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Root daemon socket path is too long."}];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        strlcpy(address.sun_path, path, sizeof(address.sun_path));

        if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
            NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: @"Could not connect to darkgpt-rootd. Confirm the jailbreak is active and the daemon is loaded."}];
            close(fd);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }

        NSMutableData *payload = [json mutableCopy];
        const uint8_t newline = '\n';
        [payload appendBytes:&newline length:1];

        const uint8_t *bytes = payload.bytes;
        NSUInteger remaining = payload.length;
        while (remaining > 0) {
            ssize_t written = write(fd, bytes, remaining);
            if (written <= 0) {
                NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
                close(fd);
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
                return;
            }
            bytes += written;
            remaining -= (NSUInteger)written;
        }
        shutdown(fd, SHUT_WR);

        NSMutableData *responseData = [NSMutableData data];
        uint8_t buffer[8192];
        while (responseData.length < 1024 * 1024) {
            ssize_t count = read(fd, buffer, sizeof(buffer));
            if (count == 0) break;
            if (count < 0) {
                NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
                close(fd);
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
                return;
            }
            [responseData appendBytes:buffer length:(NSUInteger)count];
        }
        close(fd);

        NSError *parseError = nil;
        id object = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&parseError];
        if (![object isKindOfClass:NSDictionary.class]) {
            NSError *error = parseError ?: [NSError errorWithDomain:@"DarkGPT" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Root daemon returned an invalid response."}];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{ completion((NSDictionary *)object, nil); });
    });
}

@end

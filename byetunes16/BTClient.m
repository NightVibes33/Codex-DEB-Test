#import "BTClient.h"
#import <arpa/inet.h>
#import <sys/socket.h>
#import <unistd.h>

static const uint16_t kBTDaemonPort = 45981;

@implementation BTClient

+ (instancetype)sharedClient {
    static BTClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ client = [BTClient new]; });
    return client;
}

- (void)sendRequest:(NSDictionary *)request completion:(BTClientCompletion)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *jsonError = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:&jsonError];
        if (!json) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, jsonError); });
            return;
        }

        NSMutableData *wire = [json mutableCopy];
        uint8_t newline = '\n';
        [wire appendBytes:&newline length:1];

        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) {
            NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
            return;
        }

        struct timeval timeout = { .tv_sec = 20, .tv_usec = 0 };
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

        struct sockaddr_in addr = {0};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(kBTDaemonPort);
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);

        if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
            NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: @"ByeTunes16 helper is not reachable"}];
            close(fd);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
            return;
        }

        const uint8_t *bytes = wire.bytes;
        size_t remaining = wire.length;
        while (remaining > 0) {
            ssize_t n = send(fd, bytes, remaining, 0);
            if (n <= 0) break;
            bytes += n;
            remaining -= (size_t)n;
        }

        NSMutableData *responseData = [NSMutableData data];
        uint8_t buffer[4096];
        while (responseData.length < 1024 * 1024) {
            ssize_t n = recv(fd, buffer, sizeof(buffer), 0);
            if (n <= 0) break;
            [responseData appendBytes:buffer length:(NSUInteger)n];
            if (memchr(buffer, '\n', (size_t)n)) break;
        }
        close(fd);

        while (responseData.length && ((const uint8_t *)responseData.bytes)[responseData.length - 1] == '\n') {
            [responseData setLength:responseData.length - 1];
        }

        NSError *parseError = nil;
        NSDictionary *response = responseData.length ? [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&parseError] : nil;
        if (![response isKindOfClass:NSDictionary.class]) {
            NSError *err = parseError ?: [NSError errorWithDomain:@"ByeTunes16" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response from ByeTunes16 helper"}];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{ completion(response, nil); });
    });
}

@end

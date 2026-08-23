#import "TMClient.h"
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>

static NSString * const TMSocketPath = @"/var/run/tweakmedicd.sock";

@implementation TMClient

+ (NSDictionary *)request:(NSDictionary *)request error:(NSError **)error {
    NSData *body = [NSJSONSerialization dataWithJSONObject:request options:0 error:error];
    if (!body) return @{};

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        if (error) *error = [NSError errorWithDomain:@"TweakMedic" code:errno userInfo:@{NSLocalizedDescriptionKey:@"Could not create daemon socket."}];
        return @{};
    }

    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, TMSocketPath.UTF8String, sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        if (error) *error = [NSError errorWithDomain:@"TweakMedic" code:errno userInfo:@{NSLocalizedDescriptionKey:@"TweakMedic daemon is not reachable."}];
        close(fd);
        return @{};
    }

    NSMutableData *wire = [body mutableCopy];
    [wire appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    const uint8_t *bytes = wire.bytes;
    NSUInteger remaining = wire.length;
    while (remaining > 0) {
        ssize_t sent = write(fd, bytes, remaining);
        if (sent <= 0) break;
        bytes += sent;
        remaining -= (NSUInteger)sent;
    }
    shutdown(fd, SHUT_WR);

    NSMutableData *response = [NSMutableData data];
    uint8_t buffer[8192];
    for (;;) {
        ssize_t n = read(fd, buffer, sizeof(buffer));
        if (n <= 0) break;
        [response appendBytes:buffer length:(NSUInteger)n];
        if (response.length > (4 * 1024 * 1024)) break;
    }
    close(fd);

    if (response.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"TweakMedic" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"Daemon returned an empty response."}];
        return @{};
    }

    id object = [NSJSONSerialization JSONObjectWithData:response options:0 error:error];
    return [object isKindOfClass:NSDictionary.class] ? object : @{};
}

+ (NSDictionary *)ping:(NSError **)error { return [self request:@{ @"op": @"ping" } error:error]; }
+ (NSDictionary *)snapshot:(NSError **)error { return [self request:@{ @"op": @"snapshot" } error:error]; }
+ (NSDictionary *)status:(NSError **)error { return [self request:@{ @"op": @"status" } error:error]; }
+ (NSDictionary *)reports:(NSError **)error { return [self request:@{ @"op": @"reports" } error:error]; }
+ (NSDictionary *)startScanForBundleID:(NSString *)bundleID timeout:(NSInteger)timeout error:(NSError **)error {
    return [self request:@{ @"op": @"scan", @"bundleID": bundleID ?: @"", @"timeout": @(MAX(8, MIN(timeout, 120))) } error:error];
}
+ (NSDictionary *)setTweak:(NSString *)name disabled:(BOOL)disabled error:(NSError **)error {
    return [self request:@{ @"op": disabled ? @"disable" : @"enable", @"tweak": name ?: @"" } error:error];
}
+ (NSDictionary *)uninstallPackage:(NSString *)package error:(NSError **)error {
    return [self request:@{ @"op": @"uninstall", @"package": package ?: @"" } error:error];
}
+ (NSDictionary *)restoreStaging:(NSError **)error { return [self request:@{ @"op": @"restore" } error:error]; }

@end

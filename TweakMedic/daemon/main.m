#import <Foundation/Foundation.h>
#import "TMScanner.h"
#import <signal.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <sys/un.h>
#import <unistd.h>

static const char *kSocketPath = "/var/run/tweakmedicd.sock";

static NSDictionary *TMHandleRequest(NSDictionary *request) {
    NSString *op = [request[@"op"] isKindOfClass:NSString.class] ? request[@"op"] : @"";
    TMScanner *scanner = TMScanner.sharedScanner;
    if ([op isEqualToString:@"ping"]) return @{ @"ok": @YES, @"daemon": @"tweakmedicd", @"version": @"1.0.0", @"pid": @(getpid()) };
    if ([op isEqualToString:@"snapshot"]) return [scanner snapshot];
    if ([op isEqualToString:@"status"]) return [scanner status];
    if ([op isEqualToString:@"reports"]) return [scanner reports];
    if ([op isEqualToString:@"restore"]) return [scanner restoreStaging];
    if ([op isEqualToString:@"scan"]) {
        NSString *bundleID = [request[@"bundleID"] isKindOfClass:NSString.class] ? request[@"bundleID"] : @"";
        NSInteger timeout = [request[@"timeout"] integerValue];
        if (timeout <= 0) timeout = 22;
        return [scanner startScanForBundleID:bundleID timeout:timeout];
    }
    if ([op isEqualToString:@"disable"] || [op isEqualToString:@"enable"]) {
        NSString *name = [request[@"tweak"] isKindOfClass:NSString.class] ? request[@"tweak"] : @"";
        return [scanner setTweak:name disabled:[op isEqualToString:@"disable"]];
    }
    if ([op isEqualToString:@"uninstall"]) {
        NSString *package = [request[@"package"] isKindOfClass:NSString.class] ? request[@"package"] : @"";
        return [scanner uninstallPackage:package];
    }
    return @{ @"ok": @NO, @"error": @"Unknown operation." };
}

static void TMServeClient(int fd) {
    @autoreleasepool {
        NSMutableData *input = [NSMutableData data];
        uint8_t buffer[8192];
        while (input.length < (4 * 1024 * 1024)) {
            ssize_t n = read(fd, buffer, sizeof(buffer));
            if (n <= 0) break;
            [input appendBytes:buffer length:(NSUInteger)n];
            if (memchr(buffer, '\n', (size_t)n)) break;
        }
        while (input.length && ((const uint8_t *)input.bytes)[input.length - 1] <= ' ') [input setLength:input.length - 1];
        NSError *error = nil;
        NSDictionary *request = input.length ? [NSJSONSerialization JSONObjectWithData:input options:0 error:&error] : nil;
        NSDictionary *response;
        if (![request isKindOfClass:NSDictionary.class]) response = @{ @"ok": @NO, @"error": error.localizedDescription ?: @"Invalid JSON request." };
        else response = TMHandleRequest(request);
        NSData *wire = [NSJSONSerialization dataWithJSONObject:response ?: @{ @"ok": @NO } options:0 error:nil];
        if (wire) write(fd, wire.bytes, wire.length);
    }
}

int main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        (void)TMScanner.sharedScanner;
        unlink(kSocketPath);
        int server = socket(AF_UNIX, SOCK_STREAM, 0);
        if (server < 0) return 2;
        struct sockaddr_un addr = {0};
        addr.sun_family = AF_UNIX;
        strncpy(addr.sun_path, kSocketPath, sizeof(addr.sun_path) - 1);
        mode_t oldMask = umask(0);
        int bound = bind(server, (struct sockaddr *)&addr, sizeof(addr));
        umask(oldMask);
        if (bound != 0) { close(server); return 3; }
        chmod(kSocketPath, 0666);
        if (listen(server, 16) != 0) { close(server); return 4; }
        for (;;) {
            int client = accept(server, NULL, NULL);
            if (client < 0) { if (errno == EINTR) continue; sleep(1); continue; }
            TMServeClient(client);
            close(client);
        }
    }
    return 0;
}

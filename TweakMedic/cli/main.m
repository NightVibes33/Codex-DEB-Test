#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>

static NSDictionary *Send(NSDictionary *request) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return @{ @"ok": @NO, @"error": @"socket failed" };
    struct sockaddr_un addr = {0}; addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, "/var/run/tweakmedicd.sock", sizeof(addr.sun_path)-1);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) { close(fd); return @{ @"ok": @NO, @"error": @"daemon unavailable" }; }
    NSMutableData *wire = [json mutableCopy]; [wire appendBytes:"\n" length:1];
    write(fd, wire.bytes, wire.length); shutdown(fd, SHUT_WR);
    NSMutableData *out = [NSMutableData data]; uint8_t buf[8192];
    for (;;) { ssize_t n = read(fd, buf, sizeof(buf)); if (n <= 0) break; [out appendBytes:buf length:(NSUInteger)n]; }
    close(fd);
    NSDictionary *r = out.length ? [NSJSONSerialization JSONObjectWithData:out options:0 error:nil] : nil;
    return [r isKindOfClass:NSDictionary.class] ? r : @{ @"ok": @NO, @"error": @"invalid daemon response" };
}

static void Usage(void) {
    fprintf(stderr, "tweakmedicctl ping|snapshot|status|reports|restore|scan <bundle-id> [seconds]|disable <tweak>|enable <tweak>|uninstall <package>\n");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 2) { Usage(); return 64; }
        NSString *cmd = [NSString stringWithUTF8String:argv[1]];
        NSMutableDictionary *req = [NSMutableDictionary dictionary];
        if ([cmd isEqualToString:@"ping"] || [cmd isEqualToString:@"snapshot"] || [cmd isEqualToString:@"status"] || [cmd isEqualToString:@"reports"] || [cmd isEqualToString:@"restore"]) req[@"op"] = cmd;
        else if ([cmd isEqualToString:@"scan"] && argc >= 3) { req[@"op"] = @"scan"; req[@"bundleID"] = [NSString stringWithUTF8String:argv[2]]; req[@"timeout"] = @(argc >= 4 ? atoi(argv[3]) : 22); }
        else if (([cmd isEqualToString:@"disable"] || [cmd isEqualToString:@"enable"]) && argc >= 3) { req[@"op"] = cmd; req[@"tweak"] = [NSString stringWithUTF8String:argv[2]]; }
        else if ([cmd isEqualToString:@"uninstall"] && argc >= 3) { req[@"op"] = @"uninstall"; req[@"package"] = [NSString stringWithUTF8String:argv[2]]; }
        else { Usage(); return 64; }
        NSDictionary *r = Send(req);
        NSData *pretty = [NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingPrettyPrinted error:nil];
        fwrite(pretty.bytes, 1, pretty.length, stdout); fputc('\n', stdout);
        return [r[@"ok"] boolValue] ? 0 : 1;
    }
}

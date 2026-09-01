#import <Foundation/Foundation.h>
#import "BTImporter.h"
#import <arpa/inet.h>
#import <errno.h>
#import <signal.h>
#import <string.h>
#import <sys/socket.h>
#import <unistd.h>

static const uint16_t kBTPort = 45981;
static const NSUInteger kBTMaxRequest = 2 * 1024 * 1024;

static NSDictionary *BTHandle(NSDictionary *request) {
    NSString *op = [request[@"op"] isKindOfClass:NSString.class] ? request[@"op"] : @"";
    if ([op isEqualToString:@"probe"]) return [BTImporter probe];
    if ([op isEqualToString:@"backup"]) return [BTImporter createBackup];
    if ([op isEqualToString:@"restore"]) return [BTImporter restoreLatestBackup];
    if ([op isEqualToString:@"repair"]) return [BTImporter repairLibrary];
    if ([op isEqualToString:@"library"]) {
        NSUInteger limit = [request[@"limit"] unsignedIntegerValue];
        return [BTImporter libraryWithLimit:limit ?: 250];
    }
    if ([op isEqualToString:@"playlists"]) return [BTImporter playlists];

    if ([op isEqualToString:@"searchMetadata"]) {
        NSString *query = [request[@"query"] isKindOfClass:NSString.class] ? request[@"query"] : @"";
        return [BTImporter searchMetadataForQuery:query];
    }

    if ([op isEqualToString:@"import"]) {
        NSString *path = [request[@"path"] isKindOfClass:NSString.class] ? request[@"path"] : nil;
        NSString *sourceName = [request[@"sourceName"] isKindOfClass:NSString.class] ? request[@"sourceName"] : nil;
        NSDictionary *metadata = [request[@"metadata"] isKindOfClass:NSDictionary.class] ? request[@"metadata"] : nil;
        NSString *playlist = [request[@"playlistName"] isKindOfClass:NSString.class] ? request[@"playlistName"] : nil;
        if (!path.length) return @{ @"ok": @NO, @"error": @"Missing import path" };
        return [BTImporter importFileAtPath:path sourceName:sourceName metadata:metadata playlistName:playlist];
    }

    if ([op isEqualToString:@"createPlaylist"]) {
        NSString *name = [request[@"name"] isKindOfClass:NSString.class] ? request[@"name"] : @"";
        NSArray *pids = [request[@"itemPIDs"] isKindOfClass:NSArray.class] ? request[@"itemPIDs"] : @[];
        return [BTImporter createPlaylistNamed:name itemPIDs:pids];
    }

    if ([op isEqualToString:@"addToPlaylist"]) {
        int64_t playlistPID = [request[@"playlistPID"] longLongValue];
        NSArray *pids = [request[@"itemPIDs"] isKindOfClass:NSArray.class] ? request[@"itemPIDs"] : @[];
        return [BTImporter addItemPIDs:pids toPlaylistPID:playlistPID];
    }

    if ([op isEqualToString:@"applyMetadataCandidate"]) {
        int64_t pid = [request[@"itemPID"] longLongValue];
        NSDictionary *candidate = [request[@"candidate"] isKindOfClass:NSDictionary.class] ? request[@"candidate"] : @{};
        if (pid <= 0) return @{ @"ok": @NO, @"error": @"Missing item PID" };
        return [BTImporter applyMetadataCandidate:candidate toItemPID:pid];
    }

    if ([op isEqualToString:@"updateMetadata"]) {
        int64_t pid = [request[@"itemPID"] longLongValue];
        NSDictionary *metadata = [request[@"metadata"] isKindOfClass:NSDictionary.class] ? request[@"metadata"] : @{};
        if (pid <= 0) return @{ @"ok": @NO, @"error": @"Missing item PID" };
        return [BTImporter updateMetadataForItemPID:pid metadata:metadata];
    }

    if ([op isEqualToString:@"delete"]) {
        int64_t pid = [request[@"itemPID"] longLongValue];
        if (pid <= 0) return @{ @"ok": @NO, @"error": @"Missing item PID" };
        return [BTImporter deleteItemPID:pid];
    }

    return @{ @"ok": @NO, @"error": [NSString stringWithFormat:@"Unknown operation: %@", op] };
}

static void BTSend(int fd, NSDictionary *response) {
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:response ?: @{ @"ok": @NO, @"error": @"No response" } options:0 error:&error];
    if (!json) json = [@"{\"ok\":false,\"error\":\"JSON encoding failed\"}" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *wire = [json mutableCopy];
    uint8_t nl = '\n';
    [wire appendBytes:&nl length:1];
    const uint8_t *bytes = wire.bytes;
    size_t left = wire.length;
    while (left) {
        ssize_t n = send(fd, bytes, left, 0);
        if (n <= 0) break;
        bytes += n;
        left -= (size_t)n;
    }
}

static void BTServeClient(int fd) {
    @autoreleasepool {
        struct timeval timeout = { .tv_sec = 30, .tv_usec = 0 };
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

        NSMutableData *data = [NSMutableData data];
        uint8_t buf[8192];
        BOOL gotNewline = NO;
        while (data.length < kBTMaxRequest && !gotNewline) {
            ssize_t n = recv(fd, buf, sizeof(buf), 0);
            if (n <= 0) break;
            const void *nl = memchr(buf, '\n', (size_t)n);
            if (nl) {
                size_t bytesBeforeNL = (const uint8_t *)nl - buf;
                [data appendBytes:buf length:bytesBeforeNL];
                gotNewline = YES;
            } else {
                [data appendBytes:buf length:(NSUInteger)n];
            }
        }

        if (!gotNewline || data.length == 0 || data.length >= kBTMaxRequest) {
            BTSend(fd, @{ @"ok": @NO, @"error": @"Invalid or oversized request" });
            close(fd);
            return;
        }

        NSError *error = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (![obj isKindOfClass:NSDictionary.class]) {
            BTSend(fd, @{ @"ok": @NO, @"error": error.localizedDescription ?: @"Request must be a JSON object" });
            close(fd);
            return;
        }

        BTSend(fd, BTHandle((NSDictionary *)obj));
        close(fd);
    }
}

int main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/mobile/Library/Logs" withIntermediateDirectories:YES attributes:nil error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/mobile/Library/ByeTunes16" withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil];

        int server = socket(AF_INET, SOCK_STREAM, 0);
        if (server < 0) return 2;
        int yes = 1;
        setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

        struct sockaddr_in addr = {0};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(kBTPort);
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);
        if (bind(server, (struct sockaddr *)&addr, sizeof(addr)) != 0) { close(server); return 3; }
        if (listen(server, 8) != 0) { close(server); return 4; }

        NSLog(@"[ByeTunes16] helper listening on 127.0.0.1:%u", kBTPort);
        for (;;) {
            int client = accept(server, NULL, NULL);
            if (client < 0) { if (errno == EINTR) continue; sleep(1); continue; }
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ BTServeClient(client); });
        }
    }
    return 0;
}

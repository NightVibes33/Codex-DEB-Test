#import "BTRestoreFix.h"
#import <sqlite3.h>
#import <unistd.h>

static NSString * const kBTDB = @"/var/mobile/Media/iTunes_Control/iTunes/MediaLibrary.sqlitedb";
static NSString * const kBTBackups = @"/var/mobile/Library/ByeTunes16/Backups";

static NSString *BTLatest(void) {
    NSArray *dirs = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:kBTBackups error:nil] sortedArrayUsingSelector:@selector(compare:)];
    NSString *last = dirs.lastObject;
    if (!last.length) return nil;
    NSString *p = [[kBTBackups stringByAppendingPathComponent:last] stringByAppendingPathComponent:@"MediaLibrary.sqlitedb"];
    return [[NSFileManager defaultManager] fileExistsAtPath:p] ? p : nil;
}

static NSString *BTCheck(sqlite3 *db) {
    sqlite3_stmt *s = NULL;
    NSString *out = @"unknown";
    if (sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &s, NULL) == SQLITE_OK && sqlite3_step(s) == SQLITE_ROW) {
        const unsigned char *p = sqlite3_column_text(s, 0);
        if (p) out = [NSString stringWithUTF8String:(const char *)p];
    }
    sqlite3_finalize(s);
    return out;
}

static BOOL BTHasItem(sqlite3 *db) {
    sqlite3_stmt *s = NULL;
    BOOL ok = NO;
    if (sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name='item' LIMIT 1", -1, &s, NULL) == SQLITE_OK) ok = sqlite3_step(s) == SQLITE_ROW;
    sqlite3_finalize(s);
    return ok;
}

@implementation BTRestoreFix
+ (NSDictionary *)restoreLatestBackupSafely {
    NSString *srcPath = BTLatest();
    if (!srcPath) return @{ @"ok":@NO, @"error":@"No ByeTunes backup exists" };

    sqlite3 *src = NULL;
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX;
    if (sqlite3_open_v2(srcPath.UTF8String, &src, flags, NULL) != SQLITE_OK) {
        NSString *e = src ? [NSString stringWithUTF8String:sqlite3_errmsg(src)] : @"Could not open backup";
        if (src) sqlite3_close(src);
        return @{ @"ok":@NO, @"error":e };
    }
    sqlite3_busy_timeout(src, 8000);
    NSString *srcCheck = BTCheck(src);
    if (![srcCheck isEqualToString:@"ok"] || !BTHasItem(src)) {
        sqlite3_close(src);
        return @{ @"ok":@NO, @"error":[NSString stringWithFormat:@"Backup validation failed (%@)", srcCheck] };
    }

    sqlite3 *dst = NULL;
    if (sqlite3_open_v2(kBTDB.UTF8String, &dst, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
        NSString *e = dst ? [NSString stringWithUTF8String:sqlite3_errmsg(dst)] : @"Could not open live media library";
        if (dst) sqlite3_close(dst);
        sqlite3_close(src);
        return @{ @"ok":@NO, @"error":e };
    }
    sqlite3_busy_timeout(dst, 8000);

    sqlite3_backup *b = sqlite3_backup_init(dst, "main", src, "main");
    if (!b) {
        NSString *e = [NSString stringWithUTF8String:sqlite3_errmsg(dst)];
        sqlite3_close(dst); sqlite3_close(src);
        return @{ @"ok":@NO, @"error":e ?: @"Could not initialize in-place restore" };
    }
    int rc = sqlite3_backup_step(b, -1);
    int finish = sqlite3_backup_finish(b);
    if (rc != SQLITE_DONE || finish != SQLITE_OK) {
        NSString *e = [NSString stringWithUTF8String:sqlite3_errmsg(dst)];
        sqlite3_close(dst); sqlite3_close(src);
        return @{ @"ok":@NO, @"error":e ?: [NSString stringWithFormat:@"Restore failed (%d/%d)", rc, finish] };
    }

    sqlite3_exec(dst, "PRAGMA wal_checkpoint(TRUNCATE)", NULL, NULL, NULL);
    NSString *after = BTCheck(dst);
    BOOL schema = BTHasItem(dst);
    sqlite3_close(dst); sqlite3_close(src);

    if (![after isEqualToString:@"ok"] || !schema) return @{ @"ok":@NO, @"error":[NSString stringWithFormat:@"Restored DB validation failed (%@)", after] };
    chown(kBTDB.fileSystemRepresentation, 501, 501);
    chmod(kBTDB.fileSystemRepresentation, 0644);
    return @{ @"ok":@YES, @"message":@"Latest media-library backup restored safely", @"backup":srcPath, @"quickCheck":after, @"restartMusic":@YES };
}
@end

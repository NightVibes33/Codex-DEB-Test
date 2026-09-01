#import "BTImporter.h"
#import "BTMetadataService.h"
#import <sqlite3.h>

static NSString * const BTFullDBPath = @"/var/mobile/Media/iTunes_Control/iTunes/MediaLibrary.sqlitedb";

static NSDictionary *BTFullFail(NSString *message) {
    return @{ @"ok": @NO, @"error": message ?: @"Unknown error" };
}

static int64_t BTFullPID(void) {
    uint64_t value = 0;
    arc4random_buf(&value, sizeof(value));
    value &= 0x7fffffffffffffffULL;
    if (value < 1000000000000000000ULL) value += 1000000000000000000ULL;
    return (int64_t)value;
}

@implementation BTImporter (Full)

+ (NSDictionary *)searchMetadataForQuery:(NSString *)query {
    return [BTMetadataService search:query ?: @""];
}

+ (NSDictionary *)applyMetadataCandidate:(NSDictionary *)candidate toItemPID:(int64_t)itemPID {
    if (itemPID <= 0) return BTFullFail(@"Invalid song PID");
    if (![candidate isKindOfClass:NSDictionary.class]) return BTFullFail(@"Invalid metadata candidate");
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    for (NSString *key in @[ @"title", @"artist", @"album", @"genre", @"year", @"track", @"disc", @"artworkURL", @"storeId" ]) {
        id value = candidate[key];
        if (value && value != NSNull.null && (! [value isKindOfClass:NSString.class] || [(NSString *)value length])) metadata[key] = value;
    }
    NSMutableDictionary *result = [[BTImporter updateMetadataForItemPID:itemPID metadata:metadata] mutableCopy];
    if ([result[@"ok"] boolValue]) {
        result[@"metadataSource"] = candidate[@"source"] ?: @"unknown";
        if (candidate[@"artworkURL"]) result[@"artworkURL"] = candidate[@"artworkURL"];
    }
    return result;
}

+ (NSDictionary *)addItemPIDs:(NSArray<NSNumber *> *)itemPIDs toPlaylistPID:(int64_t)playlistPID {
    if (playlistPID <= 0) return BTFullFail(@"Invalid playlist PID");
    if (![itemPIDs isKindOfClass:NSArray.class] || !itemPIDs.count) return BTFullFail(@"No songs were selected");

    NSDictionary *backup = [BTImporter createBackup];
    if (![backup[@"ok"] boolValue]) return BTFullFail(backup[@"error"] ?: @"Could not back up media library");

    sqlite3 *db = NULL;
    if (sqlite3_open_v2(BTFullDBPath.UTF8String, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
        NSString *error = db ? [NSString stringWithUTF8String:sqlite3_errmsg(db)] : @"Could not open media library";
        if (db) sqlite3_close(db);
        return BTFullFail(error);
    }
    sqlite3_busy_timeout(db, 8000);

    sqlite3_stmt *stmt = NULL;
    BOOL playlistExists = NO;
    if (sqlite3_prepare_v2(db, "SELECT 1 FROM container WHERE container_pid=? AND contained_media_type=8 LIMIT 1", -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, playlistPID);
        playlistExists = sqlite3_step(stmt) == SQLITE_ROW;
    }
    sqlite3_finalize(stmt);
    if (!playlistExists) {
        sqlite3_close(db);
        return BTFullFail(@"Playlist was not found");
    }

    char *sqliteError = NULL;
    if (sqlite3_exec(db, "BEGIN IMMEDIATE", NULL, NULL, &sqliteError) != SQLITE_OK) {
        NSString *error = sqliteError ? [NSString stringWithUTF8String:sqliteError] : @"Could not lock media library";
        if (sqliteError) sqlite3_free(sqliteError);
        sqlite3_close(db);
        return BTFullFail(error);
    }

    int64_t position = 0;
    if (sqlite3_prepare_v2(db, "SELECT COALESCE(MAX(position),-1)+1 FROM container_item WHERE container_pid=?", -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, playlistPID);
        if (sqlite3_step(stmt) == SQLITE_ROW) position = sqlite3_column_int64(stmt, 0);
    }
    sqlite3_finalize(stmt);

    NSUInteger added = 0;
    BOOL ok = YES;
    NSString *error = nil;
    for (NSNumber *number in itemPIDs) {
        int64_t itemPID = number.longLongValue;
        if (itemPID <= 0) continue;

        BOOL itemExists = NO;
        if (sqlite3_prepare_v2(db, "SELECT 1 FROM item WHERE item_pid=? AND media_type=8 LIMIT 1", -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(stmt, 1, itemPID);
            itemExists = sqlite3_step(stmt) == SQLITE_ROW;
        }
        sqlite3_finalize(stmt);
        if (!itemExists) continue;

        BOOL alreadyThere = NO;
        if (sqlite3_prepare_v2(db, "SELECT 1 FROM container_item WHERE container_pid=? AND item_pid=? LIMIT 1", -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(stmt, 1, playlistPID);
            sqlite3_bind_int64(stmt, 2, itemPID);
            alreadyThere = sqlite3_step(stmt) == SQLITE_ROW;
        }
        sqlite3_finalize(stmt);
        if (alreadyThere) continue;

        if (sqlite3_prepare_v2(db, "INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)", -1, &stmt, NULL) != SQLITE_OK) {
            ok = NO;
            error = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
            break;
        }
        NSString *uuid = NSUUID.UUID.UUIDString;
        sqlite3_bind_int64(stmt, 1, BTFullPID());
        sqlite3_bind_int64(stmt, 2, playlistPID);
        sqlite3_bind_int64(stmt, 3, itemPID);
        sqlite3_bind_int64(stmt, 4, position++);
        sqlite3_bind_text(stmt, 5, uuid.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) != SQLITE_DONE) {
            ok = NO;
            error = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
            sqlite3_finalize(stmt);
            break;
        }
        sqlite3_finalize(stmt);
        added++;
    }

    if (ok) {
        if (sqlite3_exec(db, "COMMIT", NULL, NULL, &sqliteError) != SQLITE_OK) {
            ok = NO;
            error = sqliteError ? [NSString stringWithUTF8String:sqliteError] : @"Commit failed";
            if (sqliteError) sqlite3_free(sqliteError);
        }
    } else {
        sqlite3_exec(db, "ROLLBACK", NULL, NULL, NULL);
    }
    sqlite3_close(db);

    if (!ok) return BTFullFail(error);
    return @{ @"ok": @YES, @"playlistPID": @(playlistPID), @"added": @(added), @"restartMusic": @YES };
}

@end

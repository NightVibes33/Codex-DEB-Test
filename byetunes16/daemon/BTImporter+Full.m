#import "BTImporter.h"
#import "BTMetadataService.h"
#import <CommonCrypto/CommonDigest.h>
#import <sqlite3.h>
#import <sys/stat.h>
#import <unistd.h>

static NSString * const BTFullDBPath = @"/var/mobile/Media/iTunes_Control/iTunes/MediaLibrary.sqlitedb";
static NSString * const BTFullArtworkDir = @"/var/mobile/Media/iTunes_Control/iTunes/Artwork/Originals";

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

static BOOL BTFullColumn(sqlite3 *db, NSString *table, NSString *column) {
    sqlite3_stmt *stmt = NULL;
    BOOL found = NO;
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", table];
    if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const unsigned char *p = sqlite3_column_text(stmt, 1);
            if (p && [column isEqualToString:[NSString stringWithUTF8String:(const char *)p]]) { found = YES; break; }
        }
    }
    sqlite3_finalize(stmt);
    return found;
}

static NSData *BTFullDownload(NSString *urlString, NSString **errorOut) {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    if (!url) { if (errorOut) *errorOut = @"Invalid artwork URL"; return nil; }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12.0];
    [request setValue:@"ByeTunes16/0.2 (iOS 16)" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *response, NSError *e) {
        (void)response;
        if (d.length <= 15 * 1024 * 1024) data = d;
        else error = [NSError errorWithDomain:@"ByeTunes16" code:413 userInfo:@{NSLocalizedDescriptionKey:@"Artwork is larger than 15 MB"}];
        if (e) error = e;
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 14 * NSEC_PER_SEC)) != 0) {
        [task cancel];
        if (errorOut) *errorOut = @"Artwork request timed out";
        return nil;
    }
    if (!data.length && errorOut) *errorOut = error.localizedDescription ?: @"Artwork provider returned no data";
    return data;
}

static NSString *BTFullArtworkRelativePath(NSString *token) {
    NSData *data = [token dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char hash[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", hash[i]];
    return [NSString stringWithFormat:@"%@/%@", [hex substringToIndex:2], [hex substringFromIndex:2]];
}

static BOOL BTFullExec(sqlite3 *db, NSString *sql, NSString **errorOut) {
    char *error = NULL;
    int rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, &error);
    if (rc == SQLITE_OK) return YES;
    if (errorOut) *errorOut = error ? [NSString stringWithUTF8String:error] : [NSString stringWithFormat:@"SQLite error %d", rc];
    if (error) sqlite3_free(error);
    return NO;
}

static BOOL BTFullBindArtwork(sqlite3 *db, NSData *data, int64_t itemPID, int64_t albumPID, NSString **errorOut) {
    if (!data.length || itemPID <= 0 || albumPID <= 0) return YES;
    NSString *token = [NSString stringWithFormat:@"%lld", itemPID];
    NSString *relative = BTFullArtworkRelativePath(token);
    NSString *path = [BTFullArtworkDir stringByAppendingPathComponent:relative];
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:nil];
    NSError *writeError = nil;
    if (![data writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
        if (errorOut) *errorOut = writeError.localizedDescription;
        return NO;
    }
    chown(path.fileSystemRepresentation, 501, 501);
    chmod(path.fileSystemRepresentation, 0644);

    BOOL artworkVariant = BTFullColumn(db, @"artwork", @"artwork_variant_type");
    BOOL tokenVariant = BTFullColumn(db, @"artwork_token", @"artwork_variant_type");
    BOOL bestVariant = BTFullColumn(db, @"best_artwork_token", @"artwork_variant_type");
    sqlite3_stmt *stmt = NULL;

    NSString *artworkSQL = artworkVariant
        ? @"INSERT OR REPLACE INTO artwork(artwork_token,artwork_source_type,relative_path,artwork_type,interest_data,artwork_variant_type) VALUES(?,1,?,1,'',0)"
        : @"INSERT OR REPLACE INTO artwork(artwork_token,artwork_source_type,relative_path,artwork_type,interest_data) VALUES(?,1,?,1,'')";
    if (sqlite3_prepare_v2(db, artworkSQL.UTF8String, -1, &stmt, NULL) != SQLITE_OK) goto fail;
    sqlite3_bind_text(stmt, 1, token.UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, relative.UTF8String, -1, SQLITE_TRANSIENT);
    if (sqlite3_step(stmt) != SQLITE_DONE) goto fail;
    sqlite3_finalize(stmt); stmt = NULL;

    int64_t entities[2] = { itemPID, albumPID };
    int types[2] = { 0, 1 };
    for (int i = 0; i < 2; i++) {
        NSString *tokenSQL = tokenVariant
            ? @"INSERT OR REPLACE INTO artwork_token(artwork_token,artwork_source_type,artwork_type,entity_pid,entity_type,artwork_variant_type) VALUES(?,1,1,?,?,0)"
            : @"INSERT OR REPLACE INTO artwork_token(artwork_token,artwork_source_type,artwork_type,entity_pid,entity_type) VALUES(?,1,1,?,?)";
        if (sqlite3_prepare_v2(db, tokenSQL.UTF8String, -1, &stmt, NULL) != SQLITE_OK) goto fail;
        sqlite3_bind_text(stmt, 1, token.UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 2, entities[i]);
        sqlite3_bind_int(stmt, 3, types[i]);
        if (sqlite3_step(stmt) != SQLITE_DONE) goto fail;
        sqlite3_finalize(stmt); stmt = NULL;

        NSString *bestSQL = bestVariant
            ? @"INSERT OR REPLACE INTO best_artwork_token(entity_pid,entity_type,artwork_type,available_artwork_token,fetchable_artwork_token,fetchable_artwork_source_type,artwork_variant_type) VALUES(?,?,1,?,'',0,0)"
            : @"INSERT OR REPLACE INTO best_artwork_token(entity_pid,entity_type,artwork_type,available_artwork_token,fetchable_artwork_token,fetchable_artwork_source_type) VALUES(?,?,1,?,'',0)";
        if (sqlite3_prepare_v2(db, bestSQL.UTF8String, -1, &stmt, NULL) != SQLITE_OK) goto fail;
        sqlite3_bind_int64(stmt, 1, entities[i]);
        sqlite3_bind_int(stmt, 2, types[i]);
        sqlite3_bind_text(stmt, 3, token.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) != SQLITE_DONE) goto fail;
        sqlite3_finalize(stmt); stmt = NULL;
    }
    return YES;

fail:
    if (errorOut) *errorOut = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
    sqlite3_finalize(stmt);
    return NO;
}

@implementation BTImporter (Full)

+ (NSDictionary *)searchMetadataForQuery:(NSString *)query {
    return [BTMetadataService search:query ?: @""];
}

+ (NSDictionary *)applyMetadataCandidate:(NSDictionary *)candidate toItemPID:(int64_t)itemPID {
    if (itemPID <= 0) return BTFullFail(@"Invalid song PID");
    if (![candidate isKindOfClass:NSDictionary.class]) return BTFullFail(@"Invalid metadata candidate");
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    for (NSString *key in @[ @"title", @"artist", @"album", @"genre", @"year", @"track", @"disc", @"storeId" ]) {
        id value = candidate[key];
        if (value && value != NSNull.null && (![value isKindOfClass:NSString.class] || [(NSString *)value length])) metadata[key] = value;
    }

    NSMutableDictionary *result = [[BTImporter updateMetadataForItemPID:itemPID metadata:metadata] mutableCopy];
    if (![result[@"ok"] boolValue]) return result;
    result[@"metadataSource"] = candidate[@"source"] ?: @"unknown";

    NSString *artworkURL = [candidate[@"artworkURL"] isKindOfClass:NSString.class] ? candidate[@"artworkURL"] : nil;
    if (!artworkURL.length) return result;
    result[@"artworkURL"] = artworkURL;

    NSString *artError = nil;
    NSData *artwork = BTFullDownload(artworkURL, &artError);
    if (!artwork.length) {
        result[@"artworkApplied"] = @NO;
        result[@"artworkWarning"] = artError ?: @"Artwork could not be downloaded";
        return result;
    }

    sqlite3 *db = NULL;
    if (sqlite3_open_v2(BTFullDBPath.UTF8String, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
        result[@"artworkApplied"] = @NO;
        result[@"artworkWarning"] = db ? [NSString stringWithUTF8String:sqlite3_errmsg(db)] : @"Could not reopen media library for artwork";
        if (db) sqlite3_close(db);
        return result;
    }
    sqlite3_busy_timeout(db, 8000);

    sqlite3_stmt *stmt = NULL;
    int64_t albumPID = 0;
    if (sqlite3_prepare_v2(db, "SELECT album_pid FROM item WHERE item_pid=? LIMIT 1", -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, itemPID);
        if (sqlite3_step(stmt) == SQLITE_ROW) albumPID = sqlite3_column_int64(stmt, 0);
    }
    sqlite3_finalize(stmt);

    BOOL ok = albumPID > 0 && BTFullExec(db, @"BEGIN IMMEDIATE", &artError);
    if (ok) ok = BTFullBindArtwork(db, artwork, itemPID, albumPID, &artError);
    if (ok) ok = BTFullExec(db, @"COMMIT", &artError);
    else BTFullExec(db, @"ROLLBACK", NULL);
    sqlite3_close(db);

    result[@"artworkApplied"] = @(ok);
    if (!ok) result[@"artworkWarning"] = artError ?: @"Artwork database binding failed";
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

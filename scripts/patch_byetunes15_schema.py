from pathlib import Path
import re

root = Path("byetunes16")
main = root / "daemon" / "BTImporter.m"
full = root / "daemon" / "BTImporter+Full.m"

s = main.read_text()

# iOS 15.8.8 lacks artwork_variant_type in artwork/artwork_token/best_artwork_token.
# Select the SQL shape at runtime so the same source remains usable on iOS 16.
if 'BOOL artworkVariant = BTColumn(db, @"artwork", @"artwork_variant_type")' not in s:
    artwork_impl = r'''static BOOL BTWriteArtwork(sqlite3 *db, NSData *data, int64_t itemPID, int64_t albumPID, NSString **errorOut) {
    if (!data.length || !BTTable(db, @"artwork") || !BTTable(db, @"artwork_token") || !BTTable(db, @"best_artwork_token")) return YES;
    NSString *token = [NSString stringWithFormat:@"%lld", itemPID];
    NSString *rel = BTRelativeArtworkPath(token);
    NSString *path = [BTArtworkDir stringByAppendingPathComponent:rel];
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:nil];
    NSError *writeError = nil;
    if (![data writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
        if (errorOut) *errorOut = writeError.localizedDescription;
        return NO;
    }
    chown(path.fileSystemRepresentation, 501, 501);
    chmod(path.fileSystemRepresentation, 0644);

    BOOL artworkVariant = BTColumn(db, @"artwork", @"artwork_variant_type");
    BOOL tokenVariant = BTColumn(db, @"artwork_token", @"artwork_variant_type");
    BOOL bestVariant = BTColumn(db, @"best_artwork_token", @"artwork_variant_type");
    sqlite3_stmt *stmt = NULL;

    NSString *artworkSQL = artworkVariant
        ? @"INSERT OR REPLACE INTO artwork(artwork_token,artwork_source_type,relative_path,artwork_type,artwork_variant_type) VALUES(?,1,?,1,0)"
        : @"INSERT OR REPLACE INTO artwork(artwork_token,artwork_source_type,relative_path,artwork_type) VALUES(?,1,?,1)";
    if (sqlite3_prepare_v2(db, artworkSQL.UTF8String, -1, &stmt, NULL) != SQLITE_OK) goto fail;
    sqlite3_bind_text(stmt, 1, token.UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, rel.UTF8String, -1, SQLITE_TRANSIENT);
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

static NSString *BTBackup'''
    s, n = re.subn(r"static BOOL BTWriteArtwork\(.*?\n\}\n\nstatic NSString \*BTBackup", artwork_impl, s, count=1, flags=re.S)
    if n != 1:
        raise SystemExit("BTWriteArtwork target block not found")

# iOS 15.8.8 container_item has no uuid column.
if 'BOOL hasUUID=BTColumn(db,@"container_item",@"uuid")' not in s:
    old = 'sqlite3_finalize(s);NSInteger pos=0;for(NSNumber*n in pids){if(sqlite3_prepare_v2(db,"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)",-1,&s,NULL)!=SQLITE_OK)goto fail;NSString*u=NSUUID.UUID.UUIDString;sqlite3_bind_int64(s,1,BTPID());sqlite3_bind_int64(s,2,pid);sqlite3_bind_int64(s,3,n.longLongValue);sqlite3_bind_int64(s,4,pos++);sqlite3_bind_text(s,5,u.UTF8String,-1,SQLITE_TRANSIENT);if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);}'
    new = 'sqlite3_finalize(s);BOOL hasUUID=BTColumn(db,@"container_item",@"uuid");NSInteger pos=0;for(NSNumber*n in pids){const char*sql=hasUUID?"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)":"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position) VALUES(?,?,?,?)";if(sqlite3_prepare_v2(db,sql,-1,&s,NULL)!=SQLITE_OK)goto fail;sqlite3_bind_int64(s,1,BTPID());sqlite3_bind_int64(s,2,pid);sqlite3_bind_int64(s,3,n.longLongValue);sqlite3_bind_int64(s,4,pos++);if(hasUUID){NSString*u=NSUUID.UUID.UUIDString;sqlite3_bind_text(s,5,u.UTF8String,-1,SQLITE_TRANSIENT);}if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);}'
    if old not in s:
        raise SystemExit("BTImporter playlist target block not found")
    s = s.replace(old, new, 1)

main.write_text(s)

s = full.read_text()
if 'BOOL hasUUID = BTFullColumn(db, @"container_item", @"uuid")' not in s:
    old = '''        if (sqlite3_prepare_v2(db, "INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)", -1, &stmt, NULL) != SQLITE_OK) {
            ok = NO;
            error = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
            break;
        }
        NSString *uuid = NSUUID.UUID.UUIDString;
        sqlite3_bind_int64(stmt, 1, BTFullPID());
        sqlite3_bind_int64(stmt, 2, playlistPID);
        sqlite3_bind_int64(stmt, 3, itemPID);
        sqlite3_bind_int64(stmt, 4, position++);
        sqlite3_bind_text(stmt, 5, uuid.UTF8String, -1, SQLITE_TRANSIENT);'''
    new = '''        BOOL hasUUID = BTFullColumn(db, @"container_item", @"uuid");
        const char *insertSQL = hasUUID
            ? "INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)"
            : "INSERT INTO container_item(container_item_pid,container_pid,item_pid,position) VALUES(?,?,?,?)";
        if (sqlite3_prepare_v2(db, insertSQL, -1, &stmt, NULL) != SQLITE_OK) {
            ok = NO;
            error = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
            break;
        }
        sqlite3_bind_int64(stmt, 1, BTFullPID());
        sqlite3_bind_int64(stmt, 2, playlistPID);
        sqlite3_bind_int64(stmt, 3, itemPID);
        sqlite3_bind_int64(stmt, 4, position++);
        if (hasUUID) {
            NSString *uuid = NSUUID.UUID.UUIDString;
            sqlite3_bind_text(stmt, 5, uuid.UTF8String, -1, SQLITE_TRANSIENT);
        }'''
    if old not in s:
        raise SystemExit("BTImporter+Full playlist target block not found")
    s = s.replace(old, new, 1)
full.write_text(s)

print("PATCH_OK")

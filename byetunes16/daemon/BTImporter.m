#import "BTImporter.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CommonCrypto/CommonDigest.h>
#import <sqlite3.h>
#import <sys/stat.h>
#import <unistd.h>

static NSString * const BTDBPath = @"/var/mobile/Media/iTunes_Control/iTunes/MediaLibrary.sqlitedb";
static NSString * const BTMusicDir = @"/var/mobile/Media/iTunes_Control/Music/F00";
static NSString * const BTArtworkDir = @"/var/mobile/Media/iTunes_Control/iTunes/Artwork/Originals";
static NSString * const BTStateDir = @"/var/mobile/Library/ByeTunes16";
static NSString * const BTBackupDir = @"/var/mobile/Library/ByeTunes16/Backups";

static NSDictionary *BTFail(NSString *message) { return @{ @"ok": @NO, @"error": message ?: @"Unknown error" }; }
static NSDictionary *BTOK(NSDictionary *extra) {
    NSMutableDictionary *r = [@{ @"ok": @YES } mutableCopy];
    if (extra) [r addEntriesFromDictionary:extra];
    return r;
}

static BOOL BTExec(sqlite3 *db, NSString *sql, NSString **errorOut) {
    char *err = NULL;
    int rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, &err);
    if (rc == SQLITE_OK) return YES;
    if (errorOut) *errorOut = err ? [NSString stringWithUTF8String:err] : [NSString stringWithFormat:@"SQLite error %d", rc];
    if (err) sqlite3_free(err);
    return NO;
}

static BOOL BTTable(sqlite3 *db, NSString *table) {
    sqlite3_stmt *s = NULL; BOOL ok = NO;
    if (sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", -1, &s, NULL) == SQLITE_OK) {
        sqlite3_bind_text(s, 1, table.UTF8String, -1, SQLITE_TRANSIENT);
        ok = sqlite3_step(s) == SQLITE_ROW;
    }
    sqlite3_finalize(s); return ok;
}

static BOOL BTColumn(sqlite3 *db, NSString *table, NSString *column) {
    sqlite3_stmt *s = NULL; BOOL found = NO;
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", table];
    if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &s, NULL) == SQLITE_OK) {
        while (sqlite3_step(s) == SQLITE_ROW) {
            const unsigned char *p = sqlite3_column_text(s, 1);
            if (p && [column isEqualToString:[NSString stringWithUTF8String:(const char *)p]]) { found = YES; break; }
        }
    }
    sqlite3_finalize(s); return found;
}

static NSString *BTQuickCheck(sqlite3 *db) {
    sqlite3_stmt *s = NULL; NSString *out = @"unknown";
    if (sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &s, NULL) == SQLITE_OK && sqlite3_step(s) == SQLITE_ROW) {
        const unsigned char *p = sqlite3_column_text(s, 0);
        if (p) out = [NSString stringWithUTF8String:(const char *)p];
    }
    sqlite3_finalize(s); return out;
}

static int64_t BTPID(void) {
    uint64_t v = 0; arc4random_buf(&v, sizeof(v));
    v &= 0x7fffffffffffffffULL;
    if (v < 1000000000000000000ULL) v += 1000000000000000000ULL;
    return (int64_t)v;
}

static NSString *BTText(sqlite3_stmt *s, int col) {
    const unsigned char *p = sqlite3_column_text(s, col);
    return p ? [NSString stringWithUTF8String:(const char *)p] : @"";
}

static BOOL BTSchemaOK(sqlite3 *db, NSString **errorOut) {
    NSArray *tables = @[ @"item", @"item_extra", @"item_playback", @"item_artist", @"album", @"album_artist", @"genre", @"sort_map", @"base_location", @"container", @"container_item" ];
    for (NSString *t in tables) if (!BTTable(db, t)) { if (errorOut) *errorOut = [NSString stringWithFormat:@"Missing table %@", t]; return NO; }
    NSDictionary *cols = @{ @"item": @[ @"item_pid", @"media_type", @"base_location_id" ], @"item_extra": @[ @"item_pid", @"title", @"location" ], @"sort_map": @[ @"name", @"name_order", @"name_section", @"sort_key" ] };
    for (NSString *t in cols) for (NSString *c in cols[t]) if (!BTColumn(db, t, c)) { if (errorOut) *errorOut = [NSString stringWithFormat:@"Missing column %@.%@", t, c]; return NO; }
    return YES;
}

static sqlite3 *BTOpen(BOOL write, NSString **errorOut) {
    sqlite3 *db = NULL;
    int flags = write ? (SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX) : (SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX);
    if (sqlite3_open_v2(BTDBPath.UTF8String, &db, flags, NULL) != SQLITE_OK) {
        if (errorOut) *errorOut = db ? [NSString stringWithUTF8String:sqlite3_errmsg(db)] : @"sqlite3_open failed";
        if (db) sqlite3_close(db); return NULL;
    }
    sqlite3_busy_timeout(db, 8000);
    return db;
}

static NSInteger BTSection(NSString *name) {
    NSString *n = [[name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:NSLocale.currentLocale] uppercaseString];
    if (!n.length) return 26;
    unichar c = [n characterAtIndex:0];
    return (c >= 'A' && c <= 'Z') ? c - 'A' : 26;
}

static BOOL BTSort(sqlite3 *db, NSString *name, int64_t *orderOut, NSInteger *sectionOut, NSString **errorOut) {
    sqlite3_stmt *s = NULL;
    if (sqlite3_prepare_v2(db, "SELECT name_order,name_section FROM sort_map WHERE name=? LIMIT 1", -1, &s, NULL) == SQLITE_OK) {
        sqlite3_bind_text(s, 1, name.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(s) == SQLITE_ROW) {
            *orderOut = sqlite3_column_int64(s, 0); *sectionOut = sqlite3_column_int(s, 1); sqlite3_finalize(s); return YES;
        }
    }
    sqlite3_finalize(s);
    int64_t next = 1;
    if (sqlite3_prepare_v2(db, "SELECT COALESCE(MAX(name_order),0)+1 FROM sort_map", -1, &s, NULL) == SQLITE_OK && sqlite3_step(s) == SQLITE_ROW) next = sqlite3_column_int64(s, 0);
    sqlite3_finalize(s);
    NSInteger sec = BTSection(name);
    NSData *key = [[name lowercaseString] dataUsingEncoding:NSUTF8StringEncoding] ?: NSData.data;
    if (sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO sort_map(name,name_order,name_section,sort_key) VALUES(?,?,?,?)", -1, &s, NULL) != SQLITE_OK) goto fail;
    sqlite3_bind_text(s,1,name.UTF8String,-1,SQLITE_TRANSIENT); sqlite3_bind_int64(s,2,next); sqlite3_bind_int(s,3,(int)sec); sqlite3_bind_blob(s,4,key.bytes,(int)key.length,SQLITE_TRANSIENT);
    if (sqlite3_step(s) != SQLITE_DONE) goto fail;
    sqlite3_finalize(s); *orderOut = next; *sectionOut = sec; return YES;
fail:
    if (errorOut) *errorOut = [NSString stringWithUTF8String:sqlite3_errmsg(db)]; sqlite3_finalize(s); return NO;
}

static int64_t BTNamedPID(sqlite3 *db, NSString *table, NSString *nameCol, NSString *pidCol, NSString *name) {
    sqlite3_stmt *s = NULL; int64_t pid = 0;
    NSString *q = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=? LIMIT 1", pidCol, table, nameCol];
    if (sqlite3_prepare_v2(db, q.UTF8String, -1, &s, NULL) == SQLITE_OK) {
        sqlite3_bind_text(s,1,name.UTF8String,-1,SQLITE_TRANSIENT); if (sqlite3_step(s)==SQLITE_ROW) pid=sqlite3_column_int64(s,0);
    }
    sqlite3_finalize(s); return pid;
}

static BOOL BTArtist(sqlite3 *db, NSString *name, int64_t rep, int64_t *pidOut, NSString **errorOut) {
    int64_t pid = BTNamedPID(db,@"item_artist",@"item_artist",@"item_artist_pid",name); if (pid) { *pidOut=pid; return YES; }
    pid=BTPID(); sqlite3_stmt *s=NULL;
    if (sqlite3_prepare_v2(db,"INSERT INTO item_artist(item_artist_pid,item_artist,sort_item_artist,series_name,sync_id,keep_local,representative_item_pid) VALUES(?,?,?,'',?,1,?)",-1,&s,NULL)!=SQLITE_OK) goto fail;
    sqlite3_bind_int64(s,1,pid); sqlite3_bind_text(s,2,name.UTF8String,-1,SQLITE_TRANSIENT); sqlite3_bind_text(s,3,name.UTF8String,-1,SQLITE_TRANSIENT); sqlite3_bind_int64(s,4,BTPID()); sqlite3_bind_int64(s,5,rep);
    if(sqlite3_step(s)!=SQLITE_DONE) goto fail; sqlite3_finalize(s); *pidOut=pid; return YES;
fail: if(errorOut)*errorOut=[NSString stringWithUTF8String:sqlite3_errmsg(db)]; sqlite3_finalize(s); return NO;
}

static BOOL BTAlbumArtist(sqlite3 *db, NSString *name, int64_t rep, int64_t *pidOut, NSString **errorOut) {
    int64_t pid=BTNamedPID(db,@"album_artist",@"album_artist",@"album_artist_pid",name); if(pid){*pidOut=pid;return YES;}
    pid=BTPID(); sqlite3_stmt *s=NULL;
    if(sqlite3_prepare_v2(db,"INSERT INTO album_artist(album_artist_pid,album_artist,sort_album_artist,sync_id,keep_local,representative_item_pid) VALUES(?,?,?, ?,1,?)",-1,&s,NULL)!=SQLITE_OK)goto fail;
    sqlite3_bind_int64(s,1,pid);sqlite3_bind_text(s,2,name.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(s,3,name.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(s,4,BTPID());sqlite3_bind_int64(s,5,rep);
    if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);*pidOut=pid;return YES;
fail:if(errorOut)*errorOut=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(s);return NO;
}

static BOOL BTAlbum(sqlite3 *db, NSString *name, int64_t aa, int64_t rep, NSInteger year, int64_t *pidOut, NSString **errorOut) {
    sqlite3_stmt *s=NULL;int64_t pid=0;
    if(sqlite3_prepare_v2(db,"SELECT album_pid FROM album WHERE album=? AND album_artist_pid=? LIMIT 1",-1,&s,NULL)==SQLITE_OK){sqlite3_bind_text(s,1,name.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(s,2,aa);if(sqlite3_step(s)==SQLITE_ROW)pid=sqlite3_column_int64(s,0);}sqlite3_finalize(s);
    if(pid){*pidOut=pid;return YES;}pid=BTPID();
    if(sqlite3_prepare_v2(db,"INSERT INTO album(album_pid,album,sort_album,album_artist_pid,album_year,keep_local,sync_id,representative_item_pid) VALUES(?,?,?,?,?,1,?,?)",-1,&s,NULL)!=SQLITE_OK)goto fail;
    sqlite3_bind_int64(s,1,pid);sqlite3_bind_text(s,2,name.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(s,3,name.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(s,4,aa);sqlite3_bind_int(s,5,(int)year);sqlite3_bind_int64(s,6,BTPID());sqlite3_bind_int64(s,7,rep);
    if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);*pidOut=pid;return YES;
fail:if(errorOut)*errorOut=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(s);return NO;
}

static BOOL BTGenre(sqlite3 *db, NSString *name, int64_t rep, int64_t *pidOut, NSString **errorOut) {
    int64_t pid=BTNamedPID(db,@"genre",@"genre",@"genre_id",name);if(pid){*pidOut=pid;return YES;}pid=BTPID();sqlite3_stmt*s=NULL;
    if(sqlite3_prepare_v2(db,"INSERT INTO genre(genre_id,genre,representative_item_pid,sync_id,keep_local) VALUES(?,?,?, ?,1)",-1,&s,NULL)!=SQLITE_OK)goto fail;
    sqlite3_bind_int64(s,1,pid);sqlite3_bind_text(s,2,name.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(s,3,rep);sqlite3_bind_int64(s,4,BTPID());if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);*pidOut=pid;return YES;
fail:if(errorOut)*errorOut=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(s);return NO;
}

static NSString *BTMeta(AVURLAsset *a, AVMetadataIdentifier i) {
    for(AVMetadataItem *m in [AVMetadataItem metadataItemsFromArray:a.commonMetadata filteredByIdentifier:i]) if(m.stringValue.length)return m.stringValue; return nil;
}

static NSData *BTArtworkData(AVURLAsset *a) {
    for(AVMetadataItem *m in [AVMetadataItem metadataItemsFromArray:a.commonMetadata filteredByIdentifier:AVMetadataCommonIdentifierArtwork]) { if(m.dataValue.length)return m.dataValue; }
    return nil;
}

static NSString *BTName(NSString *ext) {
    static NSString *chars=@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";NSMutableString*n=[NSMutableString string];for(int i=0;i<12;i++)[n appendFormat:@"%C",[chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];return [NSString stringWithFormat:@"%@.%@",n,ext.length?ext.lowercaseString:@"mp3"];
}

static int BTFourCC(NSString *e) {
    e=e.lowercaseString;if([e isEqual:@"mp3"])return 301;if([e isEqual:@"m4a"]||[e isEqual:@"aac"])return 0x61616320;if([e isEqual:@"alac"])return 0x616c6163;if([e isEqual:@"flac"])return 0x664c6143;if([e isEqual:@"wav"]||[e isEqual:@"wave"])return 0x57415645;if([e isEqual:@"opus"])return 0x6f707573;return 0;
}

static NSString *BTRelativeArtworkPath(NSString *token) {
    NSData *d=[token dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA1_DIGEST_LENGTH];CC_SHA1(d.bytes,(CC_LONG)d.length,hash);NSMutableString*h=[NSMutableString string];for(int i=0;i<CC_SHA1_DIGEST_LENGTH;i++)[h appendFormat:@"%02x",hash[i]];return [NSString stringWithFormat:@"%@/%@",[h substringToIndex:2],[h substringFromIndex:2]];
}

static BOOL BTWriteArtwork(sqlite3 *db, NSData *data, int64_t itemPID, int64_t albumPID, NSString **errorOut) {
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

static NSString *BTBackup(sqlite3 *db, NSString **errorOut) {
    NSFileManager*fm=NSFileManager.defaultManager;[fm createDirectoryAtPath:BTBackupDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:nil];NSDateFormatter*f=[NSDateFormatter new];f.dateFormat=@"yyyyMMdd-HHmmss";NSString*dir=[BTBackupDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@",[f stringFromDate:NSDate.date],[NSUUID.UUID.UUIDString substringToIndex:8]]];[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];NSString*dstPath=[dir stringByAppendingPathComponent:@"MediaLibrary.sqlitedb"];sqlite3*dst=NULL;if(sqlite3_open(dstPath.UTF8String,&dst)!=SQLITE_OK){if(errorOut)*errorOut=@"Could not open backup DB";if(dst)sqlite3_close(dst);return nil;}sqlite3_backup*b=sqlite3_backup_init(dst,"main",db,"main");if(!b){if(errorOut)*errorOut=[NSString stringWithUTF8String:sqlite3_errmsg(dst)];sqlite3_close(dst);return nil;}int rc=sqlite3_backup_step(b,-1);sqlite3_backup_finish(b);sqlite3_close(dst);if(rc!=SQLITE_DONE){if(errorOut)*errorOut=[NSString stringWithFormat:@"Backup failed (%d)",rc];return nil;}chown(dstPath.fileSystemRepresentation,501,501);chmod(dstPath.fileSystemRepresentation,0644);NSArray*dirs=[[fm contentsOfDirectoryAtPath:BTBackupDir error:nil] sortedArrayUsingSelector:@selector(compare:)];if(dirs.count>12)for(NSUInteger i=0;i<dirs.count-12;i++)[fm removeItemAtPath:[BTBackupDir stringByAppendingPathComponent:dirs[i]] error:nil];return dir;
}

static NSString *BTLatestBackup(void) { NSArray*d=[[NSFileManager.defaultManager contentsOfDirectoryAtPath:BTBackupDir error:nil] sortedArrayUsingSelector:@selector(compare:)];if(!d.lastObject)return nil;NSString*p=[[BTBackupDir stringByAppendingPathComponent:d.lastObject] stringByAppendingPathComponent:@"MediaLibrary.sqlitedb"];return[NSFileManager.defaultManager fileExistsAtPath:p]?p:nil; }

static BOOL BTCreatePlaylistInternal(sqlite3*db,NSString*name,NSArray<NSNumber*>*pids,int64_t*pidOut,NSString**errorOut){if(!name.length){if(errorOut)*errorOut=@"Playlist name is empty";return NO;}int64_t order=0;NSInteger section=0;if(!BTSort(db,name,&order,&section,errorOut))return NO;int64_t pid=BTPID(),now=(int64_t)NSDate.date.timeIntervalSince1970;sqlite3_stmt*s=NULL;if(sqlite3_prepare_v2(db,"INSERT INTO container(container_pid,name,name_order,date_created,date_modified,contained_media_type,is_owner,is_editable,distinguished_kind) VALUES(?,?,?,?,?,8,1,1,0)",-1,&s,NULL)!=SQLITE_OK)goto fail;sqlite3_bind_int64(s,1,pid);sqlite3_bind_text(s,2,name.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(s,3,order);sqlite3_bind_int64(s,4,now);sqlite3_bind_int64(s,5,now);if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);BOOL hasUUID=BTColumn(db,@"container_item",@"uuid");NSInteger pos=0;for(NSNumber*n in pids){const char*sql=hasUUID?"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)":"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position) VALUES(?,?,?,?)";if(sqlite3_prepare_v2(db,sql,-1,&s,NULL)!=SQLITE_OK)goto fail;sqlite3_bind_int64(s,1,BTPID());sqlite3_bind_int64(s,2,pid);sqlite3_bind_int64(s,3,n.longLongValue);sqlite3_bind_int64(s,4,pos++);if(hasUUID){NSString*u=NSUUID.UUID.UUIDString;sqlite3_bind_text(s,5,u.UTF8String,-1,SQLITE_TRANSIENT);}if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);}if(pidOut)*pidOut=pid;return YES;
fail:if(errorOut)*errorOut=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(s);return NO;}

@implementation BTImporter

+ (NSDictionary *)probe {
    NSMutableDictionary*r=[NSMutableDictionary dictionaryWithDictionary:@{ @"ok":@YES,@"os":NSProcessInfo.processInfo.operatingSystemVersionString?:@"unknown",@"uid":@(getuid()),@"rootless":@([NSFileManager.defaultManager fileExistsAtPath:@"/var/jb"]),@"dbPath":BTDBPath,@"dbExists":@([NSFileManager.defaultManager fileExistsAtPath:BTDBPath]),@"musicDirExists":@([NSFileManager.defaultManager fileExistsAtPath:BTMusicDir]),@"latestBackup":BTLatestBackup()?:[NSNull null] }];NSString*e=nil;sqlite3*db=BTOpen(NO,&e);if(!db){r[@"ok"]=@NO;r[@"error"]=e?:@"open failed";return r;}r[@"quickCheck"]=BTQuickCheck(db);r[@"schemaOK"]=@(BTSchemaOK(db,&e));if(e)r[@"schemaError"]=e;sqlite3_stmt*s=NULL;if(sqlite3_prepare_v2(db,"PRAGMA user_version",-1,&s,NULL)==SQLITE_OK&&sqlite3_step(s)==SQLITE_ROW)r[@"userVersion"]=@(sqlite3_column_int(s,0));sqlite3_finalize(s);sqlite3_close(db);return r;
}

+ (NSDictionary *)createBackup { NSString*e=nil;sqlite3*db=BTOpen(NO,&e);if(!db)return BTFail(e);NSString*p=BTBackup(db,&e);sqlite3_close(db);return p?BTOK(@{ @"backup":p }):BTFail(e); }

+ (NSDictionary *)restoreLatestBackup {
    NSString*src=BTLatestBackup();if(!src)return BTFail(@"No ByeTunes16 backup exists");NSFileManager*fm=NSFileManager.defaultManager;NSString*tmp=[BTDBPath stringByAppendingString:@".byetunes-restore"];[fm removeItemAtPath:tmp error:nil];NSError*e=nil;if(![fm copyItemAtPath:src toPath:tmp error:&e])return BTFail(e.localizedDescription);sqlite3*check=NULL;if(sqlite3_open_v2(tmp.UTF8String,&check,SQLITE_OPEN_READONLY,NULL)!=SQLITE_OK){[fm removeItemAtPath:tmp error:nil];if(check)sqlite3_close(check);return BTFail(@"Backup DB could not be opened");}NSString*q=BTQuickCheck(check);sqlite3_close(check);if(![q isEqual:@"ok"]){[fm removeItemAtPath:tmp error:nil];return BTFail([NSString stringWithFormat:@"Backup integrity check failed: %@",q]);}[fm removeItemAtPath:[BTDBPath stringByAppendingString:@"-wal"] error:nil];[fm removeItemAtPath:[BTDBPath stringByAppendingString:@"-shm"] error:nil];NSString*old=[BTDBPath stringByAppendingString:@".before-restore"];[fm removeItemAtPath:old error:nil];[fm moveItemAtPath:BTDBPath toPath:old error:nil];if(![fm moveItemAtPath:tmp toPath:BTDBPath error:&e]){[fm moveItemAtPath:old toPath:BTDBPath error:nil];return BTFail(e.localizedDescription);}[fm removeItemAtPath:old error:nil];chown(BTDBPath.fileSystemRepresentation,501,501);chmod(BTDBPath.fileSystemRepresentation,0644);return BTOK(@{ @"message":@"Latest media-library backup restored" });
}

+ (NSDictionary *)importFileAtPath:(NSString *)path sourceName:(NSString *)sourceName metadata:(NSDictionary *)metadata playlistName:(NSString *)playlistName {
    NSFileManager*fm=NSFileManager.defaultManager;if(![fm fileExistsAtPath:path])return BTFail(@"Selected file no longer exists");NSString*ext=path.pathExtension.lowercaseString;NSSet*allowed=[NSSet setWithArray:@[@"mp3",@"m4a",@"aac",@"alac",@"flac",@"wav",@"wave",@"opus"]];if(![allowed containsObject:ext])return BTFail([NSString stringWithFormat:@"Unsupported audio format: %@",ext]);
    AVURLAsset*a=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];NSString*fallback=(sourceName.length?sourceName:path.lastPathComponent).stringByDeletingPathExtension;NSString*title=metadata[@"title"]?:BTMeta(a,AVMetadataCommonIdentifierTitle)?:fallback?:@"Imported Audio";NSString*artist=metadata[@"artist"]?:BTMeta(a,AVMetadataCommonIdentifierArtist)?:@"Unknown Artist";NSString*album=metadata[@"album"]?:BTMeta(a,AVMetadataCommonIdentifierAlbumName)?:@"Imported with ByeTunes16";NSString*genre=metadata[@"genre"]?:@"Unknown Genre";NSInteger year=[metadata[@"year"] integerValue];if(year<=0)year=[NSCalendar.currentCalendar component:NSCalendarUnitYear fromDate:NSDate.date];NSInteger track=MAX(1,[metadata[@"track"] integerValue]);NSInteger disc=MAX(1,[metadata[@"disc"] integerValue]);NSString*lyrics=metadata[@"lyrics"]?:@"";NSData*art=BTArtworkData(a);NSTimeInterval sec=CMTimeGetSeconds(a.duration);if(!isfinite(sec)||sec<0)sec=0;int64_t dur=(int64_t)llround(sec*1000.0);int64_t size=[fm attributesOfItemAtPath:path error:nil][NSFileSize]?[[fm attributesOfItemAtPath:path error:nil][NSFileSize] longLongValue]:0;
    [fm createDirectoryAtPath:BTMusicDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:nil];NSString*remote=BTName(ext);NSString*dest=[BTMusicDir stringByAppendingPathComponent:remote];NSError*copyErr=nil;if(![fm copyItemAtPath:path toPath:dest error:&copyErr])return BTFail([NSString stringWithFormat:@"Audio copy failed: %@",copyErr.localizedDescription]);chown(dest.fileSystemRepresentation,501,501);chmod(dest.fileSystemRepresentation,0644);
    NSString*e=nil;sqlite3*db=BTOpen(YES,&e);if(!db){[fm removeItemAtPath:dest error:nil];return BTFail(e);}if(!BTSchemaOK(db,&e)){sqlite3_close(db);[fm removeItemAtPath:dest error:nil];return BTFail(e);}if(![BTQuickCheck(db) isEqual:@"ok"]){sqlite3_close(db);[fm removeItemAtPath:dest error:nil];return BTFail(@"MediaLibrary.sqlitedb failed quick_check before import");}if(!BTBackup(db,&e)){sqlite3_close(db);[fm removeItemAtPath:dest error:nil];return BTFail([NSString stringWithFormat:@"Backup failed; import aborted: %@",e]);}if(!BTExec(db,@"BEGIN IMMEDIATE",&e)){sqlite3_close(db);[fm removeItemAtPath:dest error:nil];return BTFail(e);}
    BOOL ok=YES;int64_t item=BTPID(),artistPID=0,aa=0,albumPID=0,genrePID=0;int64_t to=0,aro=0,alo=0,aao=0,go=0;NSInteger ts=26,ars=26,als=26,aas=26,gs=26;ok&=BTExec(db,@"INSERT OR IGNORE INTO base_location(base_location_id,path) VALUES(3840,'iTunes_Control/Music/F00')",&e);if(ok)ok&=BTSort(db,title,&to,&ts,&e);if(ok)ok&=BTSort(db,artist,&aro,&ars,&e);if(ok)ok&=BTSort(db,album,&alo,&als,&e);if(ok)ok&=BTSort(db,artist,&aao,&aas,&e);if(ok)ok&=BTSort(db,genre,&go,&gs,&e);if(ok)ok&=BTArtist(db,artist,item,&artistPID,&e);if(ok)ok&=BTAlbumArtist(db,artist,item,&aa,&e);if(ok)ok&=BTAlbum(db,album,aa,item,year,&albumPID,&e);if(ok)ok&=BTGenre(db,genre,item,&genrePID,&e);int64_t now=(int64_t)NSDate.date.timeIntervalSince1970;
    if(ok){NSString*q=[NSString stringWithFormat:@"INSERT INTO item(item_pid,media_type,title_order,title_order_section,item_artist_pid,item_artist_order,item_artist_order_section,album_pid,album_order,album_order_section,album_artist_pid,album_artist_order,album_artist_order_section,genre_id,genre_order,genre_order_section,disc_number,track_number,base_location_id,keep_local,keep_local_status,in_my_library,date_added,date_downloaded) VALUES(%lld,8,%lld,%ld,%lld,%lld,%ld,%lld,%lld,%ld,%lld,%lld,%ld,%lld,%lld,%ld,%ld,%ld,3840,1,2,1,%lld,%lld)",item,to,(long)ts,artistPID,aro,(long)ars,albumPID,alo,(long)als,aa,aao,(long)aas,genrePID,go,(long)gs,(long)disc,(long)track,now,now];ok&=BTExec(db,q,&e);}
    if(ok){sqlite3_stmt*s=NULL;if(sqlite3_prepare_v2(db,"INSERT INTO item_extra(item_pid,title,sort_title,disc_count,track_count,total_time_ms,year,location,file_size,integrity,date_modified,media_kind,location_kind_id,copyright) VALUES(?,?,?,1,1,?,?,?,?,X'',?,1,42,'')",-1,&s,NULL)!=SQLITE_OK)ok=NO;else{sqlite3_bind_int64(s,1,item);sqlite3_bind_text(s,2,title.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(s,3,title.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(s,4,dur);sqlite3_bind_int(s,5,(int)year);sqlite3_bind_text(s,6,remote.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(s,7,size);sqlite3_bind_int64(s,8,now);ok=sqlite3_step(s)==SQLITE_DONE;}if(!ok)e=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(s);}
    if(ok){NSString*q=[NSString stringWithFormat:@"INSERT OR REPLACE INTO item_playback(item_pid,audio_format,bit_rate,codec_type,codec_subtype,data_kind,duration,has_video,relative_volume,sample_rate) VALUES(%lld,%d,320,0,0,0,0,0,0,44100)",item,BTFourCC(ext)];ok&=BTExec(db,q,&e);}if(ok&&BTTable(db,@"item_stats"))ok&=BTExec(db,[NSString stringWithFormat:@"INSERT OR REPLACE INTO item_stats(item_pid,date_accessed) VALUES(%lld,%lld)",item,now],&e);if(ok&&BTTable(db,@"item_store"))ok&=BTExec(db,[NSString stringWithFormat:@"INSERT OR REPLACE INTO item_store(item_pid,sync_id,sync_in_my_library,is_subscription) VALUES(%lld,%lld,1,0)",item,BTPID()],&e);if(ok&&BTTable(db,@"item_search"))ok&=BTExec(db,[NSString stringWithFormat:@"INSERT OR REPLACE INTO item_search(item_pid,search_title,search_album,search_artist,search_composer,search_album_artist) VALUES(%lld,%lld,%lld,%lld,0,%lld)",item,to,alo,aro,aao],&e);if(ok&&BTTable(db,@"lyrics")){sqlite3_stmt*s=NULL;if(sqlite3_prepare_v2(db,"INSERT OR REPLACE INTO lyrics(item_pid,lyrics,store_lyrics_available,time_synced_lyrics_available) VALUES(?,?,0,0)",-1,&s,NULL)==SQLITE_OK){sqlite3_bind_int64(s,1,item);sqlite3_bind_text(s,2,lyrics.UTF8String,-1,SQLITE_TRANSIENT);ok=sqlite3_step(s)==SQLITE_DONE;}sqlite3_finalize(s);}if(ok&&BTTable(db,@"chapter"))BTExec(db,[NSString stringWithFormat:@"INSERT OR REPLACE INTO chapter(item_pid) VALUES(%lld)",item],NULL);if(ok&&art.length)ok&=BTWriteArtwork(db,art,item,albumPID,&e);if(ok&&playlistName.length){int64_t pp=0;ok&=BTCreatePlaylistInternal(db,playlistName,@[@(item)],&pp,&e);}if(ok)ok&=BTExec(db,@"COMMIT",&e);else BTExec(db,@"ROLLBACK",NULL);NSString*after=ok?BTQuickCheck(db):@"not-run";sqlite3_close(db);if(!ok||![after isEqual:@"ok"]){[fm removeItemAtPath:dest error:nil];return BTFail(e?:[NSString stringWithFormat:@"Post-import quick_check: %@",after]);}return BTOK(@{ @"itemPID":@(item),@"title":title,@"artist":artist,@"album":album,@"location":remote,@"artwork":@(art.length>0),@"restartMusic":@YES });
}

+ (NSDictionary *)libraryWithLimit:(NSUInteger)limit {
    NSString*e=nil;sqlite3*db=BTOpen(NO,&e);if(!db)return BTFail(e);limit=MIN(MAX(limit,1),500);NSString*q=[NSString stringWithFormat:@"SELECT i.item_pid,x.title,IFNULL(ar.item_artist,''),IFNULL(al.album,''),IFNULL(g.genre,''),x.year,x.location,x.file_size,i.base_location_id FROM item i JOIN item_extra x ON x.item_pid=i.item_pid LEFT JOIN item_artist ar ON ar.item_artist_pid=i.item_artist_pid LEFT JOIN album al ON al.album_pid=i.album_pid LEFT JOIN genre g ON g.genre_id=i.genre_id WHERE i.media_type=8 ORDER BY i.date_added DESC LIMIT %lu",(unsigned long)limit];sqlite3_stmt*s=NULL;NSMutableArray*rows=[NSMutableArray array];if(sqlite3_prepare_v2(db,q.UTF8String,-1,&s,NULL)==SQLITE_OK)while(sqlite3_step(s)==SQLITE_ROW)[rows addObject:@{ @"itemPID":@(sqlite3_column_int64(s,0)),@"title":BTText(s,1),@"artist":BTText(s,2),@"album":BTText(s,3),@"genre":BTText(s,4),@"year":@(sqlite3_column_int(s,5)),@"location":BTText(s,6),@"fileSize":@(sqlite3_column_int64(s,7)),@"baseLocation":@(sqlite3_column_int(s,8)) }];else e=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(s);sqlite3_close(db);return e?BTFail(e):BTOK(@{ @"songs":rows });
}

+ (NSDictionary *)playlists {
    NSString*e=nil;sqlite3*db=BTOpen(NO,&e);if(!db)return BTFail(e);sqlite3_stmt*s=NULL;NSMutableArray*rows=[NSMutableArray array];const char*q="SELECT c.container_pid,c.name,COUNT(ci.item_pid) FROM container c LEFT JOIN container_item ci ON ci.container_pid=c.container_pid WHERE c.contained_media_type=8 AND c.distinguished_kind=0 GROUP BY c.container_pid,c.name ORDER BY c.name COLLATE NOCASE";if(sqlite3_prepare_v2(db,q,-1,&s,NULL)==SQLITE_OK)while(sqlite3_step(s)==SQLITE_ROW)[rows addObject:@{ @"containerPID":@(sqlite3_column_int64(s,0)),@"name":BTText(s,1),@"count":@(sqlite3_column_int(s,2)) }];else e=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(s);sqlite3_close(db);return e?BTFail(e):BTOK(@{ @"playlists":rows });
}

+ (NSDictionary *)createPlaylistNamed:(NSString *)name itemPIDs:(NSArray<NSNumber *> *)itemPIDs {
    NSString*e=nil;sqlite3*db=BTOpen(YES,&e);if(!db)return BTFail(e);if(!BTBackup(db,&e)){sqlite3_close(db);return BTFail(e);}BTExec(db,@"BEGIN IMMEDIATE",&e);int64_t pid=0;BOOL ok=BTCreatePlaylistInternal(db,name,itemPIDs,&pid,&e);ok?BTExec(db,@"COMMIT",&e):BTExec(db,@"ROLLBACK",NULL);sqlite3_close(db);return ok?BTOK(@{ @"containerPID":@(pid),@"name":name }):BTFail(e);
}

+ (NSDictionary *)updateMetadataForItemPID:(int64_t)itemPID metadata:(NSDictionary *)metadata {
    NSString*e=nil;sqlite3*db=BTOpen(YES,&e);if(!db)return BTFail(e);if(!BTBackup(db,&e)){sqlite3_close(db);return BTFail(e);}sqlite3_stmt*s=NULL;NSString*title=metadata[@"title"],*artist=metadata[@"artist"],*album=metadata[@"album"],*genre=metadata[@"genre"];NSInteger year=[metadata[@"year"] integerValue];if(sqlite3_prepare_v2(db,"SELECT IFNULL(x.title,''),IFNULL(ar.item_artist,''),IFNULL(al.album,''),IFNULL(g.genre,''),x.year FROM item i JOIN item_extra x ON x.item_pid=i.item_pid LEFT JOIN item_artist ar ON ar.item_artist_pid=i.item_artist_pid LEFT JOIN album al ON al.album_pid=i.album_pid LEFT JOIN genre g ON g.genre_id=i.genre_id WHERE i.item_pid=?",-1,&s,NULL)!=SQLITE_OK){e=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_close(db);return BTFail(e);}sqlite3_bind_int64(s,1,itemPID);if(sqlite3_step(s)!=SQLITE_ROW){sqlite3_finalize(s);sqlite3_close(db);return BTFail(@"Song not found");}if(!title.length)title=BTText(s,0);if(!artist.length)artist=BTText(s,1);if(!album.length)album=BTText(s,2);if(!genre.length)genre=BTText(s,3);if(year<=0)year=sqlite3_column_int(s,4);sqlite3_finalize(s);if(!BTExec(db,@"BEGIN IMMEDIATE",&e)){sqlite3_close(db);return BTFail(e);}int64_t to=0,aro=0,alo=0,aao=0,go=0;NSInteger ts=26,ars=26,als=26,aas=26,gs=26;int64_t ap=0,aa=0,alp=0,gp=0;BOOL ok=BTSort(db,title,&to,&ts,&e)&&BTSort(db,artist,&aro,&ars,&e)&&BTSort(db,album,&alo,&als,&e)&&BTSort(db,artist,&aao,&aas,&e)&&BTSort(db,genre,&go,&gs,&e)&&BTArtist(db,artist,itemPID,&ap,&e)&&BTAlbumArtist(db,artist,itemPID,&aa,&e)&&BTAlbum(db,album,aa,itemPID,year,&alp,&e)&&BTGenre(db,genre,itemPID,&gp,&e);if(ok){NSString*q=[NSString stringWithFormat:@"UPDATE item SET title_order=%lld,title_order_section=%ld,item_artist_pid=%lld,item_artist_order=%lld,item_artist_order_section=%ld,album_pid=%lld,album_order=%lld,album_order_section=%ld,album_artist_pid=%lld,album_artist_order=%lld,album_artist_order_section=%ld,genre_id=%lld,genre_order=%lld,genre_order_section=%ld WHERE item_pid=%lld",to,(long)ts,ap,aro,(long)ars,alp,alo,(long)als,aa,aao,(long)aas,gp,go,(long)gs,itemPID];ok&=BTExec(db,q,&e);}if(ok){sqlite3_stmt*u=NULL;if(sqlite3_prepare_v2(db,"UPDATE item_extra SET title=?,sort_title=?,year=?,date_modified=? WHERE item_pid=?",-1,&u,NULL)==SQLITE_OK){sqlite3_bind_text(u,1,title.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(u,2,title.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int(u,3,(int)year);sqlite3_bind_int64(u,4,(int64_t)NSDate.date.timeIntervalSince1970);sqlite3_bind_int64(u,5,itemPID);ok=sqlite3_step(u)==SQLITE_DONE;}else ok=NO;if(!ok)e=[NSString stringWithUTF8String:sqlite3_errmsg(db)];sqlite3_finalize(u);}ok?BTExec(db,@"COMMIT",&e):BTExec(db,@"ROLLBACK",NULL);sqlite3_close(db);return ok?BTOK(@{ @"itemPID":@(itemPID),@"title":title,@"artist":artist,@"album":album,@"genre":genre,@"year":@(year),@"restartMusic":@YES }):BTFail(e);
}

+ (NSDictionary *)deleteItemPID:(int64_t)itemPID {
    NSString*e=nil;sqlite3*db=BTOpen(YES,&e);if(!db)return BTFail(e);if(!BTBackup(db,&e)){sqlite3_close(db);return BTFail(e);}sqlite3_stmt*s=NULL;NSString*location=@"";int base=0;if(sqlite3_prepare_v2(db,"SELECT x.location,i.base_location_id FROM item i JOIN item_extra x ON x.item_pid=i.item_pid WHERE i.item_pid=?",-1,&s,NULL)==SQLITE_OK){sqlite3_bind_int64(s,1,itemPID);if(sqlite3_step(s)==SQLITE_ROW){location=BTText(s,0);base=sqlite3_column_int(s,1);}}sqlite3_finalize(s);if(!location.length){sqlite3_close(db);return BTFail(@"Song not found");}if(!BTExec(db,@"BEGIN IMMEDIATE",&e)){sqlite3_close(db);return BTFail(e);}NSArray*tables=@[@"container_item",@"item_search",@"item_stats",@"item_store",@"item_video",@"lyrics",@"chapter",@"item_playback",@"item_extra",@"item"];BOOL ok=YES;for(NSString*t in tables)if(BTTable(db,t)){NSString*col=[t isEqual:@"container_item"]?@"item_pid":@"item_pid";ok&=BTExec(db,[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=%lld",t,col,itemPID],&e);if(!ok)break;}ok?BTExec(db,@"COMMIT",&e):BTExec(db,@"ROLLBACK",NULL);sqlite3_close(db);return ok?BTOK(@{ @"itemPID":@(itemPID),@"location":location,@"baseLocation":@(base),@"filePreserved":@YES,@"restartMusic":@YES }):BTFail(e);
}

+ (NSDictionary *)repairLibrary {
    NSString*e=nil;sqlite3*db=BTOpen(YES,&e);if(!db)return BTFail(e);NSString*before=BTQuickCheck(db);if(![before isEqual:@"ok"]){sqlite3_close(db);return BTFail([NSString stringWithFormat:@"quick_check failed before repair: %@. Restore a backup instead.",before]);}if(!BTBackup(db,&e)){sqlite3_close(db);return BTFail(e);}BTExec(db,@"PRAGMA wal_checkpoint(TRUNCATE)",NULL);BTExec(db,@"BEGIN IMMEDIATE",&e);BOOL ok=YES;ok&=BTExec(db,@"INSERT OR IGNORE INTO base_location(base_location_id,path) VALUES(3840,'iTunes_Control/Music/F00')",&e);ok&=BTExec(db,@"UPDATE album SET sync_id=abs(random()),keep_local=1 WHERE sync_id=0",&e);ok&=BTExec(db,@"UPDATE album_artist SET sync_id=abs(random()),keep_local=1 WHERE sync_id=0",&e);ok&=BTExec(db,@"UPDATE item_artist SET sync_id=abs(random()),keep_local=1 WHERE sync_id=0",&e);if(ok)ok&=BTExec(db,@"DELETE FROM container_item WHERE item_pid NOT IN (SELECT item_pid FROM item)",&e);ok?BTExec(db,@"COMMIT",&e):BTExec(db,@"ROLLBACK",NULL);NSString*after=BTQuickCheck(db);sqlite3_close(db);return(ok&&[after isEqual:@"ok"])?BTOK(@{ @"before":before,@"after":after,@"restartMusic":@YES }):BTFail(e?:after);
}

@end

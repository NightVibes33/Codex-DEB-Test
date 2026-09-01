from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        print(f"{path}: already patched")
        return
    if old not in text:
        raise SystemExit(f"{path}: expected source pattern not found")
    p.write_text(text.replace(old, new, 1))
    print(f"{path}: patched")


replace_once(
    "byetunes16/daemon/BTImporter.m",
    'sqlite3_finalize(s);NSInteger pos=0;for(NSNumber*n in pids){if(sqlite3_prepare_v2(db,"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)",-1,&s,NULL)!=SQLITE_OK)goto fail;NSString*u=NSUUID.UUID.UUIDString;sqlite3_bind_int64(s,1,BTPID());sqlite3_bind_int64(s,2,pid);sqlite3_bind_int64(s,3,n.longLongValue);sqlite3_bind_int64(s,4,pos++);sqlite3_bind_text(s,5,u.UTF8String,-1,SQLITE_TRANSIENT);if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);}',
    'sqlite3_finalize(s);BOOL hasUUID=BTColumn(db,@"container_item",@"uuid");NSInteger pos=0;for(NSNumber*n in pids){const char*sql=hasUUID?"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)":"INSERT INTO container_item(container_item_pid,container_pid,item_pid,position) VALUES(?,?,?,?)";if(sqlite3_prepare_v2(db,sql,-1,&s,NULL)!=SQLITE_OK)goto fail;sqlite3_bind_int64(s,1,BTPID());sqlite3_bind_int64(s,2,pid);sqlite3_bind_int64(s,3,n.longLongValue);sqlite3_bind_int64(s,4,pos++);if(hasUUID){NSString*u=NSUUID.UUID.UUIDString;sqlite3_bind_text(s,5,u.UTF8String,-1,SQLITE_TRANSIENT);}if(sqlite3_step(s)!=SQLITE_DONE)goto fail;sqlite3_finalize(s);}'
)

replace_once(
    "byetunes16/daemon/BTImporter+Full.m",
    '''        if (sqlite3_prepare_v2(db, "INSERT INTO container_item(container_item_pid,container_pid,item_pid,position,uuid) VALUES(?,?,?,?,?)", -1, &stmt, NULL) != SQLITE_OK) {
            ok = NO;
            error = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
            break;
        }
        NSString *uuid = NSUUID.UUID.UUIDString;
        sqlite3_bind_int64(stmt, 1, BTFullPID());
        sqlite3_bind_int64(stmt, 2, playlistPID);
        sqlite3_bind_int64(stmt, 3, itemPID);
        sqlite3_bind_int64(stmt, 4, position++);
        sqlite3_bind_text(stmt, 5, uuid.UTF8String, -1, SQLITE_TRANSIENT);''',
    '''        BOOL hasUUID = BTFullColumn(db, @"container_item", @"uuid");
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
)

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BTImporter : NSObject
+ (NSDictionary *)probe;
+ (NSDictionary *)importFileAtPath:(NSString *)path
                        sourceName:(NSString * _Nullable)sourceName
                          metadata:(NSDictionary * _Nullable)metadata
                      playlistName:(NSString * _Nullable)playlistName;
+ (NSDictionary *)libraryWithLimit:(NSUInteger)limit;
+ (NSDictionary *)playlists;
+ (NSDictionary *)createPlaylistNamed:(NSString *)name itemPIDs:(NSArray<NSNumber *> *)itemPIDs;
+ (NSDictionary *)updateMetadataForItemPID:(int64_t)itemPID metadata:(NSDictionary *)metadata;
+ (NSDictionary *)deleteItemPID:(int64_t)itemPID;
+ (NSDictionary *)createBackup;
+ (NSDictionary *)restoreLatestBackup;
+ (NSDictionary *)repairLibrary;
@end

NS_ASSUME_NONNULL_END

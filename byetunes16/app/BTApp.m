#import <UIKit/UIKit.h>
#import "../BTClient.h"

static NSString *BTString(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return @"";
}

static void BTOpenMusic(void) {
    NSURL *url = [NSURL URLWithString:@"music://"];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@interface BTBaseTableController : UITableViewController
- (void)send:(NSDictionary *)request completion:(void (^)(NSDictionary *response))completion;
- (void)message:(NSString *)title body:(NSString *)body;
- (BOOL)responseOK:(NSDictionary *)response;
@end

@implementation BTBaseTableController
- (void)send:(NSDictionary *)request completion:(void (^)(NSDictionary *response))completion {
    [[BTClient sharedClient] sendRequest:request completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            [self message:@"ByeTunes Helper" body:error.localizedDescription ?: @"The ByeTunes helper is not reachable."];
            if (completion) completion(@{});
            return;
        }
        if (completion) completion(response ?: @{});
    }];
}
- (void)message:(NSString *)title body:(NSString *)body {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:body preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (BOOL)responseOK:(NSDictionary *)response {
    if ([response[@"ok"] boolValue]) return YES;
    [self message:@"ByeTunes" body:BTString(response[@"error"]).length ? BTString(response[@"error"]) : @"The operation failed."];
    return NO;
}
@end

@interface BTDashboardController : BTBaseTableController
@property(nonatomic,strong) NSDictionary *probe;
@end

@implementation BTDashboardController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"ByeTunes";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshProbe)];
    [self refreshProbe];
}
- (void)refreshProbe {
    [self send:@{ @"op": @"probe" } completion:^(NSDictionary *response) {
        self.probe = response;
        [self.tableView reloadData];
    }];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section == 0 ? 5 : (section == 1 ? 2 : 1); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { (void)tableView; return section == 0 ? @"System" : (section == 1 ? @"Quick Actions" : @"About"); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.section == 0) {
        NSArray *names = @[ @"Helper", @"MediaLibrary", @"Integrity", @"Schema", @"System" ];
        cell.textLabel.text = names[indexPath.row];
        switch (indexPath.row) {
            case 0: cell.detailTextLabel.text = [self.probe[@"ok"] boolValue] ? @"Online" : @"Offline"; break;
            case 1: cell.detailTextLabel.text = [self.probe[@"dbExists"] boolValue] ? @"Found" : @"Missing"; break;
            case 2: cell.detailTextLabel.text = BTString(self.probe[@"quickCheck"]); break;
            case 3: cell.detailTextLabel.text = [self.probe[@"schemaOK"] boolValue] ? @"Compatible" : @"Mismatch"; break;
            default: cell.detailTextLabel.text = BTString(self.probe[@"os"]); break;
        }
    } else if (indexPath.section == 1) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = indexPath.row == 0 ? @"Open Apple Music" : @"Refresh ByeTunes Status";
    } else {
        cell.textLabel.text = @"ByeTunes 0.3.0";
        cell.detailTextLabel.text = @"App + tweak + helper";
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) return;
    if (indexPath.row == 0) BTOpenMusic(); else [self refreshProbe];
}
@end

@interface BTLibraryController : BTBaseTableController <UIDocumentPickerDelegate>
@property(nonatomic,strong) NSArray<NSDictionary *> *songs;
@end

@implementation BTLibraryController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Library";
    self.songs = @[];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(importAudio)];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reloadLibrary) forControlEvents:UIControlEventValueChanged];
    [self reloadLibrary];
}
- (void)reloadLibrary {
    [self send:@{ @"op": @"library", @"limit": @500 } completion:^(NSDictionary *response) {
        [self.refreshControl endRefreshing];
        if (![self responseOK:response]) return;
        NSArray *rows = [response[@"songs"] isKindOfClass:NSArray.class] ? response[@"songs"] : @[];
        self.songs = rows;
        [self.tableView reloadData];
    }];
}
- (void)importAudio {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.audio"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSDictionary *req = @{ @"op": @"import", @"path": url.path ?: @"", @"sourceName": url.lastPathComponent ?: @"Imported Audio", @"metadata": @{} };
    [self send:req completion:^(NSDictionary *response) {
        if (![self responseOK:response]) return;
        NSString *title = BTString(response[@"title"]);
        [self message:@"Imported" body:title.length ? [NSString stringWithFormat:@"%@ was added to the native Music library.", title] : @"Audio was added to the native Music library."];
        [self reloadLibrary];
    }];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.songs.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"song"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"song"];
    NSDictionary *song = self.songs[indexPath.row];
    cell.textLabel.text = BTString(song[@"title"]).length ? BTString(song[@"title"]) : @"Untitled";
    NSString *artist = BTString(song[@"artist"]); NSString *album = BTString(song[@"album"]);
    cell.detailTextLabel.text = album.length ? [NSString stringWithFormat:@"%@ • %@", artist.length ? artist : @"Unknown Artist", album] : (artist.length ? artist : @"Unknown Artist");
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *song = self.songs[indexPath.row];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:BTString(song[@"title"]) message:BTString(song[@"artist"]) preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Edit Metadata" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){ [self editSong:song]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Search Metadata" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){ [self searchMetadataForSong:song]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Add to Playlist" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){ [self addSongToPlaylist:song]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Delete Library Record" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a){ [self confirmDeleteSong:song]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = tableView;
    sheet.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)editSong:(NSDictionary *)song {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Edit Metadata" message:@"Changes are written to the native Music library." preferredStyle:UIAlertControllerStyleAlert];
    NSArray *keys = @[ @"title", @"artist", @"album", @"genre", @"year" ];
    NSArray *labels = @[ @"Title", @"Artist", @"Album", @"Genre", @"Year" ];
    for (NSUInteger i=0;i<keys.count;i++) {
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.placeholder = labels[i]; f.text = BTString(song[keys[i]]); if (i==4) f.keyboardType=UIKeyboardTypeNumberPad; }];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){
        NSMutableDictionary *m=[NSMutableDictionary dictionary];
        for(NSUInteger i=0;i<keys.count;i++) if(a.textFields[i].text.length) m[keys[i]]=a.textFields[i].text;
        [self send:@{ @"op":@"updateMetadata", @"itemPID":song[@"itemPID"] ?: @0, @"metadata":m } completion:^(NSDictionary *r){ if([self responseOK:r]) { [self reloadLibrary]; BTOpenMusic(); } }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)searchMetadataForSong:(NSDictionary *)song {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Metadata Search" message:@"Search Apple/iTunes and Deezer metadata." preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.text=[NSString stringWithFormat:@"%@ %@",BTString(song[@"title"]),BTString(song[@"artist"])]; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Search" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){
        NSString *q=a.textFields.firstObject.text ?: @"";
        [self send:@{ @"op":@"searchMetadata", @"query":q } completion:^(NSDictionary *r){ if(![self responseOK:r]) return; [self presentCandidates:r[@"results"] song:song]; }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)presentCandidates:(id)value song:(NSDictionary *)song {
    NSArray *results=[value isKindOfClass:NSArray.class]?value:@[];
    if(!results.count){ [self message:@"Metadata Search" body:@"No matches were found."]; return; }
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Choose Metadata" message:@"Applying a result can update artwork too." preferredStyle:UIAlertControllerStyleActionSheet];
    NSUInteger count=MIN((NSUInteger)8,results.count);
    for(NSUInteger i=0;i<count;i++){
        NSDictionary *c=results[i]; NSString *label=[NSString stringWithFormat:@"%@ — %@",BTString(c[@"title"]),BTString(c[@"artist"])];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){
            [self send:@{ @"op":@"applyMetadataCandidate", @"itemPID":song[@"itemPID"] ?: @0, @"candidate":c } completion:^(NSDictionary *r){ if([self responseOK:r]) { [self reloadLibrary]; BTOpenMusic(); } }];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=self.view; sheet.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height-1,1,1);
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)addSongToPlaylist:(NSDictionary *)song {
    [self send:@{ @"op":@"playlists" } completion:^(NSDictionary *r){
        if(![self responseOK:r]) return; NSArray *rows=[r[@"playlists"] isKindOfClass:NSArray.class]?r[@"playlists"]:@[];
        if(!rows.count){ [self message:@"Playlists" body:@"Create a playlist first from the Playlists tab."]; return; }
        UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Add to Playlist" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for(NSDictionary *p in rows){ [sheet addAction:[UIAlertAction actionWithTitle:BTString(p[@"name"]) style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){
            [self send:@{ @"op":@"addToPlaylist", @"playlistPID":p[@"containerPID"] ?: @0, @"itemPIDs":@[song[@"itemPID"] ?: @0] } completion:^(NSDictionary *rr){ if([self responseOK:rr]) BTOpenMusic(); }];
        }]]; }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        sheet.popoverPresentationController.sourceView=self.view; sheet.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,self.view.bounds.size.height-1,1,1);
        [self presentViewController:sheet animated:YES completion:nil];
    }];
}
- (void)confirmDeleteSong:(NSDictionary *)song {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Delete Library Record?" message:@"The database record will be removed. ByeTunes preserves the underlying audio file for recovery." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x){
        [self send:@{ @"op":@"delete", @"itemPID":song[@"itemPID"] ?: @0 } completion:^(NSDictionary *r){ if([self responseOK:r]) { [self reloadLibrary]; BTOpenMusic(); } }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

@interface BTPlaylistsController : BTBaseTableController
@property(nonatomic,strong) NSArray<NSDictionary *> *playlists;
@end

@implementation BTPlaylistsController
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Playlists"; self.playlists=@[]; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createPlaylist)]; self.refreshControl=[UIRefreshControl new]; [self.refreshControl addTarget:self action:@selector(reloadPlaylists) forControlEvents:UIControlEventValueChanged]; [self reloadPlaylists]; }
- (void)reloadPlaylists { [self send:@{ @"op":@"playlists" } completion:^(NSDictionary *r){ [self.refreshControl endRefreshing]; if(![self responseOK:r])return; self.playlists=[r[@"playlists"] isKindOfClass:NSArray.class]?r[@"playlists"]:@[]; [self.tableView reloadData]; }]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;(void)section;return self.playlists.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { UITableViewCell *c=[tableView dequeueReusableCellWithIdentifier:@"p"]; if(!c)c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"p"]; NSDictionary *p=self.playlists[indexPath.row]; c.textLabel.text=BTString(p[@"name"]); c.detailTextLabel.text=[NSString stringWithFormat:@"%@ songs",BTString(p[@"count"])]; return c; }
- (void)createPlaylist { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"New Playlist" message:nil preferredStyle:UIAlertControllerStyleAlert]; [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.placeholder=@"Playlist name"; }]; [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]]; [a addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){ NSString *name=a.textFields.firstObject.text ?: @""; if(!name.length)return; [self send:@{ @"op":@"createPlaylist",@"name":name,@"itemPIDs":@[] } completion:^(NSDictionary *r){ if([self responseOK:r]) { [self reloadPlaylists]; BTOpenMusic(); } }]; }]]; [self presentViewController:a animated:YES completion:nil]; }
@end

@interface BTToolsController : BTBaseTableController
@end

@implementation BTToolsController
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Tools"; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;(void)section;return 5; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; NSArray *t=@[@"Backup Media Library",@"Restore Latest Backup",@"Repair Library",@"Open Apple Music",@"Probe Helper"]; NSArray *d=@[@"Create a protected SQLite snapshot",@"Restore the newest ByeTunes snapshot",@"Repair sync IDs and orphaned playlist rows",@"Reload the native Music UI",@"Check daemon and database integrity"]; c.textLabel.text=t[indexPath.row]; c.detailTextLabel.text=d[indexPath.row]; c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; return c; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath { [tableView deselectRowAtIndexPath:indexPath animated:YES]; if(indexPath.row==0){ [self send:@{ @"op":@"backup" } completion:^(NSDictionary *r){ if([self responseOK:r]) [self message:@"Backup Complete" body:BTString(r[@"backup"])]; }]; return; } if(indexPath.row==1){ [self confirmRestore]; return; } if(indexPath.row==2){ [self send:@{ @"op":@"repair" } completion:^(NSDictionary *r){ if([self responseOK:r]) { [self message:@"Repair Complete" body:@"The Music library passed ByeTunes repair checks."]; BTOpenMusic(); } }]; return; } if(indexPath.row==3){ BTOpenMusic(); return; } [self send:@{ @"op":@"probe" } completion:^(NSDictionary *r){ if(![self responseOK:r])return; NSString *m=[NSString stringWithFormat:@"Integrity: %@\nSchema: %@\nOS: %@",BTString(r[@"quickCheck"]),[r[@"schemaOK"] boolValue]?@"compatible":@"mismatch",BTString(r[@"os"])]; [self message:@"ByeTunes Helper" body:m]; }]; }
- (void)confirmRestore { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Restore Latest Backup?" message:@"Apple Music will be reopened afterward so its SQLite WAL state is initialized safely." preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]]; [a addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x){ [self send:@{ @"op":@"restore" } completion:^(NSDictionary *r){ if(![self responseOK:r])return; BTOpenMusic(); dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self message:@"Restore Complete" body:@"The latest ByeTunes backup was restored and Music was reopened."]; }); }]; }]]; [self presentViewController:a animated:YES completion:nil]; }
@end

@interface BTAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation BTAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UITabBarController *tabs=[UITabBarController new];
    NSArray *controllers=@[[BTDashboardController new],[BTLibraryController new],[BTPlaylistsController new],[BTToolsController new]];
    NSArray *titles=@[@"Home",@"Library",@"Playlists",@"Tools"];
    NSArray *symbols=@[@"music.note.house",@"music.note.list",@"music.note.list",@"wrench.and.screwdriver"];
    NSMutableArray *navs=[NSMutableArray array];
    for(NSUInteger i=0;i<controllers.count;i++){
        UIViewController *vc=controllers[i];
        UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:vc];
        UIImage *image=nil; if(@available(iOS 13.0,*)) image=[UIImage systemImageNamed:symbols[i]];
        nav.tabBarItem=[[UITabBarItem alloc] initWithTitle:titles[i] image:image tag:(NSInteger)i];
        [navs addObject:nav];
    }
    tabs.viewControllers=navs;
    self.window.rootViewController=tabs;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(BTAppDelegate.class)); }
}

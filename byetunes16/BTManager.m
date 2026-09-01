#import "BTManager.h"
#import "BTClient.h"

@interface BTManagerViewController ()
@property(nonatomic,strong) NSArray<NSDictionary *> *songs;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@end

@implementation BTManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"ByeTunes16 Library";
    self.songs = @[];
    self.tableView.rowHeight = 62;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadLibrary)];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.tableView.backgroundView = self.spinner;
    [self reloadLibrary];
}

- (void)showError:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ByeTunes16" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)reloadLibrary {
    [self.spinner startAnimating];
    [[BTClient sharedClient] sendRequest:@{ @"op": @"library", @"limit": @500 } completion:^(NSDictionary *response, NSError *error) {
        [self.spinner stopAnimating];
        if (error || ![response[@"ok"] boolValue]) {
            [self showError:error.localizedDescription ?: response[@"error"] ?: @"Could not load the media library"];
            return;
        }
        self.songs = [response[@"songs"] isKindOfClass:NSArray.class] ? response[@"songs"] : @[];
        [self.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.songs.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"song";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary *song = self.songs[indexPath.row];
    cell.textLabel.text = song[@"title"] ?: @"Untitled";
    NSString *artist = song[@"artist"] ?: @"Unknown Artist";
    NSString *album = song[@"album"] ?: @"";
    cell.detailTextLabel.text = album.length ? [NSString stringWithFormat:@"%@ — %@", artist, album] : artist;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *song = self.songs[indexPath.row];
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:song[@"title"] ?: @"Song" message:[NSString stringWithFormat:@"%@\n%@", song[@"artist"] ?: @"", song[@"album"] ?: @""] preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Edit Metadata" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [self editSong:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Create Playlist With Song" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [self createPlaylistWithSong:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Remove From Library" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) { [self deleteSong:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (menu.popoverPresentationController) { menu.popoverPresentationController.sourceView = self.view; menu.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath]; }
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)editSong:(NSDictionary *)song {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Edit Metadata" message:@"Changes are written directly to the iOS media library. A backup is created first." preferredStyle:UIAlertControllerStyleAlert];
    NSArray *keys = @[ @"title", @"artist", @"album", @"genre", @"year" ];
    NSArray *labels = @[ @"Title", @"Artist", @"Album", @"Genre", @"Year" ];
    for (NSUInteger i = 0; i < keys.count; i++) {
        [a addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = labels[i];
            id value = song[keys[i]];
            field.text = [value isKindOfClass:NSString.class] ? value : [value description];
            if ([keys[i] isEqualToString:@"year"]) field.keyboardType = UIKeyboardTypeNumberPad;
        }];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < keys.count; i++) if (a.textFields[i].text.length) metadata[keys[i]] = a.textFields[i].text;
        [[BTClient sharedClient] sendRequest:@{ @"op": @"updateMetadata", @"itemPID": song[@"itemPID"] ?: @0, @"metadata": metadata } completion:^(NSDictionary *response, NSError *error) {
            if (error || ![response[@"ok"] boolValue]) { [self showError:error.localizedDescription ?: response[@"error"] ?: @"Metadata update failed"]; return; }
            [self reloadLibrary];
        }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)createPlaylistWithSong:(NSDictionary *)song {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"New Playlist" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.placeholder = @"Playlist name"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = a.textFields.firstObject.text;
        if (!name.length) return;
        [[BTClient sharedClient] sendRequest:@{ @"op": @"createPlaylist", @"name": name, @"itemPIDs": @[ song[@"itemPID"] ?: @0 ] } completion:^(NSDictionary *response, NSError *error) {
            if (error || ![response[@"ok"] boolValue]) { [self showError:error.localizedDescription ?: response[@"error"] ?: @"Playlist creation failed"]; return; }
            UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Playlist Created" message:name preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:done animated:YES completion:nil];
        }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)deleteSong:(NSDictionary *)song {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Remove song?" message:@"The database record is removed after an automatic backup. The audio file is intentionally preserved for recovery." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[BTClient sharedClient] sendRequest:@{ @"op": @"delete", @"itemPID": song[@"itemPID"] ?: @0 } completion:^(NSDictionary *response, NSError *error) {
            if (error || ![response[@"ok"] boolValue]) { [self showError:error.localizedDescription ?: response[@"error"] ?: @"Delete failed"]; return; }
            [self reloadLibrary];
        }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end

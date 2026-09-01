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
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(bt_close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadLibrary)];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.tableView.backgroundView = self.spinner;
    [self reloadLibrary];
}

- (void)bt_close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)showError:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ByeTunes16" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)showMessage:(NSString *)title message:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
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
    [menu addAction:[UIAlertAction actionWithTitle:@"Auto Metadata Search" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [self autoMetadataForSong:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Edit Metadata" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [self editSong:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Add to Existing Playlist" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [self addSongToExistingPlaylist:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Create Playlist With Song" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [self createPlaylistWithSong:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Remove From Library" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) { [self deleteSong:song]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (menu.popoverPresentationController) { menu.popoverPresentationController.sourceView = self.view; menu.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath]; }
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)autoMetadataForSong:(NSDictionary *)song {
    NSString *query = [NSString stringWithFormat:@"%@ %@", song[@"artist"] ?: @"", song[@"title"] ?: @""];
    query = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!query.length) { [self showError:@"This song does not have enough metadata to search."]; return; }

    UIAlertController *searching = [UIAlertController alertControllerWithTitle:@"Searching Metadata" message:@"Checking Apple/iTunes and Deezer…" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:searching animated:YES completion:nil];

    [[BTClient sharedClient] sendRequest:@{ @"op": @"searchMetadata", @"query": query } completion:^(NSDictionary *response, NSError *error) {
        [searching dismissViewControllerAnimated:YES completion:^{
            if (error || ![response[@"ok"] boolValue]) {
                [self showError:error.localizedDescription ?: response[@"error"] ?: @"Metadata search failed"];
                return;
            }
            NSArray<NSDictionary *> *results = [response[@"results"] isKindOfClass:NSArray.class] ? response[@"results"] : @[];
            if (!results.count) {
                NSArray *providerErrors = [response[@"providerErrors"] isKindOfClass:NSArray.class] ? response[@"providerErrors"] : @[];
                [self showError:providerErrors.count ? [providerErrors componentsJoinedByString:@"\n"] : @"No metadata matches were found."];
                return;
            }

            UIAlertController *choices = [UIAlertController alertControllerWithTitle:@"Metadata Matches" message:@"Selecting a match updates the song after an automatic database backup." preferredStyle:UIAlertControllerStyleActionSheet];
            NSUInteger count = MIN(results.count, 12);
            for (NSUInteger i = 0; i < count; i++) {
                NSDictionary *candidate = results[i];
                NSString *title = candidate[@"title"] ?: @"Unknown";
                NSString *artist = candidate[@"artist"] ?: @"Unknown Artist";
                NSString *source = candidate[@"source"] ?: @"Metadata";
                NSString *label = [NSString stringWithFormat:@"%@ — %@ [%@]", title, artist, source];
                if (label.length > 90) label = [[label substringToIndex:87] stringByAppendingString:@"…"];
                [choices addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                    [self applyMetadataCandidate:candidate toSong:song];
                }]];
            }
            [choices addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            if (choices.popoverPresentationController) { choices.popoverPresentationController.sourceView = self.view; choices.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1); }
            [self presentViewController:choices animated:YES completion:nil];
        }];
    }];
}

- (void)applyMetadataCandidate:(NSDictionary *)candidate toSong:(NSDictionary *)song {
    [[BTClient sharedClient] sendRequest:@{ @"op": @"applyMetadataCandidate", @"itemPID": song[@"itemPID"] ?: @0, @"candidate": candidate } completion:^(NSDictionary *response, NSError *error) {
        if (error || ![response[@"ok"] boolValue]) {
            [self showError:error.localizedDescription ?: response[@"error"] ?: @"Could not apply metadata"];
            return;
        }
        NSString *source = response[@"metadataSource"] ?: candidate[@"source"] ?: @"metadata provider";
        [self showMessage:@"Metadata Updated" message:[NSString stringWithFormat:@"Applied %@ metadata. Reopen Music if the old text is cached.", source]];
        [self reloadLibrary];
    }];
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

- (void)addSongToExistingPlaylist:(NSDictionary *)song {
    [[BTClient sharedClient] sendRequest:@{ @"op": @"playlists" } completion:^(NSDictionary *response, NSError *error) {
        if (error || ![response[@"ok"] boolValue]) { [self showError:error.localizedDescription ?: response[@"error"] ?: @"Could not load playlists"]; return; }
        NSArray<NSDictionary *> *playlists = [response[@"playlists"] isKindOfClass:NSArray.class] ? response[@"playlists"] : @[];
        if (!playlists.count) { [self showError:@"There are no editable music playlists yet."]; return; }
        UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Add to Playlist" message:song[@"title"] ?: @"Song" preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSDictionary *playlist in playlists) {
            NSString *name = playlist[@"name"] ?: @"Untitled Playlist";
            NSNumber *pid = playlist[@"containerPID"] ?: @0;
            NSString *label = [NSString stringWithFormat:@"%@ (%@)", name, playlist[@"count"] ?: @0];
            [menu addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                [[BTClient sharedClient] sendRequest:@{ @"op": @"addToPlaylist", @"playlistPID": pid, @"itemPIDs": @[ song[@"itemPID"] ?: @0 ] } completion:^(NSDictionary *addResponse, NSError *addError) {
                    if (addError || ![addResponse[@"ok"] boolValue]) { [self showError:addError.localizedDescription ?: addResponse[@"error"] ?: @"Could not add song to playlist"]; return; }
                    [self showMessage:@"Added to Playlist" message:[NSString stringWithFormat:@"%@ → %@", song[@"title"] ?: @"Song", name]];
                }];
            }]];
        }
        [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        if (menu.popoverPresentationController) { menu.popoverPresentationController.sourceView = self.view; menu.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1); }
        [self presentViewController:menu animated:YES completion:nil];
    }];
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
            [self showMessage:@"Playlist Created" message:name];
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

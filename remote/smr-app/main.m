#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>
#import <errno.h>

static NSString *const SMRSocketPath = @"/var/mobile/Library/SafeModeRepair/rootd.sock";

static NSString *SMRRequest(NSString *command) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return [NSString stringWithFormat:@"ERROR: socket: %s", strerror(errno)];
    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, SMRSocketPath.UTF8String, sizeof(addr.sun_path));
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        NSString *err = [NSString stringWithFormat:@"ERROR: Repair service offline (%s). Reinstall the DEB or restart its launch daemon.", strerror(errno)];
        close(fd);
        return err;
    }
    NSData *request = [[command stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *bytes = request.bytes;
    size_t remaining = request.length;
    while (remaining) {
        ssize_t n = write(fd, bytes, remaining);
        if (n <= 0) { close(fd); return @"ERROR: Could not send command."; }
        bytes += n;
        remaining -= (size_t)n;
    }
    shutdown(fd, SHUT_WR);
    NSMutableData *reply = [NSMutableData data];
    char chunk[4096];
    ssize_t n;
    while ((n = read(fd, chunk, sizeof(chunk))) > 0) {
        if (reply.length + (NSUInteger)n > 512 * 1024) break;
        [reply appendBytes:chunk length:(NSUInteger)n];
    }
    close(fd);
    NSString *result = [[NSString alloc] initWithData:reply encoding:NSUTF8StringEncoding];
    return result ?: @"ERROR: Invalid reply from repair service.";
}

@interface SMRController : UITableViewController
@property(nonatomic,strong) NSArray<NSDictionary<NSString *,NSString *> *> *rows;
@property(nonatomic,strong) NSString *message;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,assign) BOOL disabledView;
@property(nonatomic,assign) BOOL busy;
@end

@implementation SMRController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _rows = @[];
        _message = @"Scan crash reports to inspect installed tweaks.";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Safe Mode Repair";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Disabled" style:UIBarButtonItemStylePlain target:self action:@selector(switchView)];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.navigationItem.titleView = nil;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.tableFooterView = [UIView new];
    [self refresh];
}

- (void)switchView {
    if (self.busy) return;
    self.disabledView = !self.disabledView;
    self.navigationItem.leftBarButtonItem.title = self.disabledView ? @"Suspects" : @"Disabled";
    [self refresh];
}

- (void)refresh {
    [self performCommand:self.disabledView ? @"DISABLED" : @"SCAN" completion:^(NSString *output) {
        [self parseList:output];
    }];
}

- (void)performCommand:(NSString *)command completion:(void (^)(NSString *))completion {
    if (self.busy) return;
    self.busy = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.navigationItem.leftBarButtonItem.enabled = NO;
    [self.spinner startAnimating];
    self.navigationItem.titleView = self.spinner;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *output = SMRRequest(command);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            self.navigationItem.titleView = nil;
            [self.spinner stopAnimating];
            self.navigationItem.rightBarButtonItem.enabled = YES;
            self.navigationItem.leftBarButtonItem.enabled = YES;
            if (completion) completion(output);
        });
    });
}

- (void)parseList:(NSString *)output {
    NSMutableArray *parsed = [NSMutableArray array];
    BOOL reading = NO;
    NSArray<NSString *> *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (self.disabledView) {
        for (NSString *line in lines) {
            if ([line hasPrefix:@"=== DISABLED BY THIS TOOL ==="]) { reading = YES; continue; }
            if (!reading || !line.length || [line hasPrefix:@"("] || [line hasPrefix:@"ERROR:"]) continue;
            [parsed addObject:@{@"name":line, @"score":@"-", @"package":@""}];
        }
        self.message = parsed.count ? @"Tap a tweak to re-enable it. Changes take effect after respring." : @"No tweaks disabled by Safe Mode Repair.";
    } else {
        for (NSString *line in lines) {
            if ([line hasPrefix:@"SCORE\tREPORTS\tTWEAK\tPACKAGE"]) { reading = YES; continue; }
            if (!reading) continue;
            NSArray<NSString *> *parts = [line componentsSeparatedByString:@"\t"];
            if (parts.count == 4 && [parts[0] length] && [parts[2] length]) {
                [parsed addObject:@{@"name":parts[2], @"score":parts[0], @"reports":parts[1], @"package":parts[3]}];
            }
        }
        self.message = [output containsString:@"Crash attribution unavailable"] || [output containsString:@"scanner failed"]
          ? @"Installed tweaks found. Crash attribution unavailable due to memory pressure; scores are not evidence."
          : @"Ranked using SpringBoard/backboardd crashing frames. Zero means no matching evidence, not that the tweak is safe.";
        if (!parsed.count && ![output hasPrefix:@"ERROR:"]) self.message = @"No installed tweaks found in the injection directory.";
    }
    if ([output containsString:@"ERROR:"]) self.message = output;
    self.rows = parsed;
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.rows.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.disabledView ? @"Re-enable disabled tweaks" : @"Installed tweaks • Crash evidence";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section; return self.message;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tweak"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tweak"];
    NSDictionary *item = self.rows[indexPath.row];
    cell.textLabel.text = item[@"name"];
    NSString *pkg = item[@"package"] ?: @"";
    if (self.disabledView) {
        cell.detailTextLabel.text = @"Disabled • Tap to restore";
    } else {
        NSInteger score = [item[@"score"] integerValue];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Crash score: %ld  •  %@", (long)score, pkg];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)showText:(NSString *)title details:(NSString *)details {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:details preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)executeAction:(NSString *)action name:(NSString *)name {
    [self performCommand:[NSString stringWithFormat:@"%@ %@", action, name] completion:^(NSString *output) {
        if ([output containsString:@"ERROR:"] || [output containsString:@"failed"] || [output containsString:@"Failure"]) {
            [self showText:@"Action failed" details:output];
        } else {
            [self showText:@"Done" details:[output stringByAppendingString:@"\n\nRespring when you are ready to apply changes."]];
        }
        [self refresh];
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.busy) return;
    NSDictionary *item = self.rows[indexPath.row];
    NSString *name = item[@"name"];
    if (self.disabledView) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Restore %@?",name]
            message:@"The saved dylib and filter will be restored without changing preferences."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Re-enable" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ (void)a; [self executeAction:@"ENABLE" name:name]; }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSString *msg = [NSString stringWithFormat:@"Crash score: %@\nPackage: %@\n\nDisabling is reversible. Uninstalling removes the entire Debian package.",item[@"score"],item[@"package"]];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:name message:msg preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Disable tweak" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a; [self executeAction:@"DISABLE" name:name];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Uninstall package…" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        (void)a;
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Confirm removal"
            message:[NSString stringWithFormat:@"Remove the Debian package containing %@? Dependencies are checked before removal. This cannot be undone by the Restore button.",name]
            preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Uninstall" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *b) {
            (void)b; [self executeAction:@"UNINSTALL" name:name];
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}
@end

@interface SMRAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation SMRAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[SMRController new]];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SMRAppDelegate class]));
    }
}

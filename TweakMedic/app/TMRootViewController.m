#import "TMRootViewController.h"
#import "TMClient.h"

static NSString *TMString(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return @"";
}

static void TMAlert(UIViewController *vc, NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:a animated:YES completion:nil];
    });
}

@protocol TMRefreshable <NSObject>
- (void)refreshData;
@end

@interface TMDashboardController : UITableViewController <TMRefreshable>
@property (nonatomic, strong) NSDictionary *status;
@property (nonatomic, strong) NSDictionary *ping;
@end

@implementation TMDashboardController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TweakMedic";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshData)];
    [self refreshData];
}
- (void)refreshData {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *e = nil;
        NSDictionary *p = [TMClient ping:&e];
        NSDictionary *s = [TMClient status:&e];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.ping = p ?: @{};
            self.status = s ?: @{};
            [self.tableView reloadData];
        });
    });
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section == 0 ? 4 : 2; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { (void)tableView; return section == 0 ? @"Live status" : @"Safety"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"dash"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"dash"];
    c.accessoryType = UITableViewCellAccessoryNone;
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.section == 0) {
        NSDictionary *current = [self.status[@"status"] isKindOfClass:NSDictionary.class] ? self.status[@"status"] : @{};
        NSArray *titles = @[@"Daemon", @"State", @"Target", @"Progress"];
        c.textLabel.text = titles[indexPath.row];
        if (indexPath.row == 0) c.detailTextLabel.text = [self.ping[@"ok"] boolValue] ? @"Online" : @"Offline";
        if (indexPath.row == 1) c.detailTextLabel.text = TMString(current[@"state"]).length ? TMString(current[@"state"]) : @"Idle";
        if (indexPath.row == 2) c.detailTextLabel.text = TMString(current[@"targetName"]).length ? TMString(current[@"targetName"]) : @"—";
        if (indexPath.row == 3) c.detailTextLabel.text = TMString(current[@"message"]).length ? TMString(current[@"message"]) : @"Ready";
    } else {
        c.textLabel.text = indexPath.row == 0 ? @"Automatic staging recovery" : @"Last culprit";
        if (indexPath.row == 0) c.detailTextLabel.text = @"Enabled";
        else {
            NSDictionary *r = [self.status[@"latestReport"] isKindOfClass:NSDictionary.class] ? self.status[@"latestReport"] : @{};
            c.detailTextLabel.text = TMString(r[@"culprit"]).length ? TMString(r[@"culprit"]) : @"None";
        }
    }
    return c;
}
@end

@interface TMAppsController : UITableViewController <UISearchResultsUpdating, TMRefreshable>
@property (nonatomic, strong) NSArray<NSDictionary *> *apps;
@property (nonatomic, strong) NSArray<NSDictionary *> *filtered;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation TMAppsController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Scan";
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshData)];
    [self refreshData];
}
- (void)refreshData {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *e = nil;
        NSDictionary *r = [TMClient snapshot:&e];
        NSArray *apps = [r[@"apps"] isKindOfClass:NSArray.class] ? r[@"apps"] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.apps = apps;
            self.filtered = apps;
            [self.tableView reloadData];
        });
    });
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *q = searchController.searchBar.text.lowercaseString ?: @"";
    if (q.length == 0) self.filtered = self.apps ?: @[];
    else self.filtered = [self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *app, NSDictionary *bindings) {
        (void)bindings;
        return [TMString(app[@"name"]).lowercaseString containsString:q] || [TMString(app[@"bundleID"]).lowercaseString containsString:q];
    }]];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.filtered.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"app"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"app"];
    NSDictionary *app = self.filtered[indexPath.row];
    c.textLabel.text = TMString(app[@"name"]);
    c.detailTextLabel.text = TMString(app[@"bundleID"]);
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *app = self.filtered[indexPath.row];
    NSString *name = TMString(app[@"name"]);
    NSString *bid = TMString(app[@"bundleID"]);
    NSInteger timeout = [[NSUserDefaults standardUserDefaults] integerForKey:@"defaultTimeout"];
    if (timeout < 8) timeout = 22;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:name message:[NSString stringWithFormat:@"TweakMedic will repeatedly relaunch this app and binary-search eligible tweak injections. Default survival window: %ld seconds.", (long)timeout] preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Start Automatic Scan" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *e = nil;
            NSDictionary *r = [TMClient startScanForBundleID:bid timeout:timeout error:&e];
            if (![r[@"ok"] boolValue]) TMAlert(self, @"Scan not started", e.localizedDescription ?: TMString(r[@"error"]));
            else TMAlert(self, @"Scan started", @"The daemon owns the scan now. TweakMedic will reopen automatically when the report is finished.");
        });
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:a animated:YES completion:nil];
}
@end

@interface TMHistoryController : UITableViewController <TMRefreshable>
@property (nonatomic, strong) NSArray<NSDictionary *> *reports;
@end

@implementation TMHistoryController
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"History"; [self refreshData]; }
- (void)refreshData {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *e = nil; NSDictionary *r = [TMClient reports:&e];
        NSArray *reports = [r[@"reports"] isKindOfClass:NSArray.class] ? r[@"reports"] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{ self.reports = reports; [self.tableView reloadData]; });
    });
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.reports.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"report"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"report"];
    NSDictionary *r = self.reports[indexPath.row];
    c.textLabel.text = TMString(r[@"targetName"]);
    NSString *culprit = TMString(r[@"culprit"]);
    c.detailTextLabel.text = culprit.length ? [NSString stringWithFormat:@"Culprit: %@ • %@", culprit, TMString(r[@"confidence"])] : TMString(r[@"result"]);
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *r = self.reports[indexPath.row];
    NSString *culprit = TMString(r[@"culprit"]);
    NSString *package = TMString(r[@"package"]);
    NSString *message = [NSString stringWithFormat:@"Result: %@\nCulprit: %@\nPackage: %@\nConfidence: %@\nCandidates: %@", TMString(r[@"result"]), culprit.length ? culprit : @"None", package.length ? package : @"Unknown", TMString(r[@"confidence"]), TMString(r[@"candidateCount"])];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:TMString(r[@"targetName"]) message:message preferredStyle:UIAlertControllerStyleActionSheet];
    if (culprit.length) {
        [a addAction:[UIAlertAction actionWithTitle:@"Disable culprit globally" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ NSError *e = nil; NSDictionary *x = [TMClient setTweak:culprit disabled:YES error:&e]; TMAlert(self, [x[@"ok"] boolValue] ? @"Disabled" : @"Failed", [x[@"ok"] boolValue] ? @"The tweak filter is stored safely in TweakMedic Disabled." : (e.localizedDescription ?: TMString(x[@"error"]))); });
        }]];
    }
    if (package.length) {
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Uninstall %@", package] style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Confirm uninstall" message:[NSString stringWithFormat:@"Remove %@ with dpkg?", package] preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Uninstall" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action2) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ NSError *e = nil; NSDictionary *x = [TMClient uninstallPackage:package error:&e]; TMAlert(self, [x[@"ok"] boolValue] ? @"Removed" : @"Failed", [x[@"ok"] boolValue] ? @"Package removed." : (e.localizedDescription ?: TMString(x[@"error"]))); });
            }]];
            [self presentViewController:confirm animated:YES completion:nil];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:a animated:YES completion:nil];
}
@end

@interface TMSettingsController : UITableViewController <TMRefreshable>
@property (nonatomic, strong) UIStepper *stepper;
@property (nonatomic, strong) UISwitch *broadSwitch;
@end

@implementation TMSettingsController
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"Settings"; }
- (void)refreshData { [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; if (section == 0) return 2; if (section == 1) return 2; return 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { (void)tableView; return @[@"Scan engine", @"Recovery", @"About"][section]; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"settings"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"settings"];
    c.accessoryView = nil; c.accessoryType = UITableViewCellAccessoryNone; c.selectionStyle = UITableViewCellSelectionStyleDefault;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSInteger timeout = [d integerForKey:@"defaultTimeout"]; if (timeout < 8) timeout = 22;
    if (indexPath.section == 0 && indexPath.row == 0) {
        c.textLabel.text = @"Survival window"; c.detailTextLabel.text = [NSString stringWithFormat:@"%lds", (long)timeout];
        self.stepper = [[UIStepper alloc] init]; self.stepper.minimumValue = 8; self.stepper.maximumValue = 120; self.stepper.stepValue = 1; self.stepper.value = timeout;
        [self.stepper addTarget:self action:@selector(timeoutChanged:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = self.stepper; c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 0) {
        c.textLabel.text = @"Include UIKit-wide tweaks"; c.detailTextLabel.text = @"";
        self.broadSwitch = [[UISwitch alloc] init]; BOOL seen = [d objectForKey:@"broadUIKit"] != nil; self.broadSwitch.on = seen ? [d boolForKey:@"broadUIKit"] : YES;
        [self.broadSwitch addTarget:self action:@selector(broadChanged:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = self.broadSwitch; c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        c.textLabel.text = @"Restore interrupted staging"; c.detailTextLabel.text = @"Run now"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
        c.textLabel.text = @"Open iOS Settings pane"; c.detailTextLabel.text = @""; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        c.textLabel.text = @"TweakMedic"; c.detailTextLabel.text = @"1.0.0"; c.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return c;
}
- (void)timeoutChanged:(UIStepper *)sender { [NSUserDefaults.standardUserDefaults setInteger:(NSInteger)sender.value forKey:@"defaultTimeout"]; [self.tableView reloadData]; }
- (void)broadChanged:(UISwitch *)sender { [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:@"broadUIKit"]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == 0) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ NSError *e = nil; NSDictionary *r = [TMClient restoreStaging:&e]; TMAlert(self, [r[@"ok"] boolValue] ? @"Recovered" : @"Failed", [r[@"ok"] boolValue] ? @"Any interrupted temporary filter moves were restored." : (e.localizedDescription ?: TMString(r[@"error"]))); });
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        NSURL *u = [NSURL URLWithString:@"App-Prefs:root=TweakMedic"];
        if ([UIApplication.sharedApplication canOpenURL:u]) [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil];
    }
}
@end

@implementation TMRootViewController
- (instancetype)init {
    self = [super init];
    if (self) {
        TMDashboardController *d = [[TMDashboardController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        TMAppsController *s = [[TMAppsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        TMHistoryController *h = [[TMHistoryController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        TMSettingsController *p = [[TMSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        UINavigationController *dn = [[UINavigationController alloc] initWithRootViewController:d];
        UINavigationController *sn = [[UINavigationController alloc] initWithRootViewController:s];
        UINavigationController *hn = [[UINavigationController alloc] initWithRootViewController:h];
        UINavigationController *pn = [[UINavigationController alloc] initWithRootViewController:p];
        dn.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Home" image:[UIImage systemImageNamed:@"cross.case.fill"] tag:0];
        sn.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Scan" image:[UIImage systemImageNamed:@"waveform.path.ecg"] tag:1];
        hn.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"History" image:[UIImage systemImageNamed:@"clock.arrow.circlepath"] tag:2];
        pn.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings" image:[UIImage systemImageNamed:@"gearshape.fill"] tag:3];
        self.viewControllers = @[dn, sn, hn, pn];
    }
    return self;
}
- (void)refreshVisibleTab {
    UINavigationController *nav = [self.selectedViewController isKindOfClass:UINavigationController.class] ? (UINavigationController *)self.selectedViewController : nil;
    UIViewController *vc = nav.topViewController;
    if ([vc conformsToProtocol:@protocol(TMRefreshable)]) [(id<TMRefreshable>)vc refreshData];
}
@end

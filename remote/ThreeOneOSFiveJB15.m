#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSString *RunShell(NSString *command) {
    NSArray<NSString *> *shells = @[@"/var/jb/usr/bin/bash", @"/var/jb/bin/bash", @"/var/jb/bin/sh", @"/bin/sh"];
    NSString *shell = nil;
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *candidate in shells) {
        if ([fm isExecutableFileAtPath:candidate]) { shell = candidate; break; }
    }
    if (!shell) return @"No jailbreak shell found.";

    int pipefd[2];
    if (pipe(pipefd) != 0) return @"pipe() failed.";

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);

    const char *argv[] = { shell.UTF8String, "-lc", command.UTF8String, NULL };
    pid_t pid = 0;
    int rc = posix_spawn(&pid, shell.UTF8String, &actions, NULL, (char * const *)argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);
    if (rc != 0) { close(pipefd[0]); return [NSString stringWithFormat:@"spawn failed: %d", rc]; }

    NSMutableData *data = [NSMutableData data];
    uint8_t buffer[4096];
    ssize_t n;
    while ((n = read(pipefd[0], buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:(NSUInteger)n];
    close(pipefd[0]);
    int status = 0;
    waitpid(pid, &status, 0);
    NSString *out = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (out.length == 0) out = [NSString stringWithFormat:@"Command finished (status %d).", status];
    return out;
}

@interface ThreeOneOSFiveJB15ViewController : UIViewController
@property(nonatomic,strong) UITextField *pathField;
@property(nonatomic,strong) UITextView *outputView;
@end

@implementation ThreeOneOSFiveJB15ViewController

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *l = [UILabel new];
    l.text = text;
    l.textColor = UIColor.labelColor;
    l.numberOfLines = 0;
    l.font = [UIFont systemFontOfSize:size weight:weight];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    b.backgroundColor = UIColor.secondarySystemBackgroundColor;
    b.layer.cornerRadius = 12;
    b.contentEdgeInsets = UIEdgeInsetsMake(12, 14, 12, 14);
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"3105";

    UILabel *title = [self label:@"3105 — Dopamine iOS 15" size:28 weight:UIFontWeightBold];
    UILabel *subtitle = [self label:@"UIKit compatibility mode is active. The window is attached to the SpringBoard user session." size:14 weight:UIFontWeightRegular];
    subtitle.textColor = UIColor.secondaryLabelColor;

    self.pathField = [UITextField new];
    self.pathField.text = @"/var/mobile";
    self.pathField.placeholder = @"filesystem path";
    self.pathField.borderStyle = UITextBorderStyleRoundedRect;
    self.pathField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.pathField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.pathField.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *openPath = [self button:@"Open Path" action:@selector(openPath:)];
    UIButton *root = [self button:@"Root /" action:@selector(rootTapped:)];
    UIButton *apps = [self button:@"Applications" action:@selector(appsTapped:)];
    UIButton *mounts = [self button:@"JB Mounts" action:@selector(mountsTapped:)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[openPath, root, apps, mounts]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 10;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    self.outputView = [UITextView new];
    self.outputView.editable = NO;
    self.outputView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.outputView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.outputView.layer.cornerRadius = 12;
    self.outputView.text = [NSString stringWithFormat:@"UI READY\nuid=%u\n\nTap a route to test jailbreak filesystem access.", getuid()];
    self.outputView.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle, self.pathField, buttons, self.outputView]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18],
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18],
        [self.outputView.heightAnchor constraintGreaterThanOrEqualToConstant:220]
    ]];
}

- (void)setOutput:(NSString *)text { self.outputView.text = text ?: @""; }
- (void)openPath:(id)sender {
    NSString *path = self.pathField.text.length ? self.pathField.text : @"/var/mobile";
    NSString *q = [path stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    [self setOutput:RunShell([NSString stringWithFormat:@"ls -la '%@' 2>&1 | head -n 120", q])];
}
- (void)rootTapped:(id)sender { [self setOutput:RunShell(@"ls -la / 2>&1 | head -n 120")]; }
- (void)appsTapped:(id)sender { [self setOutput:RunShell(@"ls -la /var/containers/Bundle/Application 2>&1 | head -n 120")]; }
- (void)mountsTapped:(id)sender { [self setOutput:RunShell(@"mount 2>&1 | head -n 120")]; }
@end

static __strong UIWindow *gRetainedWindow = nil;

@interface ThreeOneOSFiveJB15Delegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation ThreeOneOSFiveJB15Delegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect frame = UIScreen.mainScreen.bounds;
    self.window = [[UIWindow alloc] initWithFrame:frame];
    gRetainedWindow = self.window;

    ThreeOneOSFiveJB15ViewController *root = [ThreeOneOSFiveJB15ViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    self.window.rootViewController = nav;
    self.window.backgroundColor = UIColor.systemBackgroundColor;
    self.window.windowLevel = UIWindowLevelNormal;
    self.window.hidden = NO;
    [self.window makeKeyAndVisible];

    NSString *marker = [NSString stringWithFormat:@"UI_READY=1\npid=%d\nwindow=%@\nkey=%d\nhidden=%d\n", getpid(), self.window, self.window.isKeyWindow, self.window.isHidden];
    [marker writeToFile:@"/var/mobile/Media/3105-ui-ready.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"[3105-iOS15] %@", marker);
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (self.window) {
        self.window.hidden = NO;
        [self.window makeKeyAndVisible];
        gRetainedWindow = self.window;
    }
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ThreeOneOSFiveJB15Delegate class]));
    }
}

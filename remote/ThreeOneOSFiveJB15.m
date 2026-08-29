#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <spawn.h>
#import <sys/wait.h>
#import <fcntl.h>
#import <unistd.h>

extern char **environ;
static const char *kPhasePath = "/var/mobile/Media/3105-launch-phase.txt";
static NSString * const kMarkerPath = @"/var/mobile/Media/3105-ui-ready.txt";

static void AppendRawPhase(const char *phase) {
    int fd = open(kPhasePath, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    char line[256];
    int n = snprintf(line, sizeof(line), "phase=%s pid=%d uid=%u euid=%u\n", phase, getpid(), getuid(), geteuid());
    if (n > 0) write(fd, line, (size_t)n);
    fsync(fd);
    close(fd);
}

__attribute__((constructor)) static void ThreeOneOSFiveLaunchConstructor(void) {
    AppendRawPhase("constructor");
}

static NSString *RunShell(NSString *command) {
    NSArray<NSString *> *shells = @[@"/var/jb/usr/bin/bash", @"/var/jb/bin/bash", @"/var/jb/bin/sh", @"/bin/sh"];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *shell = nil;
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
    ssize_t count;
    while ((count = read(pipefd[0], buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:(NSUInteger)count];
    close(pipefd[0]);
    int status = 0;
    waitpid(pid, &status, 0);
    NSString *out = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return out.length ? out : [NSString stringWithFormat:@"Command finished (status %d).", status];
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
    AppendRawPhase("viewDidLoad-enter");
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"3105";

    UILabel *title = [self label:@"3105 — Dopamine iOS 15" size:28 weight:UIFontWeightBold];
    UILabel *subtitle = [self label:@"Jailbreak compatibility runtime active" size:14 weight:UIFontWeightRegular];
    subtitle.textColor = UIColor.secondaryLabelColor;

    self.pathField = [UITextField new];
    self.pathField.text = @"/var/mobile";
    self.pathField.placeholder = @"filesystem path";
    self.pathField.borderStyle = UITextBorderStyleRoundedRect;
    self.pathField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.pathField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.pathField.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self button:@"Open Path" action:@selector(openPath:)],
        [self button:@"Root /" action:@selector(rootTapped:)],
        [self button:@"Applications" action:@selector(appsTapped:)],
        [self button:@"Dopamine /var/jb" action:@selector(jbTapped:)]
    ]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 10;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    self.outputView = [UITextView new];
    self.outputView.editable = NO;
    self.outputView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.outputView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.outputView.layer.cornerRadius = 12;
    self.outputView.text = [NSString stringWithFormat:@"UI READY\npid=%d uid=%u euid=%u\n\nTap a route to test jailbreak filesystem access.", getpid(), getuid(), geteuid()];
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
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-12],
        [self.outputView.heightAnchor constraintGreaterThanOrEqualToConstant:170]
    ]];
    AppendRawPhase("viewDidLoad-exit");
}
- (void)setOutput:(NSString *)text { self.outputView.text = text ?: @""; }
- (void)openPath:(id)sender {
    NSString *path = self.pathField.text.length ? self.pathField.text : @"/var/mobile";
    NSString *escaped = [path stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    [self setOutput:RunShell([NSString stringWithFormat:@"ls -la '%@' 2>&1 | head -n 120", escaped])];
}
- (void)rootTapped:(id)sender { [self setOutput:RunShell(@"ls -la / 2>&1 | head -n 120")]; }
- (void)appsTapped:(id)sender { [self setOutput:RunShell(@"ls -la /var/containers/Bundle/Application 2>&1 | head -n 120")]; }
- (void)jbTapped:(id)sender { [self setOutput:RunShell(@"ls -la /var/jb 2>&1 | head -n 120")]; }
@end

static __strong UIWindow *gRetainedWindow = nil;

@interface ThreeOneOSFiveJB15Delegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
- (void)buildCompatibilityWindow:(NSString *)phase;
@end

@implementation ThreeOneOSFiveJB15Delegate

- (void)writeWindowMarker:(NSString *)phase {
    UIViewController *candidate = self.window.rootViewController;
    if ([candidate isKindOfClass:UINavigationController.class]) candidate = ((UINavigationController *)candidate).topViewController;
    BOOL loaded = candidate != nil && candidate.isViewLoaded;
    NSString *marker = [NSString stringWithFormat:
        @"UI_READY=1\nphase=%@\npid=%d\nuid=%u\neuid=%u\nwindow=%@\nkey=%d\nhidden=%d\nroot_view_loaded=%d\n",
        phase, getpid(), getuid(), geteuid(), self.window, self.window.isKeyWindow, self.window.isHidden, loaded];
    [marker writeToFile:kMarkerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    AppendRawPhase(phase.UTF8String);
    NSLog(@"[3105-iOS15] %@", marker);
}

- (void)buildCompatibilityWindow:(NSString *)phase {
    AppendRawPhase("window-build-enter");
    if (!self.window) {
        CGRect frame = UIScreen.mainScreen.bounds;
        UIWindow *window = [[UIWindow alloc] initWithFrame:frame];
        ThreeOneOSFiveJB15ViewController *root = [ThreeOneOSFiveJB15ViewController new];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
        window.rootViewController = nav;
        window.backgroundColor = UIColor.systemBackgroundColor;
        window.windowLevel = UIWindowLevelNormal;
        window.userInteractionEnabled = YES;
        self.window = window;
        gRetainedWindow = window;
        (void)root.view;
        [window layoutIfNeeded];
        window.hidden = NO;
        [window makeKeyAndVisible];
        [window setNeedsLayout];
        [window layoutIfNeeded];
    } else {
        self.window.hidden = NO;
        [self.window makeKeyAndVisible];
        gRetainedWindow = self.window;
    }
    AppendRawPhase("window-build-visible");
    [self writeWindowMarker:phase];
}

- (instancetype)init {
    AppendRawPhase("delegate-init-enter");
    self = [super init];
    if (self) {
        AppendRawPhase("delegate-init-super-done");
        [self buildCompatibilityWindow:@"delegate-init-window"];
    }
    AppendRawPhase("delegate-init-exit");
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    AppendRawPhase("didFinish-enter");
    [self buildCompatibilityWindow:@"didFinish"];
    AppendRawPhase("didFinish-exit");
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    AppendRawPhase("active-enter");
    [self buildCompatibilityWindow:@"active"];
    AppendRawPhase("active-exit");
}
@end

int main(int argc, char *argv[]) {
    AppendRawPhase("main-enter");
    @autoreleasepool {
        AppendRawPhase("before-UIApplicationMain");
        int rc = UIApplicationMain(argc, argv, nil, NSStringFromClass([ThreeOneOSFiveJB15Delegate class]));
        AppendRawPhase("UIApplicationMain-returned");
        return rc;
    }
}

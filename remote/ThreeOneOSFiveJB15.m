#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#include <string.h>

extern char **environ;

static const char *kPhasePath = "/var/mobile/Media/3105-launch-phase.txt";

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
    AppendRawPhase("viewDidLoad-enter");
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"3105";

    UILabel *title = [self label:@"3105 — Dopamine iOS 15" size:28 weight:UIFontWeightBold];
    UILabel *subtitle = [self label:@"UIKit compatibility mode is active. If you can read this, the foreground scene is real." size:14 weight:UIFontWeightRegular];
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
    self.outputView.text = [NSString stringWithFormat:@"UI READY\npid=%d uid=%u euid=%u\n\nTap a route to test filesystem access.", getpid(), getuid(), geteuid()];
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
        [self.outputView.heightAnchor constraintGreaterThanOrEqualToConstant:180]
    ]];
    AppendRawPhase("viewDidLoad-exit");
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

- (instancetype)init {
    AppendRawPhase("delegate-init-enter");
    self = [super init];
    AppendRawPhase("delegate-init-exit");
    return self;
}

- (void)writeWindowMarker:(NSString *)phase {
    ThreeOneOSFiveJB15ViewController *root = nil;
    UIViewController *candidate = self.window.rootViewController;
    if ([candidate isKindOfClass:UINavigationController.class]) {
        candidate = ((UINavigationController *)candidate).topViewController;
    }
    if ([candidate isKindOfClass:ThreeOneOSFiveJB15ViewController.class]) root = (ThreeOneOSFiveJB15ViewController *)candidate;
    BOOL viewLoaded = root != nil && root.isViewLoaded;
    NSString *marker = [NSString stringWithFormat:@"UI_READY=1\nphase=%@\npid=%d\nwindow=%@\nkey=%d\nhidden=%d\nroot_view_loaded=%d\napplication_state=%ld\n", phase, getpid(), self.window, self.window.isKeyWindow, self.window.isHidden, viewLoaded, (long)UIApplication.sharedApplication.applicationState];
    [marker writeToFile:@"/var/mobile/Media/3105-ui-ready.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    AppendRawPhase(phase.UTF8String);
    NSLog(@"[3105-iOS15] %@", marker);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    AppendRawPhase("didFinish-enter");
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
    (void)root.view;
    [self writeWindowMarker:@"didFinish"];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    AppendRawPhase("active-enter");
    if (self.window) {
        self.window.hidden = NO;
        [self.window makeKeyAndVisible];
        gRetainedWindow = self.window;
        [self writeWindowMarker:@"active"];
    }
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

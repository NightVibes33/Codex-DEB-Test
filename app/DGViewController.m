#import "DGViewController.h"
#import "DGRootClient.h"
#import <WebKit/WebKit.h>

@interface DGViewController () <WKNavigationDelegate, WKScriptMessageHandler>
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong) DGRootClient *rootClient;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) NSMutableSet<NSString *> *handledToolIDs;
@end

@implementation DGViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DarkGPT";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.rootClient = [DGRootClient new];
    self.handledToolIDs = [NSMutableSet set];

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    [configuration.userContentController addScriptMessageHandler:self name:@"darkgptTool"];
    [configuration.userContentController addUserScript:[self toolObserverScript]];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.allowsBackForwardNavigationGestures = YES;

    self.statusLabel = [UILabel new];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.text = @"ChatGPT session • root tools not checked";

    UIToolbar *toolbar = [UIToolbar new];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    UIBarButtonItem *login = [[UIBarButtonItem alloc] initWithTitle:@"Login" style:UIBarButtonItemStylePlain target:self action:@selector(openLogin)];
    UIBarButtonItem *agent = [[UIBarButtonItem alloc] initWithTitle:@"Agent" style:UIBarButtonItemStylePlain target:self action:@selector(enableAgentMode)];
    UIBarButtonItem *health = [[UIBarButtonItem alloc] initWithTitle:@"Tools" style:UIBarButtonItemStylePlain target:self action:@selector(checkRootTools)];
    UIBarButtonItem *reload = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadPage)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    toolbar.items = @[login, space, agent, space, health, space, reload];

    [self.view addSubview:self.statusLabel];
    [self.view addSubview:self.webView];
    [self.view addSubview:toolbar];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:4],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.statusLabel.heightAnchor constraintEqualToConstant:18],

        [self.webView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:toolbar.topAnchor],

        [toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [toolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];

    [self loadURLString:@"https://chatgpt.com/"];
}

- (void)dealloc {
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"darkgptTool"];
}

- (WKUserScript *)toolObserverScript {
    NSString *source = @"(() => {\n"
    "if (window.__darkgptInstalled) return; window.__darkgptInstalled = true;\n"
    "const seen = new Set();\n"
    "function scan() {\n"
    "  document.querySelectorAll('pre code, code').forEach((node) => {\n"
    "    const text = (node.innerText || node.textContent || '').trim();\n"
    "    if (!text.includes('\\\"darkgpt_tool\\\"')) return;\n"
    "    try {\n"
    "      const obj = JSON.parse(text);\n"
    "      if (!obj.darkgpt_tool) return;\n"
    "      const id = obj.id || (obj.darkgpt_tool + ':' + text);\n"
    "      if (seen.has(id)) return; seen.add(id);\n"
    "      window.webkit.messageHandlers.darkgptTool.postMessage({id, tool: obj.darkgpt_tool, args: obj.args || {}});\n"
    "    } catch (_) {}\n"
    "  });\n"
    "}\n"
    "new MutationObserver(scan).observe(document.documentElement, {subtree:true, childList:true, characterData:true});\n"
    "setInterval(scan, 1500); scan();\n"
    "})();";
    return [[WKUserScript alloc] initWithSource:source injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
}

- (void)loadURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)openLogin {
    [self loadURLString:@"https://chatgpt.com/auth/login"];
}

- (void)reloadPage {
    [self.webView reload];
}

- (void)checkRootTools {
    self.statusLabel.text = @"Checking root daemon…";
    [self.rootClient sendRequest:@{@"op": @"health"} completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            self.statusLabel.text = [NSString stringWithFormat:@"Root tools offline: %@", error.localizedDescription];
            return;
        }
        NSNumber *uid = response[@"uid"] ?: @(-1);
        self.statusLabel.text = [NSString stringWithFormat:@"Root tools online • uid %@", uid];
    }];
}

- (void)enableAgentMode {
    NSString *protocol = @"Enable DarkGPT local-tool mode for this conversation. When a device operation is required, respond with only one JSON object in a fenced code block using this exact shape: {\"id\":\"unique-id\",\"darkgpt_tool\":\"tool-name\",\"args\":{}}. Available read tools are health, list, read, stat, search, process_list, crash_list, git_status, and git_diff. Write, patch, build, service, package, or shell operations require a one-time local approval code. Never claim a tool ran until a TOOL_RESULT message confirms it. Use bounded, reversible tests and do not request destructive commands, credential extraction, filesystem erasure, persistence changes, or unattended kernel writes.";
    [self submitTextToChatGPT:protocol];
    self.statusLabel.text = @"Agent protocol submitted to current conversation";
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)userContentController;
    if (![message.name isEqualToString:@"darkgptTool"] || ![message.body isKindOfClass:NSDictionary.class]) return;

    NSDictionary *body = (NSDictionary *)message.body;
    NSString *toolID = [body[@"id"] isKindOfClass:NSString.class] ? body[@"id"] : NSUUID.UUID.UUIDString;
    if ([self.handledToolIDs containsObject:toolID]) return;
    [self.handledToolIDs addObject:toolID];

    NSString *tool = [body[@"tool"] isKindOfClass:NSString.class] ? body[@"tool"] : @"";
    NSDictionary *args = [body[@"args"] isKindOfClass:NSDictionary.class] ? body[@"args"] : @{};
    if (tool.length == 0) return;

    NSMutableDictionary *request = [args mutableCopy];
    request[@"op"] = tool;
    self.statusLabel.text = [NSString stringWithFormat:@"Running tool: %@", tool];

    [self.rootClient sendRequest:request completion:^(NSDictionary *response, NSError *error) {
        NSDictionary *result = response ?: @{@"ok": @NO, @"error": error.localizedDescription ?: @"Unknown root tool error"};
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
        NSString *messageText = [NSString stringWithFormat:@"TOOL_RESULT %@\n%@", toolID, json];
        [self submitTextToChatGPT:messageText];
        self.statusLabel.text = [NSString stringWithFormat:@"Tool completed: %@", tool];
    }];
}

- (void)submitTextToChatGPT:(NSString *)text {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[text] options:0 error:nil];
    NSString *arrayJSON = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[\"\"]";
    NSString *script = [NSString stringWithFormat:
        @"(() => { const value = %@[0];"
         "const ta = document.querySelector('textarea');"
         "if (ta) { const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set; setter.call(ta,value); ta.dispatchEvent(new Event('input',{bubbles:true})); }"
         "else { const ed = document.querySelector('[contenteditable=\\\"true\\\"]'); if (!ed) return 'no-composer'; ed.focus(); ed.innerText=value; ed.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:value})); }"
         "setTimeout(() => { const button = document.querySelector('button[data-testid=\\\"send-button\\\"], button[aria-label*=\\\"Send\\\"], button[aria-label*=\\\"send\\\"]'); if (button && !button.disabled) button.click(); }, 250); return 'submitted'; })();", arrayJSON];

    [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error) self.statusLabel.text = [NSString stringWithFormat:@"Composer automation failed: %@", error.localizedDescription];
        else if ([result isKindOfClass:NSString.class] && [result isEqualToString:@"no-composer"]) self.statusLabel.text = @"Open a ChatGPT conversation before enabling Agent mode";
    }];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)webView;
    (void)navigation;
    self.statusLabel.text = @"ChatGPT loaded • use the account model picker";
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    (void)webView;
    (void)navigation;
    self.statusLabel.text = [NSString stringWithFormat:@"ChatGPT load failed: %@", error.localizedDescription];
}

@end

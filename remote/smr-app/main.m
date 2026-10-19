#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

static NSString *const kSocket = @"/var/mobile/Library/SafeModeRepair/rootd.sock";
static UIColor *SMRBG(void) { return [UIColor colorWithRed:.050 green:.073 blue:.120 alpha:1]; }
static UIColor *SMRCard(void) { return [UIColor colorWithRed:.098 green:.133 blue:.205 alpha:1]; }
static UIColor *SMRText(void) { return [UIColor colorWithRed:.94 green:.97 blue:1 alpha:1]; }
static UIColor *SMRMuted(void) { return [UIColor colorWithRed:.63 green:.71 blue:.81 alpha:1]; }
static UIColor *SMRAccent(void) { return [UIColor colorWithRed:.24 green:.87 blue:.79 alpha:1]; }

static NSString *SMRCall(NSString *command) {
    int fd=socket(AF_UNIX,SOCK_STREAM,0);
    if(fd<0) return [NSString stringWithFormat:@"ERROR: Connection unavailable (%s)",strerror(errno)];
    struct sockaddr_un addr={0};
    addr.sun_family=AF_UNIX;
    strlcpy(addr.sun_path,kSocket.UTF8String,sizeof(addr.sun_path));
    struct timeval limit={.tv_sec=35,.tv_usec=0};
    setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&limit,sizeof(limit));
    if(connect(fd,(struct sockaddr *)&addr,sizeof(addr))!=0) {
        NSString *e=[NSString stringWithFormat:@"ERROR: Repair service unavailable (%s). Reinstall DEB or restart launchd service.",strerror(errno)];
        close(fd);return e;
    }
    NSData *data=[[command stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    const char *p=data.bytes;size_t rem=data.length;
    while(rem){ssize_t n=write(fd,p,rem);if(n<=0){close(fd);return @"ERROR: Request failed";}p+=n;rem-=n;}
    shutdown(fd,SHUT_WR);
    NSMutableData *out=[NSMutableData data];char buf[4096];ssize_t n;
    while((n=read(fd,buf,sizeof(buf)))>0){
        if(out.length+(NSUInteger)n>512*1024)break;
        [out appendBytes:buf length:(NSUInteger)n];
    }
    close(fd);
    NSString *text=[[NSString alloc]initWithData:out encoding:NSUTF8StringEncoding];
    return text?:@"ERROR: Invalid response";
}
static NSDictionary *SMRKeyValues(NSString *input) {
    NSMutableDictionary *dict=[NSMutableDictionary dictionary];
    for(NSString *line in [input componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSRange r=[line rangeOfString:@"="];if(r.location==NSNotFound)continue;
        NSString *k=[[line substringToIndex:r.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *v=[line substringFromIndex:r.location+1];
        if(k.length)dict[k]=v;
    }
    return dict;
}

@interface SMRPanelCell:UITableViewCell
@property(nonatomic,strong) UILabel *overline;
@property(nonatomic,strong) UILabel *headline;
@property(nonatomic,strong) UILabel *body;
@property(nonatomic,strong) UIView *accentLine;
@end
@implementation SMRPanelCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse {
    if((self=[super initWithStyle:style reuseIdentifier:reuse])){
        self.backgroundColor=UIColor.clearColor;self.selectionStyle=UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor=SMRCard();
        self.contentView.layer.cornerRadius=18;self.contentView.layer.masksToBounds=YES;
        _overline=[UILabel new];_headline=[UILabel new];_body=[UILabel new];_accentLine=[UIView new];
        _overline.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        _overline.textColor=SMRAccent();
        _headline.font=[UIFont systemFontOfSize:21 weight:UIFontWeightBold];
        _headline.textColor=SMRText();_headline.numberOfLines=2;
        _body.font=[UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _body.textColor=SMRMuted();_body.numberOfLines=4;
        _accentLine.backgroundColor=SMRAccent();
        [self.contentView addSubview:_overline];[self.contentView addSubview:_headline];[self.contentView addSubview:_body];[self.contentView addSubview:_accentLine];
    }return self;
}
- (void)layoutSubviews{
    [super layoutSubviews];
    CGFloat w=self.bounds.size.width;
    self.contentView.frame=CGRectMake(16,4,w-32,self.bounds.size.height-8);
    CGFloat inner=self.contentView.bounds.size.width;
    _accentLine.frame=CGRectMake(0,0,5,self.contentView.bounds.size.height);
    _overline.frame=CGRectMake(20,15,inner-38,18);
    _headline.frame=CGRectMake(20,39,inner-36,52);
    _body.frame=CGRectMake(20,98,inner-36,self.contentView.bounds.size.height-110);
}
@end

@interface SMRAppController:UITableViewController <UISearchBarDelegate>
@property(nonatomic,strong) NSArray<NSDictionary *> *tweaks;
@property(nonatomic,strong) NSArray<NSDictionary *> *filtered;
@property(nonatomic,strong) NSDictionary *facts;
@property(nonatomic,strong) NSString *diagnosticText;
@property(nonatomic,strong) NSString *scanMessage;
@property(nonatomic,strong) NSString *searchTerm;
@property(nonatomic,strong) UISegmentedControl *tabs;
@property(nonatomic,strong) UISearchBar *search;
@property(nonatomic,strong) UIActivityIndicatorView *activity;
@property(nonatomic,assign) NSInteger mode;
@property(nonatomic,assign) BOOL busy;
@end

@implementation SMRAppController
- (instancetype)init { if((self=[super initWithStyle:UITableViewStyleGrouped])) {
    _tweaks=@[];_filtered=@[];_facts=@{};_searchTerm=@"";_mode=0;
    _scanMessage=@"Gathering crash evidence…";_diagnosticText=@"";
}return self;}
- (void)viewDidLoad{
    [super viewDidLoad];
    self.title=@"Safe Mode Repair";
    self.navigationController.navigationBar.prefersLargeTitles=YES;
    self.navigationController.navigationBar.tintColor=SMRAccent();
    self.navigationController.navigationBar.barStyle=UIBarStyleBlack;
    self.tableView.backgroundColor=SMRBG();self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset=UIEdgeInsetsMake(4,0,30,0);
    self.tableView.estimatedRowHeight=88;
    [self.tableView registerClass:SMRPanelCell.class forCellReuseIdentifier:@"panel"];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    UIView *header=[[UIView alloc]initWithFrame:CGRectMake(0,0,UIScreen.mainScreen.bounds.size.width,110)];
    header.backgroundColor=SMRBG();
    _tabs=[[UISegmentedControl alloc]initWithItems:@[@"Evidence",@"Disabled",@"Diagnostics"]];
    _tabs.selectedSegmentIndex=0;
    _tabs.selectedSegmentTintColor=SMRAccent();
    _tabs.frame=CGRectMake(16,10,header.bounds.size.width-32,35);
    [_tabs addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    [header addSubview:_tabs];
    _search=[[UISearchBar alloc]initWithFrame:CGRectMake(7,52,header.bounds.size.width-14,51)];
    _search.placeholder=@"Find an installed tweak";
    _search.delegate=self;
    _search.searchBarStyle=UISearchBarStyleMinimal;
    _search.barTintColor=SMRBG();_search.tintColor=SMRAccent();
    if(@available(iOS 13.0,*)){
        _search.searchTextField.textColor=SMRText();
        _search.searchTextField.backgroundColor=SMRCard();
    }
    [header addSubview:_search];
    self.tableView.tableHeaderView=header;
    self.activity=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activity.color=SMRAccent();
    UIRefreshControl *pull=[UIRefreshControl new];
    pull.tintColor=SMRAccent();[pull addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl=pull;
    [self refresh];
}
- (void)tabChanged:(UISegmentedControl *)sender{
    self.mode=sender.selectedSegmentIndex;
    self.search.hidden=(self.mode==2);
    if(self.mode==2)self.search.text=@"";
    [self applyFilter];[self.tableView reloadData];
    [self refresh];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText{
    (void)searchBar;self.searchTerm=searchText?:@"";
    [self applyFilter];[self.tableView reloadData];
}
- (void)applyFilter{
    if(!self.searchTerm.length){self.filtered=self.tweaks;return;}
    NSPredicate *p=[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row,NSDictionary *bindings){
        (void)bindings;
        return [row[@"name"] localizedCaseInsensitiveContainsString:self.searchTerm]
         || [row[@"package"] localizedCaseInsensitiveContainsString:self.searchTerm];
    }];
    self.filtered=[self.tweaks filteredArrayUsingPredicate:p];
}
- (void)showBusy:(BOOL)busy {
    self.busy=busy;
    self.navigationItem.rightBarButtonItem.enabled=!busy;
    self.tabs.enabled=!busy;
    if(busy){[self.activity startAnimating];self.navigationItem.titleView=self.activity;}
    else {[self.activity stopAnimating];self.navigationItem.titleView=nil;[self.refreshControl endRefreshing];}
}
- (void)asyncCommand:(NSString *)command completion:(void (^)(NSString *))done{
    if(self.busy)return;
    [self showBusy:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSString *answer=SMRCall(command);
        dispatch_async(dispatch_get_main_queue(),^{[self showBusy:NO];done(answer);});
    });
}
- (void)refresh{
    if(self.busy)return;
    NSInteger thisMode=self.mode;
    [self showBusy:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSString *stats=SMRCall(@"DIAGNOSTICS");
        NSString *list=SMRCall(thisMode==1?@"DISABLED":@"SCAN");
        dispatch_async(dispatch_get_main_queue(),^{
            self.diagnosticText=stats;
            self.facts=SMRKeyValues(stats);
            [self parseTweaks:list disabled:thisMode==1];
            [self showBusy:NO];[self.tableView reloadData];
        });
    });
}
- (void)parseTweaks:(NSString *)out disabled:(BOOL)disabled{
    NSMutableArray *records=[NSMutableArray array];
    BOOL started=NO;
    for(NSString *line in [out componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]){
        if(disabled){
            if([line hasPrefix:@"=== DISABLED BY THIS TOOL ==="]){started=YES;continue;}
            if(started&&line.length&&![line hasPrefix:@"("]){
                [records addObject:@{@"name":line,@"score":@"-", @"package":@""}];
            }
        }else{
            if([line hasPrefix:@"SCORE\tREPORTS\tTWEAK\tPACKAGE"]){started=YES;continue;}
            if(!started)continue;
            NSArray *columns=[line componentsSeparatedByString:@"\t"];
            if(columns.count==4&&[columns[2] length]){
                [records addObject:@{@"name":columns[2],@"score":columns[0],@"reports":columns[1],@"package":columns[3]}];
            }
        }
    }
    if([out containsString:@"ERROR:"]){self.scanMessage=out;}
    else if([out containsString:@"attribution unavailable"]||[out containsString:@"scanner failed"]){
        self.scanMessage=@"Crash attribution unavailable. Use a controlled isolation test to identify a culprit.";
    }else if(disabled){self.scanMessage=@"Disabled tweaks can be restored at any time.";}
    else{self.scanMessage=@"Only frames on the crashing thread count as direct evidence. Scores of zero are inconclusive.";}
    self.tweaks=[records sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
        NSInteger va=[[self isolationVerdict:a[@"name"]] isEqualToString:@"FIXED"]?2:
          ([[self isolationVerdict:a[@"name"]] isEqualToString:@"PERSISTS"]?-1:0);
        NSInteger vb=[[self isolationVerdict:b[@"name"]] isEqualToString:@"FIXED"]?2:
          ([[self isolationVerdict:b[@"name"]] isEqualToString:@"PERSISTS"]?-1:0);
        if(va!=vb)return va>vb?NSOrderedAscending:NSOrderedDescending;
        NSInteger sa=[a[@"score"] integerValue],sb=[b[@"score"] integerValue];
        if(sa!=sb)return sa>sb?NSOrderedAscending:NSOrderedDescending;
        return [a[@"name"] localizedStandardCompare:b[@"name"]];
    }];
    [self applyFilter];
}
- (NSString *)isolationVerdict:(NSString *)name {
    NSString *result=@"";
    for (NSString *line in [self.diagnosticText componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSArray<NSString *> *parts=[line componentsSeparatedByString:@"\t"];
        if(parts.count>=3 && [parts[1] isEqualToString:name] &&
           ([parts[2] isEqualToString:@"FIXED"]||[parts[2] isEqualToString:@"PERSISTS"])) {
            result=parts[2];
        }
    }
    return result;
}
- (BOOL)testActive{
    NSString *v=self.facts[@"active_test"];
    return v.length&&![v isEqualToString:@"none"];
}
- (NSString *)testName{return self.facts[@"active_test"]?:@"";}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{(void)t;return self.mode==2?2:3;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section{
    (void)t;
    if(section<2)return 1;
    return self.filtered.count;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    (void)tableView;
    if(indexPath.section==0)return 184;
    if(indexPath.section==1)return self.mode==2?205:108;
    return 77;
}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)section{
    (void)t;
    if(section==0)return nil;
    if(section==1)return self.mode==2?@"DIAGNOSTIC EVIDENCE":([self testActive]?@"ISOLATION IN PROGRESS":@"FIND THE CULPRIT");
    return self.mode==1?@"DISABLED TWEAKS":@"INSTALLED TWEAKS";
}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)section{
    (void)t;
    if(section==1 && self.mode==0)return @"A controlled test can identify a culprit when crash logs contain no injected tweak.";
    if(section==2)return self.scanMessage;
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip{
    if(ip.section==0){
        SMRPanelCell *cell=[t dequeueReusableCellWithIdentifier:@"panel" forIndexPath:ip];
        NSString *pressure=self.facts[@"vm_pressure"];
        BOOL active=[self testActive];
        cell.overline.text=active?@"ISOLATION MODE":@"SYSTEM DIAGNOSTICS";
        if(self.mode==1){cell.headline.text=@"Recovery controls";cell.body.text=@"Restore disabled tweaks without reinstalling packages or resetting preferences.";}
        else if(self.mode==2){cell.headline.text=@"Evidence, not guesses";cell.body.text=[pressure isEqualToString:@"detected"]?@"Recent SpringBoard crash reports record memory pressure. That does not identify a specific tweak.":@"Analyze crash details and confirm changes through a controlled isolation test.";}
        else if(active){cell.headline.text=[NSString stringWithFormat:@"Testing %@",self.testName];cell.body.text=@"Temporarily disabled. Respring, then report whether Safe Mode ended.";}
        else{cell.headline.text=@"Pinpoint the crash";cell.body.text=[pressure isEqualToString:@"detected"]?@"Memory pressure detected. Crash logs do not prove which tweak caused it. Test suspects to isolate the cause.":@"Scan crash evidence and isolate one tweak at a time, without guessing.";}
        return cell;
    }
    if(ip.section==1){
        UITableViewCell *cell=[t dequeueReusableCellWithIdentifier:@"action"];
        if(!cell)cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"action"];
        cell.backgroundColor=SMRBG();cell.contentView.backgroundColor=SMRCard();
        cell.contentView.layer.cornerRadius=14;cell.contentView.layer.masksToBounds=YES;
        cell.textLabel.textColor=SMRText();cell.textLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        cell.detailTextLabel.textColor=SMRMuted();cell.detailTextLabel.numberOfLines=3;
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        if(self.mode==2){
            NSString *report=self.facts[@"report"]?:@"No recent crash";
            cell.textLabel.text=[self.facts[@"vm_pressure"] isEqualToString:@"detected"]?@"Memory pressure detected":@"Crash report inspection";
            cell.detailTextLabel.text=[NSString stringWithFormat:@"Latest: %@\nSafe Mode flag: %@\nActive test: %@",report,self.facts[@"safe_mode"]?:@"unknown",self.testName.length?self.testName:@"none"];
        }else if([self testActive]){
            cell.textLabel.text=@"Finish active isolation test";
            cell.detailTextLabel.text=@"Respring, then confirm whether Safe Mode disappeared.";
        }else{
            cell.textLabel.text=self.mode==1?@"Return to evidence":@"How to identify the culprit";
            cell.detailTextLabel.text=self.mode==1?@"Review crash suspects and start a controlled test":@"Select a tweak below → Test → Respring → Record result";
        }
        return cell;
    }
    UITableViewCell *cell=[t dequeueReusableCellWithIdentifier:@"tweak"];
    if(!cell)cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tweak"];
    NSDictionary *row=self.filtered[ip.row];NSString *name=row[@"name"];
    cell.backgroundColor=SMRBG();cell.contentView.backgroundColor=SMRCard();
    cell.textLabel.text=name;cell.textLabel.textColor=SMRText();
    cell.textLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.detailTextLabel.font=[UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor=SMRMuted();
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    if(self.mode==1)cell.detailTextLabel.text=@"Disabled • Tap to restore";
    else{
        NSInteger score=[row[@"score"] integerValue];
        NSString *verdict=[self isolationVerdict:name];
        if([verdict isEqualToString:@"FIXED"]){
            cell.detailTextLabel.text=[NSString stringWithFormat:@"Isolation test: Safe Mode cleared • %@",row[@"package"]];
            cell.detailTextLabel.textColor=SMRAccent();
        }else if([verdict isEqualToString:@"PERSISTS"]){
            cell.detailTextLabel.text=[NSString stringWithFormat:@"Isolation test: Safe Mode persisted • %@",row[@"package"]];
            cell.detailTextLabel.textColor=SMRMuted();
        }else {
            cell.detailTextLabel.text=score>0?[NSString stringWithFormat:@"Crash evidence: %@ • %@",row[@"score"],row[@"package"]]:
              [NSString stringWithFormat:@"No direct stack match • %@",row[@"package"]];
            cell.detailTextLabel.textColor=score>0?SMRAccent():SMRMuted();
        }
    }
    return cell;
}
- (void)message:(NSString *)title text:(NSString *)text{
    UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)run:(NSString *)command title:(NSString *)title {
    [self asyncCommand:command completion:^(NSString *response){
        [self message:[response containsString:@"ERROR:"]||[response containsString:@"failed"]?@"Action failed":title text:response];
        [self refresh];
    }];
}
- (void)confirmRespring {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Respring now?"
       message:@"SpringBoard will restart. Unsaved work in other apps may be interrupted. After returning, open Safe Mode Repair to record whether Safe Mode has cleared."
       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act){
        (void)act;[self run:@"RESPRING" title:@"Respring requested"];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)finishTest {
    if(![self testActive])return;
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Did disabling %@ fix Safe Mode?",self.testName]
        message:@"Only answer after a respring. This observation helps distinguish the actual cause from unrelated tweaks."
        preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Yes — Safe Mode disappeared" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        (void)a;[self run:@"TEST_FINISH FIXED" title:@"Candidate isolated"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"No — Safe Mode remained" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        (void)a;[self run:@"TEST_FINISH PERSISTS" title:@"Tweak restored"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Respring to test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;[self confirmRespring];}]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel test and restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
        (void)a;[self run:@"TEST_CANCEL" title:@"Tweak restored"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)selectTweak:(NSDictionary *)tweak{
    NSString *name=tweak[@"name"];
    if(self.mode==1){
        UIAlertController *a=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Restore %@?",name] message:@"Restores the original dylib and filter. Respring to apply." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){(void)x;[self run:[NSString stringWithFormat:@"ENABLE %@",name] title:@"Restored"]; }]];
        [self presentViewController:a animated:YES completion:nil];return;
    }
    NSString *details=[NSString stringWithFormat:@"Crash score: %@\nDebian package: %@\n\nA zero score means the crash report doesn't identify this tweak. Testing its effect is stronger evidence.",tweak[@"score"],tweak[@"package"]];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:name message:details preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Test by temporarily disabling" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        (void)x;
        if([self testActive]){[self message:@"Finish the current test" text:@"Only one isolation test can run at a time."];return;}
        UIAlertController *c=[UIAlertController alertControllerWithTitle:@"Start isolation test?"
            message:[NSString stringWithFormat:@"Temporarily disable %@ and record a baseline. Respring afterward and check whether Safe Mode clears. You can restore the tweak.",name] preferredStyle:UIAlertControllerStyleAlert];
        [c addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [c addAction:[UIAlertAction actionWithTitle:@"Begin test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *y){
            (void)y;[self run:[NSString stringWithFormat:@"TEST_START %@",name] title:@"Test started"];
        }]];
        [self presentViewController:c animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Disable without testing" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        (void)x;[self run:[NSString stringWithFormat:@"DISABLE %@",name] title:@"Tweak disabled"];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Uninstall package…" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){
        (void)x;
        UIAlertController *c=[UIAlertController alertControllerWithTitle:@"Remove entire package?"
        message:[NSString stringWithFormat:@"Uninstall %@. The repair service verifies dependencies and refuses unsafe removals. This is not reversible using Restore.",tweak[@"package"]]
        preferredStyle:UIAlertControllerStyleAlert];
        [c addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [c addAction:[UIAlertAction actionWithTitle:@"Uninstall" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *y){
            (void)y;[self run:[NSString stringWithFormat:@"UNINSTALL %@",name] title:@"Package removed"];
        }]];
        [self presentViewController:c animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip{
    [tableView deselectRowAtIndexPath:ip animated:YES];if(self.busy)return;
    if(ip.section==0){self.tabs.selectedSegmentIndex=2;[self tabChanged:self.tabs];return;}
    if(ip.section==1){
        if([self testActive]){[self finishTest];return;}
        if(self.mode==1){self.tabs.selectedSegmentIndex=0;[self tabChanged:self.tabs];return;}
        if(self.mode==2){[self message:@"Full diagnostic details" text:self.diagnosticText];return;}
        [self message:@"Controlled isolation" text:@"Choose a tweak below and tap Test. The app temporarily disables it and saves a baseline. Respring, then report whether Safe Mode cleared. Each test is reversible."];
        return;
    }
    if(ip.row<self.filtered.count)[self selectTweak:self.filtered[ip.row]];
}
@end

@interface SMRAppDelegate:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation SMRAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts{
    (void)app;(void)opts;
    self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
    UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:[SMRAppController new]];
    nav.navigationBar.prefersLargeTitles=YES;
    nav.navigationBar.barTintColor=SMRBG();
    nav.navigationBar.tintColor=SMRAccent();
    if(@available(iOS 13.0,*))nav.navigationBar.largeTitleTextAttributes=@{NSForegroundColorAttributeName:SMRText()};
    self.window.rootViewController=nav;
    if(@available(iOS 13.0,*))self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    [self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(SMRAppDelegate.class));}}

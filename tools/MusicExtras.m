// MusicExtras.m — optional native companion for an existing Music.app UI.
// Original Apple Music tabs, artwork, and player screens are never replaced.
// No MediaRemote interception, no UIApplication swizzling, and NO automatic
// playback-state writes. Audio is affected only by explicit local-file Play.
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <math.h>

@interface MLEExtras : NSObject <UIDocumentPickerDelegate, UITextFieldDelegate>
@property(nonatomic,strong) UIButton *accessory;
@property(nonatomic,strong) UIView *sheet;
@property(nonatomic,strong) UIView *backdrop;
@property(nonatomic,strong) UIStackView *stack;
@property(nonatomic,strong) UITextView *body;
@property(nonatomic,strong) UILabel *headline;
@property(nonatomic,strong) UITextField *titleInput;
@property(nonatomic,strong) UITextField *artistInput;
@property(nonatomic,strong) AVAudioPlayer *localAudio;
@property(nonatomic,strong) NSURL *localURL;
@property(nonatomic,strong) NSString *currentMode;
@property(nonatomic,strong) NSTimer *lyricsTimer;
@property(nonatomic,strong) NSArray<NSDictionary *> *timedLines;
@property(nonatomic,strong) NSString *rawLyrics;
@property(nonatomic,strong) NSString *selectedSong;
@property(nonatomic,strong) NSURLSessionDataTask *lyricsRequest;
@property(nonatomic,assign) NSInteger lastTimedIndex;
@end

@implementation MLEExtras

+ (instancetype)shared {
    static MLEExtras *obj;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ obj = [self new]; obj.lastTimedIndex = -1; });
    return obj;
}
- (NSString *)storage {
    NSString *p=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/MusicExtras"];
    [[NSFileManager defaultManager] createDirectoryAtPath:p
        withIntermediateDirectories:YES attributes:nil error:nil];
    return p;
}
- (BOOL)isMusicGuest {
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier ?: @"";
    return [bundle isEqualToString:@"com.nightvibes33.applemusic27"];
}
- (UIWindow *)window {
    UIApplication *app=UIApplication.sharedApplication;
    for (UIWindow *w in app.windows) {
        if (!w.isHidden && w.windowLevel == UIWindowLevelNormal && w.rootViewController) return w;
    }
    for (UIWindow *w in app.windows) if (!w.isHidden && w.rootViewController) return w;
    return nil;
}
- (void)attach {
    if (![self isMusicGuest]) { self.accessory.hidden=YES; return; }
    UIWindow *w=[self window];
    if (!w || CGRectGetWidth(w.bounds)<250) return;
    if (self.accessory.superview == w) { self.accessory.hidden=NO; return; }
    [self.accessory removeFromSuperview];
    self.accessory=[UIButton buttonWithType:UIButtonTypeSystem];
    self.accessory.accessibilityLabel=@"Music extras";
    self.accessory.accessibilityHint=@"Open optional lyrics, library and local files";
    [self.accessory setTitle:@"♫+" forState:UIControlStateNormal];
    self.accessory.titleLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [self.accessory setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.accessory.backgroundColor=[UIColor colorWithRed:.77 green:.12 blue:.25 alpha:.95];
    self.accessory.layer.cornerRadius=21;
    self.accessory.layer.borderWidth=1;
    self.accessory.layer.borderColor=[UIColor colorWithWhite:1 alpha:.25].CGColor;
    self.accessory.frame=CGRectMake(CGRectGetWidth(w.bounds)-54,
                                 MAX(w.safeAreaInsets.top+50,100),42,42);
    self.accessory.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin;
    [self.accessory addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];
    [w addSubview:self.accessory];
}
- (void)triggerAttach {
    if (!self.isMusicGuest) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [[MLEExtras shared] attach]; });
}
- (UIView *)roundPanel:(CGRect)frame color:(UIColor *)color {
    UIView *v=[[UIView alloc] initWithFrame:frame];
    v.backgroundColor=color;
    v.layer.cornerRadius=20;
    v.clipsToBounds=YES;
    return v;
}
- (UILabel *)label:(NSString *)txt size:(CGFloat)size {
    UILabel *l=[UILabel new];
    l.text=txt;
    l.font=[UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    l.textColor=UIColor.whiteColor;
    l.numberOfLines=0;
    return l;
}
- (UIButton *)addAction:(NSString *)title selector:(SEL)selector {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.backgroundColor=[UIColor colorWithWhite:1 alpha:.13];
    b.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    b.layer.cornerRadius=11;
    b.contentEdgeInsets=UIEdgeInsetsMake(12,12,12,12);
    b.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
    [b addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:b];
    b.translatesAutoresizingMaskIntoConstraints=NO;
    [b.heightAnchor constraintGreaterThanOrEqualToConstant:42].active=YES;
    return b;
}
- (void)clearPage:(NSString *)headline {
    self.currentMode=headline;
    self.headline.text=headline;
    [self.lyricsTimer invalidate];
    self.lyricsTimer=nil;
    self.lastTimedIndex=-1;
    for (UIView *v in [self.stack.arrangedSubviews copy]) {
        [self.stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
}
- (void)addText:(NSString *)txt {
    UILabel *l=[self label:txt size:14];
    [self.stack addArrangedSubview:l];
}
- (void)present {
    UIWindow *w=[self window];
    if (!w || ![self isMusicGuest]) return;
    [self close];
    CGRect bounds=w.bounds;
    self.backdrop=[[UIView alloc] initWithFrame:bounds];
    self.backdrop.backgroundColor=[UIColor colorWithWhite:0 alpha:.57];
    self.backdrop.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [w addSubview:self.backdrop];
    UITapGestureRecognizer *dismiss=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    [self.backdrop addGestureRecognizer:dismiss];

    CGFloat safeBottom=w.safeAreaInsets.bottom;
    CGFloat height=MIN(550,CGRectGetHeight(bounds)-w.safeAreaInsets.top-36);
    self.sheet=[self roundPanel:CGRectMake(8,CGRectGetHeight(bounds)-height-8-safeBottom,
        CGRectGetWidth(bounds)-16,height) color:[UIColor colorWithRed:.10 green:.10 blue:.13 alpha:1]];
    self.sheet.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
    [w addSubview:self.sheet];
    UIView *header=[UIView new];
    header.translatesAutoresizingMaskIntoConstraints=NO;
    [self.sheet addSubview:header];
    self.headline=[self label:@"Music Extras" size:19];
    self.headline.translatesAutoresizingMaskIntoConstraints=NO;
    [header addSubview:self.headline];
    UIButton *close=[UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"Done" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor colorWithRed:1 green:.36 blue:.45 alpha:1] forState:UIControlStateNormal];
    close.translatesAutoresizingMaskIntoConstraints=NO;
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];
    UIScrollView *scroll=[UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints=NO;
    scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;
    [self.sheet addSubview:scroll];
    self.stack=[UIStackView new];
    self.stack.axis=UILayoutConstraintAxisVertical;
    self.stack.alignment=UIStackViewAlignmentFill;
    self.stack.spacing=10;
    self.stack.translatesAutoresizingMaskIntoConstraints=NO;
    [scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.sheet.topAnchor constant:10],
        [header.leadingAnchor constraintEqualToAnchor:self.sheet.leadingAnchor constant:18],
        [header.trailingAnchor constraintEqualToAnchor:self.sheet.trailingAnchor constant:-18],
        [header.heightAnchor constraintEqualToConstant:42],
        [self.headline.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [self.headline.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [close.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [close.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8],
        [scroll.bottomAnchor constraintEqualToAnchor:self.sheet.bottomAnchor constant:-15],
        [scroll.leadingAnchor constraintEqualToAnchor:self.sheet.leadingAnchor constant:16],
        [scroll.trailingAnchor constraintEqualToAnchor:self.sheet.trailingAnchor constant:-16],
        [self.stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [self.stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [self.stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [self.stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [self.stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];
}
- (void)openMenu {
    [self present];
    [self menuPage];
}
- (void)close {
    [self.lyricsTimer invalidate]; self.lyricsTimer=nil;
    [self.titleInput resignFirstResponder];
    [self.artistInput resignFirstResponder];
    [self.sheet removeFromSuperview]; self.sheet=nil;
    [self.backdrop removeFromSuperview]; self.backdrop=nil;
}
- (void)menuPage {
    [self clearPage:@"Music Extras"];
    [self addText:@"Native extensions for your original Apple Music interface. Playback stays with your existing Apple Music app unless you choose local-file playback."];
    [self addAction:@"♪ Synced lyrics (LRCLIB)" selector:@selector(lyricsPage)];
    [self addAction:@"♫ Now Playing / playback sources" selector:@selector(nowPlayingPage)];
    [self addAction:@"▤ Your Music library" selector:@selector(libraryPage)];
    [self addAction:@"＋ Import an audio file" selector:@selector(importFile)];
    [self addAction:@"▶ Imported music" selector:@selector(filesPage)];
    [self addAction:@"ⓘ Diagnostics / feature notes" selector:@selector(infoPage)];
}
- (void)addBack {
    [self addAction:@"‹ All extras" selector:@selector(menuPage)];
}
- (MPMusicPlayerController *)audiblePlayer {
    MPMusicPlayerController *a=[MPMusicPlayerController applicationQueuePlayer];
    MPMusicPlayerController *s=[MPMusicPlayerController systemMusicPlayer];
    if (a.nowPlayingItem && a.playbackState==MPMusicPlaybackStatePlaying) return a;
    if (s.nowPlayingItem && s.playbackState==MPMusicPlaybackStatePlaying) return s;
    if (a.nowPlayingItem) return a;
    return s;
}
- (NSString *)stateName:(MPMusicPlaybackState)state {
    switch(state) {
        case MPMusicPlaybackStatePlaying: return @"Playing";
        case MPMusicPlaybackStatePaused: return @"Paused";
        case MPMusicPlaybackStateStopped: return @"Stopped";
        case MPMusicPlaybackStateInterrupted: return @"Interrupted";
        default: return @"Unknown";
    }
}
- (void)nowPlayingPage {
    [self clearPage:@"Playback sources"];
    [self addBack];
    MPMusicPlayerController *a=[MPMusicPlayerController applicationQueuePlayer];
    MPMusicPlayerController *s=[MPMusicPlayerController systemMusicPlayer];
    for (NSUInteger i=0;i<2;i++) {
        MPMusicPlayerController *p=i==0?a:s;
        MPMediaItem *item=p.nowPlayingItem;
        NSString *kind=i==0?@"Application player":@"System Music player";
        NSString *song=[item valueForProperty:MPMediaItemPropertyTitle] ?: @"No track exposed";
        [self addText:[NSString stringWithFormat:@"%@\n%@ — %@\nPosition %.1f sec",
            kind,[self stateName:p.playbackState],song,p.currentPlaybackTime]];
    }
    if (self.localURL) [self addText:[NSString stringWithFormat:@"Imported audio: %@ (%@)",
        self.localURL.lastPathComponent,self.localAudio.isPlaying?@"Playing":@"Paused"]];
    [self addText:@"Playback readout is informational. It does not claim to repair Apple's older Music Now Playing UI. No other session is paused, stopped or taken over."];
    [self addAction:@"Refresh status" selector:@selector(nowPlayingPage)];
}
- (UITextField *)makeInput:(NSString *)placeholder value:(NSString *)value {
    UITextField *f=[UITextField new];
    f.placeholder=placeholder; f.text=value;
    f.delegate=self; f.returnKeyType=UIReturnKeyDone;
    f.textColor=UIColor.whiteColor;
    f.backgroundColor=[UIColor colorWithWhite:1 alpha:.12];
    f.layer.cornerRadius=10;
    f.font=[UIFont systemFontOfSize:15];
    UIView *left=[[UIView alloc] initWithFrame:CGRectMake(0,0,11,15)];
    f.leftView=left; f.leftViewMode=UITextFieldViewModeAlways;
    [self.stack addArrangedSubview:f];
    [f.heightAnchor constraintEqualToConstant:43].active=YES;
    return f;
}
- (BOOL)textFieldShouldReturn:(UITextField *)field {
    [field resignFirstResponder]; return YES;
}
- (void)lyricsPage {
    [self clearPage:@"Synced lyrics"];
    [self addBack];
    MPMediaItem *item=self.audiblePlayer.nowPlayingItem;
    NSString *title=[item valueForProperty:MPMediaItemPropertyTitle];
    NSString *artist=[item valueForProperty:MPMediaItemPropertyArtist];
    if (self.localURL && self.localAudio.isPlaying) {
        title=self.localURL.URLByDeletingPathExtension.lastPathComponent;
        artist=@"";
    }
    [self addText:@"Uses a matching LRCLIB result. If Music doesn't expose the active song, enter its title and artist. Timed lines follow playback position when available."];
    self.titleInput=[self makeInput:@"Song title" value:title ?: @""];
    self.artistInput=[self makeInput:@"Artist" value:artist ?: @""];
    [self addAction:@"Find synced lyrics" selector:@selector(requestLyrics)];
    self.body=[UITextView new];
    self.body.backgroundColor=UIColor.clearColor;
    self.body.textColor=UIColor.whiteColor;
    self.body.font=[UIFont systemFontOfSize:16];
    self.body.editable=NO;
    self.body.selectable=YES;
    self.body.scrollEnabled=YES;
    self.body.text=@"No lyrics loaded.";
    [self.stack addArrangedSubview:self.body];
    [self.body.heightAnchor constraintEqualToConstant:260].active=YES;
}
- (NSString *)cachePath:(NSString *)title artist:(NSString *)artist {
    NSString *string=[NSString stringWithFormat:@"%@-%@",title.lowercaseString,artist.lowercaseString];
    NSData *data=[string dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger h=1469598103934665603ULL;
    for (NSUInteger i=0;i<data.length;i++) { h^=((const uint8_t*)data.bytes)[i]; h*=1099511628211ULL; }
    return [[self storage] stringByAppendingPathComponent:[NSString stringWithFormat:@"lyrics-%llx.lrc",(unsigned long long)h]];
}
- (void)requestLyrics {
    NSString *title=[self.titleInput.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *artist=[self.artistInput.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self.titleInput resignFirstResponder];
    [self.artistInput resignFirstResponder];
    if (!title.length) { self.body.text=@"Enter the song title."; return; }
    self.selectedSong=title;
    NSString *cache=[self cachePath:title artist:artist ?: @""];
    NSString *saved=[NSString stringWithContentsOfFile:cache encoding:NSUTF8StringEncoding error:nil];
    if (saved.length) { [self consumeLyrics:saved]; return; }
    [self.lyricsRequest cancel];
    self.body.text=@"Searching LRCLIB…";
    NSURLComponents *url=[NSURLComponents componentsWithString:@"https://lrclib.net/api/get"];
    url.queryItems=@[
        [NSURLQueryItem queryItemWithName:@"track_name" value:title],
        [NSURLQueryItem queryItemWithName:@"artist_name" value:artist ?: @""]
    ];
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest=12;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config];
    __weak typeof(self) weak=self;
    self.lyricsRequest=[session dataTaskWithURL:url.URL completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSDictionary *json= data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *lrc=[json isKindOfClass:NSDictionary.class]?json[@"syncedLyrics"]:nil;
        NSString *plain=[json isKindOfClass:NSDictionary.class]?json[@"plainLyrics"]:nil;
        NSString *found=lrc.length ? lrc : plain;
        dispatch_async(dispatch_get_main_queue(), ^{
            MLEExtras *self2=weak;
            if (!self2 || ![self2.currentMode isEqualToString:@"Synced lyrics"]) return;
            if (!found.length) { self2.body.text=@"No matching lyrics found. Try a different title/artist. Apple subscription lyrics are not exposed by public MusicKit lyrics APIs."; return; }
            [found writeToFile:cache atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [self2 consumeLyrics:found];
        });
        [session finishTasksAndInvalidate];
    }];
    [self.lyricsRequest resume];
}
- (void)consumeLyrics:(NSString *)lyrics {
    self.rawLyrics=lyrics;
    NSMutableArray *items=[NSMutableArray array];
    NSRegularExpression *rx=[NSRegularExpression regularExpressionWithPattern:@"^\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]\\s*(.*)$" options:0 error:nil];
    NSArray *rows=[lyrics componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    for (NSString *row in rows) {
        NSTextCheckingResult *m=[rx firstMatchInString:row options:0 range:NSMakeRange(0,row.length)];
        if (!m || m.numberOfRanges<4) continue;
        double minutes=[[row substringWithRange:[m rangeAtIndex:1]] doubleValue];
        double seconds=[[row substringWithRange:[m rangeAtIndex:2]] doubleValue];
        NSString *text=[row substringWithRange:[m rangeAtIndex:3]];
        [items addObject:@{@"time":@(minutes*60+seconds),@"line":text}];
    }
    self.timedLines=items;
    if (!items.count) {
        self.body.text=lyrics;
        return;
    }
    [self updateTimedLyrics];
    self.lyricsTimer=[NSTimer scheduledTimerWithTimeInterval:.45 target:self
                              selector:@selector(updateTimedLyrics) userInfo:nil repeats:YES];
}
- (void)updateTimedLyrics {
    if (!self.body || ![self.currentMode isEqualToString:@"Synced lyrics"] || !self.timedLines.count) return;
    double t=self.localURL && self.localAudio.isPlaying ? self.localAudio.currentTime : self.audiblePlayer.currentPlaybackTime;
    NSInteger selected=-1;
    for(NSUInteger i=0;i<self.timedLines.count;i++) {
        if ([self.timedLines[i][@"time"] doubleValue] <= t) selected=(NSInteger)i;
        else break;
    }
    if (self.lastTimedIndex==selected) return;
    self.lastTimedIndex=selected;
    NSMutableAttributedString *render=[NSMutableAttributedString new];
    NSRange focus=NSMakeRange(0,0);
    for(NSUInteger i=0;i<self.timedLines.count;i++) {
        NSString *text=self.timedLines[i][@"line"];
        NSString *row=[NSString stringWithFormat:@"%@\n\n",text.length?text:@"♪"];
        NSRange range=NSMakeRange(render.length,row.length);
        UIColor *color=(NSInteger)i==selected?[UIColor colorWithRed:1 green:.33 blue:.43 alpha:1]:[UIColor colorWithWhite:.84 alpha:1];
        UIFont *font=[UIFont systemFontOfSize:16 weight:(NSInteger)i==selected?UIFontWeightBold:UIFontWeightRegular];
        [render appendAttributedString:[[NSAttributedString alloc] initWithString:row attributes:
                @{NSForegroundColorAttributeName:color,NSFontAttributeName:font}]];
        if((NSInteger)i==selected)focus=range;
    }
    self.body.attributedText=render;
    if (focus.length) [self.body scrollRangeToVisible:focus];
}
- (void)libraryPage {
    [self clearPage:@"Music library"];
    [self addBack];
    MPMediaLibraryAuthorizationStatus status=[MPMediaLibrary authorizationStatus];
    if (status==MPMediaLibraryAuthorizationStatusNotDetermined) {
        [self addText:@"This uses the user's existing iOS music library permission. No additional account is created."];
        [self addAction:@"Allow Music library access" selector:@selector(askLibrary)];
        return;
    }
    if (status!=MPMediaLibraryAuthorizationStatusAuthorized) {
        [self addText:@"Music library access is denied or restricted. Enable it in iOS Settings."];
        return;
    }
    NSArray *items=[[MPMediaQuery songsQuery] items];
    NSMutableSet *albums=[NSMutableSet set],*artists=[NSMutableSet set];
    for(MPMediaItem *song in items) {
        NSString *album=[song valueForProperty:MPMediaItemPropertyAlbumTitle];
        NSString *artist=[song valueForProperty:MPMediaItemPropertyArtist];
        if(album.length)[albums addObject:album];
        if(artist.length)[artists addObject:artist];
    }
    [self addText:[NSString stringWithFormat:@"Authorized device library\n%lu songs • %lu albums • %lu artists",
        (unsigned long)items.count,(unsigned long)albums.count,(unsigned long)artists.count]];
    [self addText:@"Library browsing remains in the original Apple Music interface. This panel only reads the user's permitted library."];
    [self addAction:@"Refresh library" selector:@selector(libraryPage)];
}
- (void)askLibrary {
    [MPMediaLibrary requestAuthorization:^(MPMediaLibraryAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self libraryPage]; });
    }];
}
- (void)importFile {
    NSArray *types=@[@"public.audio",@"public.mp3",@"public.mpeg-4-audio",@"com.microsoft.waveform-audio"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]
                            initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    picker.delegate=self;
    picker.allowsMultipleSelection=YES;
    UIViewController *root=self.window.rootViewController;
    while (root.presentedViewController) root=root.presentedViewController;
    [root presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSString *dir=[[self storage] stringByAppendingPathComponent:@"Audio"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    for(NSURL *url in urls) {
        NSString *extension=url.pathExtension.lowercaseString;
        if (![@[@"mp3",@"m4a",@"aac",@"wav",@"aif",@"aiff",@"caf"] containsObject:extension]) continue;
        NSString *base=url.lastPathComponent ?: @"song";
        NSString *dest=[dir stringByAppendingPathComponent:base];
        if ([NSFileManager.defaultManager fileExistsAtPath:dest]) {
            dest=[dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.%@",
                 url.URLByDeletingPathExtension.lastPathComponent,NSUUID.UUID.UUIDString,extension]];
        }
        BOOL access=[url startAccessingSecurityScopedResource];
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:nil];
        if(access)[url stopAccessingSecurityScopedResource];
    }
    [self filesPage];
}
- (NSArray<NSString *> *)audioFiles {
    NSString *dir=[[self storage] stringByAppendingPathComponent:@"Audio"];
    NSArray *files=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSMutableArray *filtered=[NSMutableArray array];
    for(NSString *n in files) if([@[@"mp3",@"m4a",@"aac",@"wav",@"aif",@"aiff",@"caf"] containsObject:n.pathExtension.lowercaseString]) [filtered addObject:n];
    return [filtered sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}
- (void)filesPage {
    [self clearPage:@"Imported music"];
    [self addBack];
    NSArray *files=[self audioFiles];
    [self addText:[NSString stringWithFormat:@"%lu imported audio files. Select a file to play it locally. This doesn't import DRM-protected Apple Music streams.",(unsigned long)files.count]];
    [self addAction:@"＋ Import more audio" selector:@selector(importFile)];
    if(self.localAudio) {
        [self addText:[NSString stringWithFormat:@"Current: %@ — %@",
            self.localURL.lastPathComponent,self.localAudio.isPlaying?@"Playing":@"Paused"]];
        [self addAction:self.localAudio.isPlaying?@"Pause local playback":@"Resume local playback" selector:@selector(toggleLocal)];
        [self addAction:@"Stop local playback" selector:@selector(stopLocal)];
    }
    NSUInteger index=0;
    for(NSString *filename in files) {
        if(index++>=50){[self addText:@"Showing first 50 files."];break;}
        UIButton *b=[self addAction:[NSString stringWithFormat:@"▶ %@",filename] selector:@selector(playFileButton:)];
        objc_setAssociatedObject(b, @selector(playFileButton:),filename,OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}
- (void)playFileButton:(UIButton *)sender {
    NSString *name=objc_getAssociatedObject(sender,@selector(playFileButton:));
    NSString *path=[[[self storage] stringByAppendingPathComponent:@"Audio"] stringByAppendingPathComponent:name];
    NSURL *url=[NSURL fileURLWithPath:path];
    NSError *error=nil;
    AVAudioPlayer *candidate=[[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if(!candidate || error) {[self addText:[NSString stringWithFormat:@"Can't decode this audio file: %@",error.localizedDescription ?: @"unsupported format"]];return;}
    [self.localAudio stop];self.localAudio=candidate;self.localURL=url;
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:nil];
    [AVAudioSession.sharedInstance setActive:YES error:nil];
    [self.localAudio prepareToPlay];
    [self.localAudio play];
    [self filesPage];
}
- (void)toggleLocal {
    if(self.localAudio.isPlaying)[self.localAudio pause];else[self.localAudio play];
    [self filesPage];
}
- (void)stopLocal {
    [self.localAudio stop];self.localAudio=nil;self.localURL=nil;
    [self filesPage];
}
- (void)infoPage {
    [self clearPage:@"Music Extras info"];
    [self addBack];
    [self addText:@"Preserves Apple Music's existing tabs, library browsing, subscription, and original playback routes."];
    [self addText:@"Available:\n• On-demand synced LRCLIB lyrics, cached locally\n• Synchronized line highlighting when a playback position is exposed\n• Music library permission and counts\n• Native audio file import and local play/pause\n• Side-by-side system/application playback snapshots"];
    [self addText:@"Not integrated into the original compiled UI: independent MusicKit playback, Navidrome/Jellyfin sign-in, EQ, mutable system playlists, advanced metadata editing, automatic Apple subscription lyrics, or the old Music app's internal Not Playing bug."];
    [self addText:@"Imported music is under Documents/MusicExtras/Audio. Lyrics cache is in Documents/MusicExtras."];
}
@end

__attribute__((constructor))
static void MLEStartExtras(void) {
    // No Music/MediaRemote calls happen at load time.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
         object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
             [[MLEExtras shared] triggerAttach];
         }];
        [[MLEExtras shared] triggerAttach];
    });
}

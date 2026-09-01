#import "BTMetadataService.h"

static id BTJSONAtURL(NSURL *url, NSString **errorOut) {
    if (!url) return nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10.0];
    [request setValue:@"ByeTunes16/0.2 (iOS 16)" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *response, NSError *e) {
        (void)response;
        data = d;
        error = e;
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC)) != 0) {
        [task cancel];
        if (errorOut) *errorOut = @"Metadata request timed out";
        return nil;
    }
    if (error || !data.length) {
        if (errorOut) *errorOut = error.localizedDescription ?: @"Metadata provider returned no data";
        return nil;
    }
    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!json && errorOut) *errorOut = jsonError.localizedDescription;
    return json;
}

static NSString *BTYear(id releaseDate) {
    if (![releaseDate isKindOfClass:NSString.class] || [(NSString *)releaseDate length] < 4) return @"";
    NSString *year = [(NSString *)releaseDate substringToIndex:4];
    return [year rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound ? year : @"";
}

static NSDictionary *BTAppleCandidate(NSDictionary *r) {
    NSString *title = [r[@"trackName"] isKindOfClass:NSString.class] ? r[@"trackName"] : @"";
    NSString *artist = [r[@"artistName"] isKindOfClass:NSString.class] ? r[@"artistName"] : @"";
    if (!title.length || !artist.length) return nil;
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:@{
        @"source": @"Apple/iTunes",
        @"title": title,
        @"artist": artist,
        @"album": [r[@"collectionName"] isKindOfClass:NSString.class] ? r[@"collectionName"] : @"",
        @"genre": [r[@"primaryGenreName"] isKindOfClass:NSString.class] ? r[@"primaryGenreName"] : @"",
        @"year": BTYear(r[@"releaseDate"]),
        @"track": [r[@"trackNumber"] respondsToSelector:@selector(stringValue)] ? [r[@"trackNumber"] stringValue] : @"",
        @"disc": [r[@"discNumber"] respondsToSelector:@selector(stringValue)] ? [r[@"discNumber"] stringValue] : @""
    }];
    NSString *art = [r[@"artworkUrl100"] isKindOfClass:NSString.class] ? r[@"artworkUrl100"] : nil;
    if (art.length) {
        art = [art stringByReplacingOccurrencesOfString:@"100x100bb" withString:@"600x600bb"];
        m[@"artworkURL"] = art;
    }
    if ([r[@"trackId"] respondsToSelector:@selector(stringValue)]) m[@"storeId"] = [r[@"trackId"] stringValue];
    return m;
}

static NSDictionary *BTDeezerCandidate(NSDictionary *r) {
    NSString *title = [r[@"title"] isKindOfClass:NSString.class] ? r[@"title"] : @"";
    NSDictionary *artistObj = [r[@"artist"] isKindOfClass:NSDictionary.class] ? r[@"artist"] : @{};
    NSDictionary *albumObj = [r[@"album"] isKindOfClass:NSDictionary.class] ? r[@"album"] : @{};
    NSString *artist = [artistObj[@"name"] isKindOfClass:NSString.class] ? artistObj[@"name"] : @"";
    if (!title.length || !artist.length) return nil;
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:@{
        @"source": @"Deezer",
        @"title": title,
        @"artist": artist,
        @"album": [albumObj[@"title"] isKindOfClass:NSString.class] ? albumObj[@"title"] : @"",
        @"genre": @"",
        @"year": @"",
        @"track": @"",
        @"disc": @""
    }];
    NSString *art = [albumObj[@"cover_xl"] isKindOfClass:NSString.class] ? albumObj[@"cover_xl"] : nil;
    if (!art.length) art = [albumObj[@"cover_big"] isKindOfClass:NSString.class] ? albumObj[@"cover_big"] : nil;
    if (art.length) m[@"artworkURL"] = art;
    if ([r[@"id"] respondsToSelector:@selector(stringValue)]) m[@"providerId"] = [r[@"id"] stringValue];
    return m;
}

@implementation BTMetadataService

+ (NSDictionary *)search:(NSString *)query {
    NSString *trimmed = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) return @{ @"ok": @NO, @"error": @"Metadata query is empty" };
    NSString *encoded = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    if (!encoded.length) return @{ @"ok": @NO, @"error": @"Could not encode metadata query" };

    NSMutableArray *results = [NSMutableArray array];
    NSMutableArray *providerErrors = [NSMutableArray array];

    NSString *appleError = nil;
    NSURL *appleURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?term=%@&entity=song&limit=8", encoded]];
    NSDictionary *apple = BTJSONAtURL(appleURL, &appleError);
    if ([apple isKindOfClass:NSDictionary.class]) {
        NSArray *rows = [apple[@"results"] isKindOfClass:NSArray.class] ? apple[@"results"] : @[];
        for (NSDictionary *row in rows) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *candidate = BTAppleCandidate(row);
            if (candidate) [results addObject:candidate];
        }
    } else if (appleError.length) {
        [providerErrors addObject:[NSString stringWithFormat:@"Apple/iTunes: %@", appleError]];
    }

    NSString *deezerError = nil;
    NSURL *deezerURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.deezer.com/search?q=%@&limit=8", encoded]];
    NSDictionary *deezer = BTJSONAtURL(deezerURL, &deezerError);
    if ([deezer isKindOfClass:NSDictionary.class]) {
        NSArray *rows = [deezer[@"data"] isKindOfClass:NSArray.class] ? deezer[@"data"] : @[];
        for (NSDictionary *row in rows) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *candidate = BTDeezerCandidate(row);
            if (!candidate) continue;
            BOOL duplicate = NO;
            for (NSDictionary *existing in results) {
                if ([existing[@"title"] caseInsensitiveCompare:candidate[@"title"]] == NSOrderedSame &&
                    [existing[@"artist"] caseInsensitiveCompare:candidate[@"artist"]] == NSOrderedSame &&
                    [existing[@"album"] caseInsensitiveCompare:candidate[@"album"]] == NSOrderedSame) { duplicate = YES; break; }
            }
            if (!duplicate) [results addObject:candidate];
        }
    } else if (deezerError.length) {
        [providerErrors addObject:[NSString stringWithFormat:@"Deezer: %@", deezerError]];
    }

    if (results.count > 16) [results removeObjectsInRange:NSMakeRange(16, results.count - 16)];
    return @{ @"ok": @YES, @"query": trimmed, @"results": results, @"providerErrors": providerErrors };
}

@end

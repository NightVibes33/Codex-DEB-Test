#!/usr/bin/env bash
set -euo pipefail

: "${IPAD_HOST:?missing IPAD_HOST}"
: "${IPAD_PASSWORD:?missing IPAD_PASSWORD}"
export SSHPASS="$IPAD_PASSWORD"
export THEOS=/opt/theos
LOG="official-exit-v3.txt"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== BUILD RUNTIME-LINKED PALERA1N EXIT HELPER ==="
sudo apt-get update
sudo apt-get install -y --no-install-recommends bash curl build-essential git ca-certificates file openssh-client sshpass
sudo rm -rf "$THEOS"
sudo mkdir -p /opt
sudo chown "$USER:$USER" /opt
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

mkdir -p exitpalev3
cat > exitpalev3/Makefile <<'MK'
ARCHS = arm64
TARGET = iphone:clang:latest:15.0
TOOL_NAME = exitpalev3
exitpalev3_FILES = main.c
exitpalev3_CFLAGS = -fblocks -Wall -Wextra
exitpalev3_CODESIGN_FLAGS = -Sentitlements.plist
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tool.mk
MK

cat > exitpalev3/main.c <<'CC'
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

    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        (void)event;
    });
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

cat > exitpalev3/entitlements.plist <<'PLIST'
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

make -C exitpalev3 clean all FINALPACKAGE=1
HELPER="$(find exitpalev3/.theos -type f -name exitpalev3 -perm -111 | head -n1)"
test -n "$HELPER"
cp "$HELPER" exitpale-v3
chmod 0755 exitpale-v3
file exitpale-v3 | grep -q arm64
echo "helper_build=success"

echo "=== WAIT FOR IPAD SSH ==="
connected=0
for attempt in $(seq 1 48); do
  if sshpass -e ssh -p 22 -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      mobile@"$IPAD_HOST" true >/dev/null 2>&1; then
    connected=1
    break
  fi
  sleep 5
done
test "$connected" -eq 1

sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  exitpale-v3 mobile@"$IPAD_HOST":/var/mobile/Media/exitpale-v3

cat > prepare-v3.sh <<'SH'
#!/bin/sh
set -eu
media="/var/mobile/Library/Application Support/Gif2Ani"
prefs="/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist"
marker="/var/mobile/Media/gif2ani-official-exit-v3.marker"
test "$(dpkg-query -W com.nightvibes33.gif2ani | cut -f2)" = "3.1.1"
mkdir -p "$media"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict>' \
  '  <key>isEnabled</key><false/>' \
  '  <key>pendingReady</key><false/>' \
  '  <key>imageTransformation</key><string>resizeAspect</string>' \
  '  <key>customLoop</key><real>-1</real>' \
  '  <key>customDuration</key><real>-1</real>' \
  '  <key>backgroundColor</key><string>#000000</string>' \
  '</dict></plist>' > "$prefs"
chown mobile:mobile "$media" "$prefs"
chmod 0755 "$media"
chmod 0644 "$prefs"
chmod 0755 /var/mobile/Media/exitpale-v3
rm -f "$media/Pending.gif" "$media/Active.gif" "$media/Rejected.gif" "$media/load-in-progress" "$media/runtime-status.plist"
touch "$marker"
echo "prepared_disabled_clean_state=yes"
SH
chmod +x prepare-v3.sh
sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  prepare-v3.sh mobile@"$IPAD_HOST":/var/mobile/Media/
printf '%s\n' "$IPAD_PASSWORD" | sshpass -e ssh -p 22 -o ConnectTimeout=20 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null mobile@"$IPAD_HOST" \
  'sudo -S -p "" sh /var/mobile/Media/prepare-v3.sh'

echo "=== SEND OFFICIAL PALERA1N EXIT SAFE MODE COMMAND ==="
set +e
printf '%s\n' "$IPAD_PASSWORD" | sshpass -e ssh -p 22 -o ConnectTimeout=20 \
  -o ServerAliveInterval=3 -o ServerAliveCountMax=2 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null mobile@"$IPAD_HOST" \
  'sudo -S -p "" /var/mobile/Media/exitpale-v3'
exit_code=$?
set -e
echo "exit_command_ssh_exit=$exit_code"
if [[ "$exit_code" -ne 0 && "$exit_code" -ne 255 ]]; then
  exit "$exit_code"
fi

echo "=== WAIT FOR IPAD AFTER OFFICIAL EXIT ==="
sleep 10
connected=0
for attempt in $(seq 1 72); do
  if sshpass -e ssh -p 22 -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      mobile@"$IPAD_HOST" true >/dev/null 2>&1; then
    connected=1
    break
  fi
  sleep 5
done
echo "reconnected_after_official_exit=$connected"
test "$connected" -eq 1
sleep 10

cat > verify-v3.sh <<'SH'
#!/bin/sh
set -eu
media="/var/mobile/Library/Application Support/Gif2Ani"
marker="/var/mobile/Media/gif2ani-official-exit-v3.marker"
test "$(dpkg-query -W com.nightvibes33.gif2ani | cut -f2)" = "3.1.1"
test ! -e "$media/Pending.gif"
test ! -e "$media/Active.gif"
test ! -e "$media/Rejected.gif"
test ! -e "$media/load-in-progress"
test -f "$media/runtime-status.plist"
cat "$media/runtime-status.plist"
grep -a -q 'tweak-loaded-no-media-decode' "$media/runtime-status.plist"
crashes=$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f \( -name 'backboardd-*.ips' -o -name 'SpringBoard-*.ips' \) -newer "$marker" -print 2>/dev/null | wc -l | tr -d ' ')
echo "crashes_after_official_exit=$crashes"
test "$crashes" = "0"
echo "official_exit_and_normal_injection=success"
ps ax | grep -E '[b]ackboardd|[S]pringBoard' || true
SH
chmod +x verify-v3.sh
sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  verify-v3.sh mobile@"$IPAD_HOST":/var/mobile/Media/
printf '%s\n' "$IPAD_PASSWORD" | sshpass -e ssh -p 22 -o ConnectTimeout=20 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null mobile@"$IPAD_HOST" \
  'sudo -S -p "" sh /var/mobile/Media/verify-v3.sh'

echo "v3_result=success"

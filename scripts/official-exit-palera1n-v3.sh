#!/usr/bin/env bash
set -euo pipefail

: "${IPAD_HOST:?missing IPAD_HOST}"
: "${IPAD_PASSWORD:?missing IPAD_PASSWORD}"
export SSHPASS="$IPAD_PASSWORD"
LOG="official-exit-v3.txt"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== BUILD OFFICIAL PALERA1N EXIT HELPER ==="
sudo apt-get update
sudo apt-get install -y --no-install-recommends bash curl git ca-certificates file openssh-client sshpass
sudo rm -rf /opt/theos
sudo mkdir -p /opt
sudo chown "$USER:$USER" /opt
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

echo "=== INSTALLED SDKS ==="
ls -la /opt/theos/sdks || true
SDK="$(ls -d /opt/theos/sdks/iPhoneOS*.sdk 2>/dev/null | sort -V | tail -n1 || true)"
if [[ -z "$SDK" ]]; then
  echo "iphoneos_sdk=missing"
  exit 80
fi
CLANG=/opt/theos/toolchain/linux/iphone/bin/clang
LDID=/opt/theos/bin/ldid
XPC_TBD="$SDK/usr/lib/system/libxpc.tbd"
echo "selected_sdk=$SDK"
echo "xpc_tbd=$XPC_TBD"
test -x "$CLANG"
test -x "$LDID"
test -f "$XPC_TBD"

cat > exitpale-v3.c <<'CC'
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef void *xpc_object_t;
typedef void *xpc_connection_t;
typedef const void *xpc_type_t;
typedef void (^xpc_handler_t)(xpc_object_t);

extern const struct _xpc_type_s _xpc_type_error;
#define XPC_TYPE_ERROR ((xpc_type_t)&_xpc_type_error)

extern xpc_connection_t xpc_connection_create_mach_service(const char *, void *, uint64_t);
extern void xpc_connection_set_event_handler(xpc_connection_t, xpc_handler_t);
extern void xpc_connection_activate(xpc_connection_t);
extern void xpc_connection_cancel(xpc_connection_t);
extern xpc_object_t xpc_connection_send_message_with_reply_sync(xpc_connection_t, xpc_object_t);
extern xpc_object_t xpc_dictionary_create(const char * const *, const xpc_object_t *, size_t);
extern void xpc_dictionary_set_uint64(xpc_object_t, const char *, uint64_t);
extern int64_t xpc_dictionary_get_int64(xpc_object_t, const char *);
extern const char *xpc_dictionary_get_string(xpc_object_t, const char *);
extern xpc_type_t xpc_get_type(xpc_object_t);
extern void xpc_release(xpc_object_t);

int main(void) {
    const uint64_t JBD_CMD_EXIT_SAFE_MODE = 10;
    xpc_connection_t connection = xpc_connection_create_mach_service(
        "in.palera.palera1nd.systemwide", NULL, 0
    );
    if (connection == NULL || xpc_get_type(connection) == XPC_TYPE_ERROR) {
        fprintf(stderr, "connection_create_failed\n");
        return 70;
    }
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) { (void)event; });
    xpc_connection_activate(connection);
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    if (request == NULL) {
        xpc_connection_cancel(connection);
        xpc_release(connection);
        fprintf(stderr, "request_create_failed\n");
        return 72;
    }
    xpc_dictionary_set_uint64(request, "cmd", JBD_CMD_EXIT_SAFE_MODE);
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, request);
    xpc_release(request);
    xpc_connection_cancel(connection);
    xpc_release(connection);
    if (reply == NULL || xpc_get_type(reply) == XPC_TYPE_ERROR) {
        fprintf(stderr, "xpc_reply_error\n");
        if (reply != NULL) xpc_release(reply);
        return 71;
    }
    int64_t error = xpc_dictionary_get_int64(reply, "error");
    const char *message = xpc_dictionary_get_string(reply, "message");
    const char *description = xpc_dictionary_get_string(reply, "errorDescription");
    printf("jailbreakd_error=%lld\n", (long long)error);
    if (message) printf("jailbreakd_message=%s\n", message);
    if (description) printf("jailbreakd_error_description=%s\n", description);
    xpc_release(reply);
    return error == 0 ? 0 : (int)error;
}
CC

cat > entitlements-v3.plist <<'PLIST'
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
  exitpale-v3.c "$XPC_TBD" -framework CoreFoundation -o exitpale-v3
"$LDID" -Sentitlements-v3.plist exitpale-v3
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

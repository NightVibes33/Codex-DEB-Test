#!/bin/sh
set -u
export PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
BASE=https://github.com/NightVibes33/Codex-DEB-Test/releases/download/lc-felix-device-test-v1
LC_IPA=/var/mobile/Media/LiveContainer-32bit-fresh-unsigned.ipa
FELIX_IPA=/var/mobile/Media/com.disney.FixItFelixJr-iOS4.3-Clutch-2.0.4.ipa
LC_SHA=db3fe97266f2f2e4221b5bbc29f09373fa1d22315cb7aa1ccc6afe41d5d4af82
FELIX_SHA=fb79424ba92e1077213cffc637f9f8c8d2205ccfc39a2c6bc020098460f30f04
BUNDLE=com.nightvibes33.livecontainer
UICACHE=/var/jb/usr/bin/uicache

echo ===INSTALL_LIVECONTAINER_AND_FELIX===
fetch() { url="$1"; out="$2"; rm -f "$out"; curl -L --fail --retry 3 -o "$out" "$url" || wget -O "$out" "$url"; }
find_helper() {
  for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
}
fetch "$BASE/LiveContainer-32bit-fresh-unsigned.ipa" "$LC_IPA"
fetch "$BASE/com.disney.FixItFelixJr-iOS4.3-Clutch-2.0.4.ipa" "$FELIX_IPA"
sha256sum "$LC_IPA" | grep -Fq "$LC_SHA" || { echo LC_HASH_FAILED=1; exit 70; }
sha256sum "$FELIX_IPA" | grep -Fq "$FELIX_SHA" || { echo FELIX_HASH_FAILED=1; exit 71; }
echo IPA_HASHES_OK=1
H="$(find_helper)"; echo trollstorehelper="$H"; [ -n "$H" ] || exit 72
"$H" install force "$LC_IPA"; [ $? -eq 0 ] || exit 73
"$H" refresh || true
sleep 5
LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
echo registration="$LINE"
HOST="${LINE#* : }"
[ -d "$HOST" ] || { echo HOST_NOT_FOUND=1; exit 74; }
DATA=
for meta in $(find /private/var/mobile/Containers/Data/Application /var/mobile/Containers/Data/Application -name .com.apple.mobile_container_manager.metadata.plist 2>/dev/null); do
  if plutil -p "$meta" 2>/dev/null | grep -Fq "$BUNDLE" || grep -aqF "$BUNDLE" "$meta"; then DATA="$(dirname "$meta")"; break; fi
done
echo data_container="$DATA"
[ -n "$DATA" ] || { echo DATA_NOT_FOUND=1; exit 75; }
APPS="$DATA/Documents/Applications"
mkdir -p "$APPS"
rm -rf "$APPS/LiveExec32.app" "$APPS/com.disney.FixItFelixJr.app" /var/mobile/Media/felix-stage
cp -R "$HOST/LiveExec32.app" "$APPS/LiveExec32.app" || exit 76
mkdir -p /var/mobile/Media/felix-stage
unzip -q "$FELIX_IPA" -d /var/mobile/Media/felix-stage || exit 77
SRC="$(find /var/mobile/Media/felix-stage/Payload -maxdepth 1 -type d -name '*.app' | head -n 1)"
[ -d "$SRC" ] || exit 78
echo felix_source="$SRC"
ls -ld "$SRC" 2>&1 || true
mv "$SRC" "$APPS/com.disney.FixItFelixJr.app" || exit 79
chown -R mobile:mobile "$APPS/LiveExec32.app" "$APPS/com.disney.FixItFelixJr.app" 2>/dev/null || true
chmod -R u+rwX "$APPS/LiveExec32.app" "$APPS/com.disney.FixItFelixJr.app"
echo LIVEEXEC_INSTALLED="$(test -x "$APPS/LiveExec32.app/LiveExec32" && echo 1 || echo 0)"
echo FELIX_INSTALLED="$(test -x "$APPS/com.disney.FixItFelixJr.app/FixItFelixJr" && echo 1 || echo 0)"
URL='livecontainer://livecontainer-launch?bundle-name=com.disney.FixItFelixJr.app'
if command -v uiopen >/dev/null 2>&1; then uiopen "$URL"; elif command -v open >/dev/null 2>&1; then open "$URL"; else echo NO_UIOPEN=1; exit 80; fi
sleep 20
echo ===PROCESS_STATE===
ps ax | grep -E 'LiveContainer|LiveExec32|FixItFelix' | grep -v grep || true
echo ===RECENT_CRASH_FILES===
find /var/mobile/Library/Logs/CrashReporter -type f -mmin -5 2>/dev/null | tail -20
echo DEVICE_INSTALL_AND_LAUNCH_COMPLETE=1

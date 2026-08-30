#!/bin/bash
set -euo pipefail

: "${URL:=https://updates.cdn-apple.com/2026SpringSeed/ad5a4f9d-f005-466b-bbcf-3b466040074b/iPhone17,3_27.0_24A5424a_Restore.ipsw}"
: "${OUT:=full-ui-probe}"
: "${EXTRACT_SYSTEM_DMG:=0}"

mkdir -p "$OUT"
REPORT="$OUT/report.txt"
FILES="$OUT/remote-files.txt"

exec > >(tee "$REPORT") 2>&1

echo "darwin-vm full UI probe"
echo "URL=$URL"
echo "host=$(uname -a)"
echo "ipsw=$(command -v ipsw || true)"
ipsw version || ipsw --version || true

echo
echo "== Remote IPSW inventory =="
ipsw info --remote "$URL" --list | tee "$FILES"

echo
echo "== Candidate system/UI payloads =="
grep -Ei '(^|/)(SystemOS|Filesystem|RestoreRamDisk|.*\.dmg|.*\.aea)$|SpringBoard|backboard|WindowServer|DCP|AGX|wlan|wifi|bluetooth' "$FILES" || true

if [[ "$EXTRACT_SYSTEM_DMG" != "1" ]]; then
  echo
echo "System DMG extraction skipped (EXTRACT_SYSTEM_DMG=$EXTRACT_SYSTEM_DMG)."
  exit 0
fi

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Full filesystem mounting requires macOS."
  exit 0
fi

echo
echo "== Extract filesystem DMG =="
mkdir -p "$OUT/fs"
set +e
ipsw extract --remote "$URL" --output "$OUT/fs" --flat -j --dmg fs > "$OUT/fs-extract.json" 2> "$OUT/fs-extract.stderr"
RC=$?
set -e
cat "$OUT/fs-extract.stderr" || true
cat "$OUT/fs-extract.json" || true
if [[ $RC -ne 0 ]]; then
  echo "ipsw --dmg fs failed with rc=$RC; inventory remains useful."
  exit 0
fi

DMG="$(find "$OUT/fs" -type f \( -name '*.dmg' -o -name '*.aea' \) -print | head -n1 || true)"
if [[ -z "$DMG" ]]; then
  echo "No filesystem image was materialized."
  find "$OUT/fs" -maxdepth 2 -type f -ls || true
  exit 0
fi

echo "filesystem image: $DMG"
if [[ "$DMG" == *.aea ]]; then
  echo "Filesystem remained AEA-encrypted; mount probe cannot continue yet."
  exit 0
fi

MNT="$(mktemp -d)"
cleanup() {
  hdiutil detach "$MNT" >/dev/null 2>&1 || true
  rmdir "$MNT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! hdiutil attach -readonly -nobrowse -mountpoint "$MNT" "$DMG"; then
  echo "hdiutil could not mount filesystem image."
  exit 0
fi

echo
echo "== UI/service presence =="
probe_path() {
  local label="$1"; shift
  local found=0
  for p in "$@"; do
    if [[ -e "$MNT/$p" ]]; then
      echo "PRESENT $label: /$p"
      found=1
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "MISSING $label"
  fi
}

probe_path SpringBoard \
  'System/Library/CoreServices/SpringBoard.app' \
  'System/Library/CoreServices/SpringBoard.app/SpringBoard'
probe_path backboardd \
  'usr/libexec/backboardd' \
  'System/Library/PrivateFrameworks/BackBoardServices.framework'
probe_path WindowServer \
  'System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer' \
  'System/Library/CoreServices/WindowServer'
probe_path wifid \
  'usr/sbin/wifid' \
  'usr/libexec/wifid'
probe_path bluetoothd \
  'usr/sbin/bluetoothd' \
  'usr/libexec/bluetoothd'

echo
echo "== Graphics / input / wireless driver candidates =="
find "$MNT/System/Library" -maxdepth 5 \( -iname '*AGX*' -o -iname '*DCP*' -o -iname '*Display*' -o -iname '*Multitouch*' -o -iname '*Touch*' -o -iname '*WLAN*' -o -iname '*WiFi*' -o -iname '*Bluetooth*' \) -print 2>/dev/null | head -n 500 || true

echo
echo "== Launch service candidates =="
find "$MNT/System/Library/LaunchDaemons" -maxdepth 1 -type f \( -iname '*backboard*' -o -iname '*springboard*' -o -iname '*window*' -o -iname '*wifi*' -o -iname '*wlan*' -o -iname '*bluetooth*' \) -print 2>/dev/null || true

echo
echo "probe complete"

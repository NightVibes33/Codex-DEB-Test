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

# Modern IPSWs ship their filesystem as an Apple Encrypted Archive (.dmg.aea).
# Current ipsw releases know the AEA FCS keys; ask ipsw to unwrap it before
# falling back to selective filesystem extraction.
if [[ "$DMG" == *.aea ]]; then
  echo
echo "== Decrypt AEA filesystem =="
  mkdir -p "$OUT/decrypted"
  set +e
  ipsw fw aea "$DMG" --output "$OUT/decrypted" > "$OUT/aea-decrypt.stdout" 2> "$OUT/aea-decrypt.stderr"
  AEA_RC=$?
  set -e
  cat "$OUT/aea-decrypt.stdout" || true
  cat "$OUT/aea-decrypt.stderr" || true

  DECRYPTED="$(find "$OUT/decrypted" -type f -name '*.dmg' -print | head -n1 || true)"
  if [[ $AEA_RC -eq 0 && -n "$DECRYPTED" ]]; then
    DMG="$DECRYPTED"
    echo "decrypted filesystem image: $DMG"
  else
    echo "Direct AEA unwrap did not produce a DMG (rc=$AEA_RC)."
    echo "Trying ipsw's filesystem-aware selective extraction path."
    mkdir -p "$OUT/selected"
    UI_PATTERN='SpringBoard\.app(/SpringBoard)?$|/backboardd$|/bluetoothd$|/wifid$|BackBoardServices\.framework|AppleParavirt(GPU|Display)|AppleVirtIO|AppleVirtualPlatform'
    set +e
    ipsw extract --remote --files --pattern "$UI_PATTERN" \
      --output "$OUT/selected" "$URL" > "$OUT/selective-extract.stdout" 2> "$OUT/selective-extract.stderr"
    SELECT_RC=$?
    set -e
    cat "$OUT/selective-extract.stdout" || true
    cat "$OUT/selective-extract.stderr" || true
    echo "selective extraction rc=$SELECT_RC"
    find "$OUT/selected" -type f -print 2>/dev/null | sed "s#^$OUT/selected/##" | tee "$OUT/selected-files.txt" || true
    if [[ ! -s "$OUT/selected-files.txt" ]]; then
      echo "No selected UI files were extracted."
    fi
    # Do not keep extracted Apple binaries in the CI artifact; the report and
    # relative file list are sufficient for the probe.
    rm -rf "$OUT/selected"
    exit 0
  fi
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
find "$MNT/System/Library" -maxdepth 5 \( -iname '*AGX*' -o -iname '*DCP*' -o -iname '*Paravirt*' -o -iname '*VirtIO*' -o -iname '*Display*' -o -iname '*Multitouch*' -o -iname '*Touch*' -o -iname '*WLAN*' -o -iname '*WiFi*' -o -iname '*Bluetooth*' \) -print 2>/dev/null | head -n 500 || true

echo
echo "== Launch service candidates =="
find "$MNT/System/Library/LaunchDaemons" -maxdepth 1 -type f \( -iname '*backboard*' -o -iname '*springboard*' -o -iname '*window*' -o -iname '*wifi*' -o -iname '*wlan*' -o -iname '*bluetooth*' \) -print 2>/dev/null || true

echo
echo "probe complete"

#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

OUT=/var/mobile/Media/PowerNFC-analysis.txt
IPA=/var/mobile/Media/PowerNFC-TestFlight.ipa
TMP=/var/mobile/Media/.powernfc-extract-$$
rm -f "$OUT" "$IPA"
rm -rf "$TMP"

{
echo '=== POWERNFC TESTFLIGHT EXTRACTION ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'machine='; uname -m 2>/dev/null || true
echo

echo '=== FAST APP DISCOVERY ==='
APP=''

echo '[1] bundle-directory names'
for p in /var/containers/Bundle/Application/*/*.app; do
  [ -d "$p" ] || continue
  base="$(basename "$p" | tr '[:upper:]' '[:lower:]')"
  case "$base" in
    *powernfc*|*power*nfc*) APP="$p"; break ;;
  esac
done
echo "directory_match=${APP:-NONE}"

if [ -z "$APP" ] && command -v uicache >/dev/null 2>&1; then
  echo '[2] uicache registry'
  uicache -l 2>/dev/null | grep -Ei -A2 -B2 'PowerNFC|power.*nfc' | head -n 80 || true
fi

if [ -z "$APP" ]; then
  echo '[3] Info.plist raw-string scan'
  for plist in /var/containers/Bundle/Application/*/*.app/Info.plist; do
    [ -f "$plist" ] || continue
    if strings "$plist" 2>/dev/null | grep -Eqi 'PowerNFC|power.*nfc'; then
      APP="$(dirname "$plist")"
      break
    fi
  done
fi
echo "final_app_match=${APP:-NONE}"

echo
echo '=== TESTFLIGHT DISCOVERY ==='
TF=''
for p in /var/containers/Bundle/Application/*/TestFlight.app; do
  [ -d "$p" ] && { TF="$p"; break; }
done
if [ -z "$TF" ]; then
  for plist in /var/containers/Bundle/Application/*/*.app/Info.plist; do
    [ -f "$plist" ] || continue
    if strings "$plist" 2>/dev/null | grep -Fqi 'com.apple.TestFlight'; then
      TF="$(dirname "$plist")"
      break
    fi
  done
fi
echo "testflight_app=${TF:-NOT_FOUND}"
echo "uiopen=$(command -v uiopen 2>/dev/null || true)"
echo "open=$(command -v open 2>/dev/null || true)"

if [ -z "$APP" ]; then
  echo 'powernfc_installed=NO'
  echo 'powernfc_extract_status=NOT_INSTALLED'
  echo '=== EXTRACTION SCRIPT COMPLETE ==='
  exit 0
fi

echo
echo '=== APP METADATA ==='
echo 'powernfc_installed=YES'
echo "app_path=$APP"
PLIST="$APP/Info.plist"

# Prefer PlistBuddy/plutil if available, but never loop over the whole app registry with it.
BID="$(plutil -extract CFBundleIdentifier raw -o - "$PLIST" 2>/dev/null)"
NAME="$(plutil -extract CFBundleDisplayName raw -o - "$PLIST" 2>/dev/null)"
[ -n "$NAME" ] || NAME="$(plutil -extract CFBundleName raw -o - "$PLIST" 2>/dev/null)"
VER="$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST" 2>/dev/null)"
BUILD="$(plutil -extract CFBundleVersion raw -o - "$PLIST" 2>/dev/null)"
EXE="$(plutil -extract CFBundleExecutable raw -o - "$PLIST" 2>/dev/null)"

# Fallback parser for iOS plutil variants that do not support -extract.
if [ -z "$BID" ] || [ -z "$EXE" ]; then
  PJSON="$(plutil -convert json -o - "$PLIST" 2>/dev/null)"
  if [ -n "$PJSON" ] && command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$PJSON" | python3 -c 'import json,sys,shlex; d=json.load(sys.stdin); keys=["CFBundleIdentifier","CFBundleDisplayName","CFBundleName","CFBundleShortVersionString","CFBundleVersion","CFBundleExecutable"]; print("\n".join(k+"="+shlex.quote(str(d.get(k,""))) for k in keys))' 2>/dev/null)"
    BID="$CFBundleIdentifier"
    [ -n "$NAME" ] || NAME="${CFBundleDisplayName:-$CFBundleName}"
    VER="$CFBundleShortVersionString"
    BUILD="$CFBundleVersion"
    EXE="$CFBundleExecutable"
  fi
fi

BIN="$APP/$EXE"
echo "bundle_id=$BID"
echo "display_name=$NAME"
echo "version=$VER"
echo "build=$BUILD"
echo "executable=$EXE"
echo "binary=$BIN"

echo
echo '=== INFO.PLIST ==='
plutil -p "$PLIST" 2>/dev/null | head -n 500 || strings "$PLIST" 2>/dev/null | head -n 500 || true

echo
echo '=== ENTITLEMENTS ==='
if command -v ldid >/dev/null 2>&1 && [ -f "$BIN" ]; then
  ldid -e "$BIN" 2>&1 | head -n 800 || true
else
  echo 'ldid_or_binary=NOT_AVAILABLE'
fi

echo
echo '=== MACH-O / ENCRYPTION ==='
if command -v otool >/dev/null 2>&1 && [ -f "$BIN" ]; then
  otool -L "$BIN" 2>&1 | head -n 500 || true
  otool -l "$BIN" 2>/dev/null | grep -E -A4 -B2 'LC_ENCRYPTION_INFO|LC_ENCRYPTION_INFO_64|cryptid' | head -n 100 || true
else
  echo 'otool_or_binary=NOT_AVAILABLE'
fi

echo
echo '=== EMBEDDED FRAMEWORKS / EXTENSIONS ==='
find "$APP" -maxdepth 4 \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' \) -print 2>/dev/null | sort | head -n 500 || true

echo
echo '=== HIGH-VALUE STRINGS ==='
if command -v strings >/dev/null 2>&1 && [ -f "$BIN" ]; then
  strings -a "$BIN" 2>/dev/null | grep -Ei 'AirTraffic|Grappa|MobileBackup|MobileRestore|BackupAgent|bookassetd|itunesstored|AFC|lockdown|RemoteXPC|RPPairing|remotepairing|RSD|syslog|passd|Passbook|Stockholm|/var/mobile/Library/Passes|Cards/|pairing.*plist|SparseRestore|BookRestore|restore|MobileDevice|Developer Mode|LocalDevVPN|Wallet' | head -n 1200 || true
fi

echo
echo '=== PACKAGE RAW INSTALLED APP AS IPA ==='
mkdir -p "$TMP/Payload"
cp -a "$APP" "$TMP/Payload/" 2>&1
RC=127
if command -v zip >/dev/null 2>&1; then
  (cd "$TMP" && zip -qry "$IPA" Payload)
  RC=$?
elif command -v python3 >/dev/null 2>&1; then
  (cd "$TMP" && python3 -m zipfile -c "$IPA" Payload)
  RC=$?
fi
rm -rf "$TMP"

if [ "$RC" -eq 0 ] && [ -s "$IPA" ]; then
  chmod 644 "$IPA" "$OUT" 2>/dev/null || true
  echo "ipa_path=$IPA"
  echo "ipa_size=$(stat -f %z "$IPA" 2>/dev/null || stat -c %s "$IPA" 2>/dev/null || true)"
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$IPA" 2>/dev/null || true; fi
  echo 'powernfc_extract_status=RAW_IPA_READY'
else
  echo "ipa_pack_rc=$RC"
  echo 'powernfc_extract_status=PACKAGING_FAILED'
fi

echo '=== EXTRACTION SCRIPT COMPLETE ==='
exit 0
} 2>&1 | tee "$OUT"

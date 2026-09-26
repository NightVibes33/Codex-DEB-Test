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

APP=''
for p in /var/containers/Bundle/Application/*/*.app /var/jb/Applications/*.app /Applications/*.app; do
  [ -d "$p" ] || continue
  plist="$p/Info.plist"
  [ -f "$plist" ] || continue
  bid="$(plutil -extract CFBundleIdentifier raw -o - "$plist" 2>/dev/null)"
  name="$(plutil -extract CFBundleDisplayName raw -o - "$plist" 2>/dev/null)"
  [ -n "$name" ] || name="$(plutil -extract CFBundleName raw -o - "$plist" 2>/dev/null)"
  case "$(printf '%s %s %s' "$name" "$bid" "$p" | tr '[:upper:]' '[:lower:]')" in
    *powernfc*|*power\ nfc*)
      APP="$p"
      break
      ;;
  esac
done

echo '=== INSTALLED APP PROBE ==='
if [ -z "$APP" ]; then
  echo 'powernfc_installed=NO'
  echo 'Searching install database text for PowerNFC/App Store ID 6748850927...'
  for f in /var/mobile/Library/Caches/com.apple.mobile.installation.plist /var/mobile/Library/Caches/com.apple.mobile.installation_backup.plist; do
    [ -f "$f" ] || continue
    strings "$f" 2>/dev/null | grep -Ei -m 10 'PowerNFC|6748850927' || true
  done

  TF=''
  for p in /var/containers/Bundle/Application/*/*.app; do
    [ -f "$p/Info.plist" ] || continue
    bid="$(plutil -extract CFBundleIdentifier raw -o - "$p/Info.plist" 2>/dev/null)"
    if [ "$bid" = 'com.apple.TestFlight' ]; then TF="$p"; break; fi
  done
  echo "testflight_app=${TF:-NOT_FOUND}"
  echo "uiopen=$(command -v uiopen 2>/dev/null || true)"
  echo "open=$(command -v open 2>/dev/null || true)"
  echo 'powernfc_extract_status=NOT_INSTALLED'
  exit 0
fi

echo 'powernfc_installed=YES'
echo "app_path=$APP"
PLIST="$APP/Info.plist"
BID="$(plutil -extract CFBundleIdentifier raw -o - "$PLIST" 2>/dev/null)"
NAME="$(plutil -extract CFBundleDisplayName raw -o - "$PLIST" 2>/dev/null)"
VER="$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST" 2>/dev/null)"
BUILD="$(plutil -extract CFBundleVersion raw -o - "$PLIST" 2>/dev/null)"
EXE="$(plutil -extract CFBundleExecutable raw -o - "$PLIST" 2>/dev/null)"
BIN="$APP/$EXE"

echo "bundle_id=$BID"
echo "display_name=$NAME"
echo "version=$VER"
echo "build=$BUILD"
echo "executable=$EXE"
echo "binary=$BIN"
echo "binary_size=$(stat -f %z "$BIN" 2>/dev/null || stat -c %s "$BIN" 2>/dev/null || true)"

echo
echo '=== INFO.PLIST ==='
plutil -p "$PLIST" 2>/dev/null || true

echo
echo '=== EMBEDDED PROVISION / ENTITLEMENTS ==='
if command -v ldid >/dev/null 2>&1; then
  ldid -e "$BIN" 2>&1 || true
else
  echo 'ldid=NOT_FOUND'
fi

echo
echo '=== MACH-O LOAD COMMANDS ==='
if command -v otool >/dev/null 2>&1; then
  otool -L "$BIN" 2>&1 || true
  echo '--- selected load-command markers ---'
  otool -l "$BIN" 2>/dev/null | grep -E -A4 -B2 'LC_ENCRYPTION_INFO|LC_ENCRYPTION_INFO_64|cryptid|LC_LOAD_DYLIB|LC_LOAD_WEAK_DYLIB' | head -n 600 || true
else
  echo 'otool=NOT_FOUND'
fi

echo
echo '=== EMBEDDED FRAMEWORKS / PLUGINS ==='
find "$APP" -maxdepth 4 \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' \) -print 2>/dev/null | sort || true

echo
echo '=== HIGH-VALUE STRING MARKERS ==='
if command -v strings >/dev/null 2>&1; then
  strings -a "$BIN" 2>/dev/null | grep -Ei 'AirTraffic|Grappa|MobileBackup|MobileRestore|BackupAgent|bookassetd|itunesstored|AFC|lockdown|RemoteXPC|RPPairing|remotepairing|RSD|syslog|passd|Passbook|Stockholm|/var/mobile/Library/Passes|Cards/|pairing.*plist|SparseRestore|BookRestore|restore|MobileDevice|Developer Mode|LocalDevVPN|Wallet' | head -n 1200 || true
else
  echo 'strings=NOT_FOUND'
fi

echo
echo '=== AVAILABLE DUMP/DEBUG TOOLS ==='
for c in frida frida-ps frida-trace python3 ldid otool nm strings zip unzip tar cycript debugserver gdb; do
  p="$(command -v "$c" 2>/dev/null || true)"
  [ -n "$p" ] && echo "$c=$p" || echo "$c=NOT_FOUND"
done
find /var/jb /usr/local /Applications -maxdepth 5 -type f \( -iname '*decrypt*' -o -iname '*dumpdecrypted*' -o -iname '*frida*dump*' -o -iname '*bfdecrypt*' \) -print 2>/dev/null | head -n 100 || true

echo
echo '=== PACKAGE RAW INSTALLED APP AS IPA ==='
mkdir -p "$TMP/Payload"
cp -a "$APP" "$TMP/Payload/" 2>&1
if command -v zip >/dev/null 2>&1; then
  (cd "$TMP" && zip -qry "$IPA" Payload)
  RC=$?
elif command -v python3 >/dev/null 2>&1; then
  (cd "$TMP" && python3 -m zipfile -c "$IPA" Payload)
  RC=$?
else
  echo 'No zip or python3 available to create IPA.'
  RC=127
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

#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== IPHONE ZEBRA + SILEO READ-ONLY DIAGNOSTICS ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
printf 'identity='; id
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'device_name='; scutil --get ComputerName 2>/dev/null || true

echo
echo '--- storage ---'
df -h / /var /var/jb 2>/dev/null || true

echo
echo '--- Zebra + Sileo package records ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' 2>/dev/null | grep -Ei 'zebra|sileo|ellekit|substrate|substitute|libhooker' || true

echo
echo '--- Zebra package metadata ---'
for pkg in xyz.willy.zebra xyz.willy.Zebra; do
  dpkg-query -W -f='Package=${Package}\nVersion=${Version}\nArchitecture=${Architecture}\nDepends=${Depends}\nStatus=${Status}\n' "$pkg" 2>/dev/null || true
done

echo
echo '--- Zebra bundle candidates ---'
for app in /var/jb/Applications/Zebra.app /Applications/Zebra.app; do
  [ -d "$app" ] || continue
  echo "ZEBRA_APP=$app"
  ls -ld "$app" 2>/dev/null || true
  ls -l "$app/Zebra" 2>/dev/null || true
  file "$app/Zebra" 2>/dev/null || true
  if command -v plutil >/dev/null 2>&1; then
    echo 'Info.plist identifiers:'
    plutil -p "$app/Info.plist" 2>/dev/null | grep -E 'CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion|CFBundleURLSchemes' || true
  fi
  if command -v otool >/dev/null 2>&1; then
    echo 'linked libraries:'
    otool -L "$app/Zebra" 2>/dev/null | sed -n '1,100p' || true
  fi
done

echo
echo '--- Zebra dpkg verification ---'
dpkg -V xyz.willy.zebra 2>&1 || true

echo
echo '--- Zebra registration ---'
uicache -l 2>/dev/null | grep -i -A5 -B5 zebra || true

echo
echo '--- currently running Zebra ---'
ps ax 2>/dev/null | grep -i '[Z]ebra' || true

echo
echo '--- recent Zebra crash reports ---'
TMP=/tmp/zebra-crash-list.$$
: > "$TMP"
for root in /var/mobile/Library/Logs/CrashReporter /private/var/mobile/Library/Logs/CrashReporter /Library/Logs/CrashReporter /private/var/Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 3 -type f \( -iname '*zebra*.ips' -o -iname '*zebra*.crash' -o -iname '*zebra*' \) -print 2>/dev/null | while IFS= read -r f; do
    TS="$(stat -f '%m' "$f" 2>/dev/null || echo 0)"
    printf '%s\t%s\n' "$TS" "$f"
  done >> "$TMP"
done
sort -nr "$TMP" 2>/dev/null | head -n 12 || true
LATEST="$(sort -nr "$TMP" 2>/dev/null | head -n 1 | cut -f2-)"
rm -f "$TMP"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  echo "LATEST_ZEBRA_CRASH=$LATEST"
  sed -n '1,420p' "$LATEST" 2>/dev/null || true
else
  echo 'no_zebra_crash_report_found=true'
fi

echo
echo '=== SILEO / CYPWN REPO DIAGNOSTICS ==='
echo '--- source definitions matching cypwn/cydwn ---'
for aptroot in /var/jb/etc/apt /etc/apt; do
  [ -d "$aptroot" ] || continue
  find "$aptroot" -maxdepth 4 -type f \( -name '*.list' -o -name '*.sources' -o -name 'sources.list' \) -print 2>/dev/null | while IFS= read -r src; do
    if grep -Eqi 'cypwn|cydwn' "$src" 2>/dev/null; then
      echo "SOURCE_FILE=$src"
      grep -Ein 'cypwn|cydwn|^(deb |deb-src |Types:|URIs:|Suites:|Components:|Architectures:|Enabled:|Signed-By:)' "$src" 2>/dev/null | sed -E 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1***:***@#g'
    fi
  done
done

echo
echo '--- cached package indexes matching cypwn/cydwn ---'
for listroot in /var/jb/var/lib/apt/lists /var/lib/apt/lists; do
  [ -d "$listroot" ] || continue
  find "$listroot" -maxdepth 2 -type f -print 2>/dev/null | grep -Ei 'cypwn|cydwn' | while IFS= read -r idx; do
    BYTES="$(wc -c < "$idx" 2>/dev/null || echo 0)"
    COUNT="$(grep -c '^Package:' "$idx" 2>/dev/null || echo 0)"
    echo "INDEX=$idx bytes=$BYTES package_records=$COUNT"
    grep '^Package:' "$idx" 2>/dev/null | head -n 20 || true
  done
done

echo
echo '--- APT index target mapping for CyPwn ---'
apt-get indextargets 2>/dev/null | grep -Ei -A16 -B4 'cypwn|cydwn' || true

echo
echo '--- partial / failed CyPwn index files ---'
for d in /var/jb/var/lib/apt/lists/partial /var/lib/apt/lists/partial; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -type f -print 2>/dev/null | grep -Ei 'cypwn|cydwn' || true
done

echo
echo '--- apt/dpkg health ---'
ls -ld /var/jb/etc/apt /var/jb/etc/apt/sources.list.d /var/jb/var/lib/apt/lists /var/jb/var/lib/apt/lists/partial 2>/dev/null || true
dpkg --audit 2>&1 || true

echo
echo '--- Sileo process and bundle ---'
ps ax 2>/dev/null | grep -i '[S]ileo' || true
for app in /var/jb/Applications/Sileo.app /Applications/Sileo.app; do
  [ -d "$app" ] || continue
  echo "SILEO_APP=$app"
  ls -ld "$app" 2>/dev/null || true
  if command -v plutil >/dev/null 2>&1; then
    plutil -p "$app/Info.plist" 2>/dev/null | grep -E 'CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion' || true
  fi
done

echo 'IPHONE_READ_ONLY_DIAGNOSTICS_COMPLETE=1'
exit 0

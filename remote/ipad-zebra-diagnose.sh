#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

sanitize_stream() {
  sed -E \
    -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1***:***@#g' \
    -e 's#([?&](token|key|auth|password|pass|apikey|api_key)=)[^&[:space:]]+#\1***#Ig'
}

echo '=== Zebra + Sileo lightweight read-only diagnostics ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
df -h /var /var/jb 2>/dev/null || true

echo
echo '--- Zebra / Sileo / injection package records ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' 2>/dev/null | grep -Ei 'zebra|sileo|ellekit|substrate|substitute|libhooker' || true

echo
echo '--- Zebra package metadata ---'
apt-cache policy xyz.willy.zebra 2>/dev/null || true
dpkg-query -W -f='Package=${Package}\nVersion=${Version}\nArchitecture=${Architecture}\nDepends=${Depends}\nStatus=${Status}\n' xyz.willy.zebra 2>/dev/null || true
dpkg -V xyz.willy.zebra 2>&1 || true

echo
echo '--- Zebra bundle / executable ---'
for p in /var/jb/Applications/Zebra.app /Applications/Zebra.app; do
  [ -e "$p" ] || continue
  echo "FOUND=$p"
  ls -ld "$p" 2>/dev/null || true
  ls -l "$p/Zebra" 2>/dev/null || true
  file "$p/Zebra" 2>/dev/null || true
  if command -v otool >/dev/null 2>&1; then otool -L "$p/Zebra" 2>/dev/null || true; fi
done

echo
echo '--- Zebra uicache registration ---'
uicache -l 2>/dev/null | grep -i -A4 -B4 zebra || true

echo
echo '--- newest Zebra crash report ---'
TMP=/tmp/zebra-crash-list.$$
: > "$TMP"
for root in /var/mobile/Library/Logs/CrashReporter /private/var/mobile/Library/Logs/CrashReporter /Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 3 -type f \( -iname '*zebra*.ips' -o -iname '*zebra*.crash' -o -iname '*zebra*' \) -print 2>/dev/null | while IFS= read -r f; do
    printf '%s\t%s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"
  done >> "$TMP"
done
sort -nr "$TMP" 2>/dev/null | head -n 10 || true
LATEST="$(sort -nr "$TMP" 2>/dev/null | head -n 1 | cut -f2-)"
rm -f "$TMP"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  echo "LATEST=$LATEST"
  sed -n '1,360p' "$LATEST" 2>/dev/null || true
else
  echo 'no_zebra_crash_report_found=true'
fi

echo
echo '--- running Zebra process ---'
ps aux 2>/dev/null | grep -i '[Z]ebra' || true

echo
echo '=== Sileo/APT repo diagnosis: cydwn + cypwn ==='
echo '--- source definitions containing cydwn/cypwn ---'
MATCHED=0
for aptroot in /var/jb/etc/apt /etc/apt; do
  [ -d "$aptroot" ] || continue
  find "$aptroot" -maxdepth 4 -type f \( -name '*.list' -o -name '*.sources' -o -name 'sources.list' \) -print 2>/dev/null | while IFS= read -r src; do
    if grep -Eqi 'cydwn|cypwn' "$src" 2>/dev/null; then
      echo "SOURCE_FILE=$src"
      grep -Ein 'cydwn|cypwn|^(deb |deb-src |Types:|URIs:|Suites:|Components:|Architectures:|Enabled:|Signed-By:)' "$src" 2>/dev/null | sanitize_stream
    fi
  done
done

echo
echo '--- cached APT list files matching cydwn/cypwn ---'
for listroot in /var/jb/var/lib/apt/lists /var/lib/apt/lists; do
  [ -d "$listroot" ] || continue
  find "$listroot" -maxdepth 2 -type f -print 2>/dev/null | grep -Ei 'cydwn|cypwn' | while IFS= read -r idx; do
    BYTES="$(wc -c < "$idx" 2>/dev/null || echo 0)"
    COUNT="$(grep -c '^Package:' "$idx" 2>/dev/null || echo 0)"
    echo "INDEX=$idx bytes=$BYTES package_records=$COUNT"
    grep '^Package:' "$idx" 2>/dev/null | head -n 15 || true
  done
done

echo
echo '--- APT index targets matching cydwn/cypwn ---'
apt-get indextargets 2>/dev/null | grep -Ei -A14 -B3 'cydwn|cypwn' | sanitize_stream || true

echo
echo '--- APT partial files matching repo ---'
for d in /var/jb/var/lib/apt/lists/partial /var/lib/apt/lists/partial; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -type f -print 2>/dev/null | grep -Ei 'cydwn|cypwn' | sanitize_stream || true
done

echo
echo '--- APT directory health ---'
ls -ld /var/jb/etc/apt /var/jb/etc/apt/sources.list.d /var/jb/var/lib/apt/lists /var/jb/var/lib/apt/lists/partial 2>/dev/null || true
dpkg --audit 2>&1 || true

echo 'read_only_diagnostics_complete=true'
exit 0

#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

sanitize_stream() {
  sed -E \
    -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1***:***@#g' \
    -e 's#([?&](token|key|auth|password|pass|apikey|api_key)=)[^&[:space:]]+#\1***#Ig'
}

echo '=== Zebra + Sileo repo diagnostics: Dopamine rootless iOS 16.7.11 ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'kernel='; uname -a
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'rootfs_free='; df -h / /var /var/jb 2>/dev/null | tail -n +2 | tr '\n' ';'; echo
printf 'rootfs_inodes='; df -i / /var /var/jb 2>/dev/null | tail -n +2 | tr '\n' ';'; echo

echo
echo '--- package-manager package records ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' 2>/dev/null | grep -Ei 'zebra|sileo|apt|libapt|ellekit|substrate|substitute|libhooker' || true

echo
echo '--- Zebra package policy/dependencies ---'
apt-cache policy xyz.willy.zebra 2>/dev/null || true
dpkg-query -W -f='Package=${Package}\nVersion=${Version}\nArchitecture=${Architecture}\nDepends=${Depends}\nStatus=${Status}\n' xyz.willy.zebra 2>/dev/null || true

echo
echo '--- App bundle candidates ---'
for p in /var/jb/Applications/Zebra.app /Applications/Zebra.app; do
  if [ -e "$p" ]; then
    echo "FOUND $p"
    ls -ld "$p"
    ls -l "$p/Zebra" 2>/dev/null || true
    file "$p/Zebra" 2>/dev/null || true
    if command -v otool >/dev/null 2>&1; then
      otool -L "$p/Zebra" 2>/dev/null || true
    fi
    if command -v ldid >/dev/null 2>&1; then
      ldid -e "$p/Zebra" 2>/dev/null | head -n 160 || true
    fi
  fi
done

echo
echo '--- dpkg verification/audit ---'
dpkg -V xyz.willy.zebra 2>&1 || true
dpkg --audit 2>&1 || true

echo
echo '--- uicache registration ---'
uicache -l 2>/dev/null | grep -i -A5 -B5 zebra || true

echo
echo '--- recent Zebra crash reports (all common roots) ---'
TMP_CRASH='/tmp/zebra-crashes.txt'
: > "$TMP_CRASH"
for root in \
  /var/mobile/Library/Logs/CrashReporter \
  /private/var/mobile/Library/Logs/CrashReporter \
  /Library/Logs/CrashReporter \
  /private/var/Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 4 -type f \( -iname '*zebra*.ips' -o -iname '*zebra*.crash' -o -iname '*zebra*' \) -print 2>/dev/null | while IFS= read -r f; do
    TS="$(stat -f '%m' "$f" 2>/dev/null || echo 0)"
    printf '%s\t%s\n' "$TS" "$f"
  done >> "$TMP_CRASH"
done
sort -nr "$TMP_CRASH" 2>/dev/null | head -n 15 || true
LATEST="$(sort -nr "$TMP_CRASH" 2>/dev/null | head -n 1 | cut -f2-)"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  echo "--- latest crash: $LATEST ---"
  sed -n '1,420p' "$LATEST" 2>/dev/null || true
else
  echo 'no_zebra_crash_report_found=true'
fi

echo
echo '--- recent unified-log Zebra signals (read-only) ---'
if command -v log >/dev/null 2>&1; then
  log show --style compact --last 30m --predicate 'process == "Zebra" OR eventMessage CONTAINS[c] "Zebra"' 2>/dev/null | tail -n 300 || true
fi

echo
echo '--- substrate / ellekit context ---'
dpkg-query -W -f='${Package} ${Version} ${Architecture}\n' 2>/dev/null | grep -Ei 'ellekit|substitute|substrate|libhooker|preference|safe.?mode' || true

echo
echo '--- process state ---'
ps aux 2>/dev/null | grep -i '[Z]ebra' || true

echo
echo '=== Sileo / APT repo diagnostics: cydwn + cypwn spellings ==='
echo '--- matching source definitions (credentials redacted) ---'
for aptroot in /var/jb/etc/apt /etc/apt; do
  [ -d "$aptroot" ] || continue
  find "$aptroot" -maxdepth 4 -type f \( -name '*.list' -o -name '*.sources' -o -name 'sources.list' \) -print 2>/dev/null | while IFS= read -r src; do
    HITS="$(grep -Ein 'cydwn|cypwn' "$src" 2>/dev/null)"
    if [ -n "$HITS" ]; then
      echo "FILE=$src"
      printf '%s\n' "$HITS" | sanitize_stream
    fi
  done
done

echo
echo '--- all active deb/deb822 source lines near matching repo names ---'
for aptroot in /var/jb/etc/apt /etc/apt; do
  [ -d "$aptroot" ] || continue
  find "$aptroot" -maxdepth 4 -type f \( -name '*.list' -o -name '*.sources' -o -name 'sources.list' \) -print 2>/dev/null | while IFS= read -r src; do
    if grep -Eqi 'cydwn|cypwn' "$src" 2>/dev/null; then
      echo "### $src"
      grep -Ein '^(deb |deb-src |Types:|URIs:|Suites:|Components:|Architectures:|Enabled:|Signed-By:)' "$src" 2>/dev/null | sanitize_stream
    fi
  done
done

echo
echo '--- APT cached index files matching cydwn/cypwn ---'
for listroot in /var/jb/var/lib/apt/lists /var/lib/apt/lists; do
  [ -d "$listroot" ] || continue
  find "$listroot" -maxdepth 2 -type f -print 2>/dev/null | grep -Ei 'cydwn|cypwn' | while IFS= read -r idx; do
    printf 'INDEX=%s bytes=' "$idx"
    wc -c < "$idx" 2>/dev/null || echo '?'
    case "$idx" in
      *Packages*|*packages*)
        printf 'package_records='; grep -c '^Package:' "$idx" 2>/dev/null || echo 0
        printf 'first_packages='; grep '^Package:' "$idx" 2>/dev/null | head -n 12 | tr '\n' ','; echo
        ;;
    esac
  done
done

echo
echo '--- APT index-target mapping matching cydwn/cypwn ---'
if command -v apt-get >/dev/null 2>&1; then
  apt-get indextargets 2>/dev/null | grep -Ei -A18 -B4 'cydwn|cypwn' | sanitize_stream || true
fi

echo
echo '--- cached package records whose metadata references cydwn/cypwn ---'
for listroot in /var/jb/var/lib/apt/lists /var/lib/apt/lists; do
  [ -d "$listroot" ] || continue
  find "$listroot" -maxdepth 2 -type f -iname '*Packages*' -print 2>/dev/null | while IFS= read -r idx; do
    if grep -Eqi 'cydwn|cypwn' "$idx" 2>/dev/null; then
      echo "MATCHING_METADATA_FILE=$idx"
      grep -Ein -A5 -B2 'cydwn|cypwn' "$idx" 2>/dev/null | head -n 120 | sanitize_stream
    fi
  done
done

echo
echo '--- APT partial/failed index clues ---'
for listroot in /var/jb/var/lib/apt/lists /var/lib/apt/lists; do
  [ -d "$listroot" ] || continue
  find "$listroot" -maxdepth 2 -type f -print 2>/dev/null | grep -Ei 'partial|cydwn|cypwn' | head -n 160 | sanitize_stream
 done

echo
echo '--- Sileo preference/cache paths mentioning repo name ---'
for root in \
  /var/mobile/Library \
  /private/var/mobile/Library \
  /var/jb/var/mobile/Library \
  /var/jb/var/lib; do
  [ -d "$root" ] || continue
  grep -RIlE 'cydwn|cypwn' "$root" 2>/dev/null | head -n 80 | sanitize_stream
 done

echo
echo '--- APT config roots and ownership ---'
ls -ld /var/jb/etc/apt /var/jb/etc/apt/sources.list.d /var/jb/var/lib/apt/lists /var/jb/var/lib/apt/lists/partial 2>/dev/null || true

printf '\nread_only_diagnostics_complete=true\n'
exit 0

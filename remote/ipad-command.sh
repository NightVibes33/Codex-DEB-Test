#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

echo '=== Zebra diagnostics: Dopamine rootless iOS 16.7.11 ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'kernel='; uname -a
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true

echo
echo '--- Zebra package records ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' 2>/dev/null | grep -i zebra || true

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
      echo "otool -L $p/Zebra"
      otool -L "$p/Zebra" 2>/dev/null || true
    fi
    if command -v ldid >/dev/null 2>&1; then
      echo "ldid entitlements $p/Zebra"
      ldid -e "$p/Zebra" 2>/dev/null | head -n 120 || true
    fi
  fi
done

echo
echo '--- dpkg verification ---'
dpkg -V xyz.willy.zebra 2>&1 || true

echo
echo '--- uicache registration ---'
uicache -l 2>/dev/null | grep -i -A3 -B3 zebra || true

echo
echo '--- recent Zebra crash reports ---'
CRASH_DIR=/var/mobile/Library/Logs/CrashReporter
find "$CRASH_DIR" -maxdepth 1 -type f \( -iname '*zebra*.ips' -o -iname '*zebra*.crash' -o -iname '*zebra*' \) -print 2>/dev/null | while IFS= read -r f; do
  stat -f '%m %N' "$f" 2>/dev/null || ls -l "$f"
done | sort -nr | head -n 10

LATEST="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -iname '*zebra*.ips' -o -iname '*zebra*.crash' -o -iname '*zebra*' \) -print 2>/dev/null | while IFS= read -r f; do printf '%s %s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"; done | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  echo
echo "--- latest crash: $LATEST ---"
  sed -n '1,260p' "$LATEST" 2>/dev/null || true
else
  echo 'no_zebra_crash_report_found=true'
fi

echo
echo '--- substrate / ellekit context ---'
dpkg-query -W -f='${Package} ${Version} ${Architecture}\n' 2>/dev/null | grep -Ei 'ellekit|substitute|substrate|libhooker|preference|safe.?mode' || true

echo
echo '--- process state ---'
ps aux 2>/dev/null | grep -i '[Z]ebra' || true

echo 'zebra_diagnostics_complete=true'

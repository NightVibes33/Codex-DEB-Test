#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile
APP=/var/jb/Applications/Zebra.app
BUNDLE=xyz.willy.Zebra
CRASH=/var/mobile/Library/Logs/CrashReporter
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
BACKUP="/var/mobile/ZebraRepairBackup-$STAMP"

echo '=== Zebra black-screen diagnosis + state repair ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'ios='; sw_vers -productVersion 2>/dev/null || true

echo '--- package ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' xyz.willy.zebra 2>/dev/null || true

echo '--- data before ---'
for p in \
 '/var/mobile/Library/Application Support/Zebra' \
 '/var/mobile/Library/Application Support/xyz.willy.Zebra' \
 '/var/mobile/Library/Caches/xyz.willy.Zebra' \
 '/var/mobile/Library/Preferences/xyz.willy.Zebra.plist' \
 '/var/mobile/Library/Preferences/xyz.willy.zebra.plist'; do
  [ -e "$p" ] && { echo "FOUND $p"; du -sh "$p" 2>/dev/null || ls -ld "$p"; }
done

echo '--- first launch: reproduce black screen ---'
killall -9 Zebra 2>/dev/null || true
BEFORE_COUNT="$(find "$CRASH" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
if command -v uiopen >/dev/null 2>&1; then
  sudo -u mobile uiopen 'zbra://' >/tmp/zebra-launch1.txt 2>&1
  echo "launch1_rc=$?"
  cat /tmp/zebra-launch1.txt 2>/dev/null || true
fi
for s in 5 20 45 70; do
  sleep "$([ "$s" = 5 ] && echo 5 || [ "$s" = 20 ] && echo 15 || [ "$s" = 45 ] && echo 25 || echo 25)"
  echo "--- t=${s}s ---"
  ps aux 2>/dev/null | grep -i '[Z]ebra' || echo 'zebra_process=absent'
  PID="$(ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}')"
  if [ -n "$PID" ]; then
    echo "zebra_pid=$PID"
    if command -v sample >/dev/null 2>&1 && [ "$s" = 20 ]; then
      sample "$PID" 1 1 2>/dev/null | head -n 120 || true
    fi
  fi
done

echo '--- reports after reproduced hang ---'
find "$CRASH" -maxdepth 1 -type f \( -iname '*Zebra*' -o -iname 'JetsamEvent*' -o -iname '*watchdog*' \) -print 2>/dev/null | while IFS= read -r f; do
  printf '%s %s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"
done | sort -nr | head -n 20
LATEST_Z="$(find "$CRASH" -maxdepth 1 -type f -iname '*Zebra*' -print 2>/dev/null | while IFS= read -r f; do printf '%s %s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"; done | sort -nr | head -n1 | cut -d' ' -f2-)"
if [ -n "$LATEST_Z" ] && [ -f "$LATEST_Z" ]; then
 echo "latest_zebra_report=$LATEST_Z"
 grep -Ei 'Exception Type|Termination Reason|watchdog|scene-update|hang|jetsam|reason|Library not loaded|dyld|coalition|procRole' "$LATEST_Z" 2>/dev/null | head -n 100 || true
fi

if command -v log >/dev/null 2>&1; then
  echo '--- recent unified log ---'
  log show --last 3m --style compact --predicate 'process == "Zebra" OR eventMessage CONTAINS[c] "xyz.willy.Zebra" OR eventMessage CONTAINS[c] "Zebra"' 2>/dev/null | tail -n 180 || true
fi

echo '--- backup Zebra state ---'
mkdir -p "$BACKUP"
for p in \
 '/var/mobile/Library/Application Support/Zebra' \
 '/var/mobile/Library/Application Support/xyz.willy.Zebra' \
 '/var/mobile/Library/Caches/xyz.willy.Zebra' \
 '/var/mobile/Library/Preferences/xyz.willy.Zebra.plist' \
 '/var/mobile/Library/Preferences/xyz.willy.zebra.plist'; do
  if [ -e "$p" ]; then
    name="$(echo "$p" | sed 's#^/##; s#/#__#g')"
    cp -a "$p" "$BACKUP/$name" 2>/dev/null || cp -R "$p" "$BACKUP/$name" 2>/dev/null || true
  fi
done
chown -R mobile:mobile "$BACKUP" 2>/dev/null || true
echo "backup_path=$BACKUP"

echo '--- reset Zebra user state ---'
killall -9 Zebra 2>/dev/null || true
rm -rf '/var/mobile/Library/Application Support/Zebra' 2>/dev/null || true
rm -rf '/var/mobile/Library/Application Support/xyz.willy.Zebra' 2>/dev/null || true
rm -rf '/var/mobile/Library/Caches/xyz.willy.Zebra' 2>/dev/null || true
rm -rf '/var/mobile/Library/Caches/xyz.willy.zebra' 2>/dev/null || true
rm -f '/var/mobile/Library/Preferences/xyz.willy.Zebra.plist' 2>/dev/null || true
rm -f '/var/mobile/Library/Preferences/xyz.willy.zebra.plist' 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
if [ -d "$APP" ]; then
  chown -R root:wheel "$APP" 2>/dev/null || true
  chmod 0755 "$APP/Zebra" 2>/dev/null || true
  uicache -p "$APP" 2>&1 || true
fi
uicache -a 2>&1 || true
sync
sleep 3

echo '--- second launch after clean state ---'
if command -v uiopen >/dev/null 2>&1; then
  sudo -u mobile uiopen 'zbra://' >/tmp/zebra-launch2.txt 2>&1
  echo "launch2_rc=$?"
  cat /tmp/zebra-launch2.txt 2>/dev/null || true
fi
for s in 5 15 35; do
  sleep "$([ "$s" = 5 ] && echo 5 || [ "$s" = 15 ] && echo 10 || echo 20)"
  echo "--- clean t=${s}s ---"
  ps aux 2>/dev/null | grep -i '[Z]ebra' || echo 'zebra_process=absent'
done

echo '--- newest Zebra report after clean launch ---'
NEWZ="$(find "$CRASH" -maxdepth 1 -type f -iname '*Zebra*' -print 2>/dev/null | while IFS= read -r f; do printf '%s %s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"; done | sort -nr | head -n1 | cut -d' ' -f2-)"
if [ -n "$NEWZ" ] && [ -f "$NEWZ" ]; then
 echo "newest_zebra_report=$NEWZ"
 grep -Ei 'Exception Type|Termination Reason|watchdog|scene-update|hang|jetsam|reason|Library not loaded|dyld' "$NEWZ" 2>/dev/null | head -n 100 || true
else
 echo 'newest_zebra_report=none'
fi

echo 'zebra_black_screen_repair_complete=true'
exit 0

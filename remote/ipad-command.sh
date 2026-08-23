#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

printf '%s\n' '=== Zebra repair: Dopamine rootless iOS 16.7.11 ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'dpkg_arch='; dpkg --print-architecture 2>/dev/null || true

echo
echo '--- BEFORE: package state ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' 2>/dev/null | grep -Ei '(^|[ |])(xyz\.willy\.zebra|com\.getzbra\.zebra2)([ |]|$)' || true
apt-cache policy xyz.willy.zebra 2>/dev/null || true
apt-cache policy com.getzbra.zebra2 2>/dev/null || true

echo
echo '--- BEFORE: app bundles ---'
for p in /var/jb/Applications/Zebra.app /Applications/Zebra.app; do
  if [ -e "$p" ]; then
    echo "FOUND=$p"
    ls -ld "$p"
    ls -l "$p/Zebra" 2>/dev/null || true
    file "$p/Zebra" 2>/dev/null || true
  fi
done

echo
echo '--- BEFORE: dpkg audit ---'
dpkg --audit 2>&1 || true

echo
echo '--- BEFORE: latest Zebra crash summary ---'
CRASH_DIR=/var/mobile/Library/Logs/CrashReporter
LATEST="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -iname '*zebra*.ips' -o -iname '*zebra*.crash' -o -iname '*zebra*' \) -print 2>/dev/null | while IFS= read -r f; do printf '%s %s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"; done | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  echo "latest_crash=$LATEST"
  grep -Ei 'Exception Type|Termination Reason|Library not loaded|Reason:|dyld|abort|symbol not found|Crashed Thread' "$LATEST" 2>/dev/null | head -n 60 || true
else
  echo 'latest_crash=none'
fi

echo
echo '--- REPAIR: complete interrupted package work ---'
dpkg --configure -a 2>&1 || true
apt-get -f install -y 2>&1 || true

echo
echo '--- REPAIR: refresh repositories ---'
apt-get update 2>&1 || true

echo
echo '--- REPAIR: reinstall Zebra ---'
ZPKG=''
if dpkg-query -W -f='${Status}' xyz.willy.zebra 2>/dev/null | grep -q 'install ok installed'; then
  ZPKG='xyz.willy.zebra'
elif dpkg-query -W -f='${Status}' com.getzbra.zebra2 2>/dev/null | grep -q 'install ok installed'; then
  ZPKG='com.getzbra.zebra2'
elif apt-cache show xyz.willy.zebra >/dev/null 2>&1; then
  ZPKG='xyz.willy.zebra'
fi
printf 'selected_zebra_package=%s\n' "${ZPKG:-none}"
if [ -n "$ZPKG" ]; then
  DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y "$ZPKG" 2>&1
  REINSTALL_RC=$?
  echo "zebra_reinstall_rc=$REINSTALL_RC"
else
  echo 'zebra_reinstall_rc=skipped-no-package-found'
fi

echo
echo '--- REPAIR: permissions and disposable caches ---'
if [ -d /var/jb/Applications/Zebra.app ]; then
  chown -R root:wheel /var/jb/Applications/Zebra.app 2>/dev/null || true
  find /var/jb/Applications/Zebra.app -type d -exec chmod 0755 {} + 2>/dev/null || true
  chmod 0755 /var/jb/Applications/Zebra.app/Zebra 2>/dev/null || true
fi
for c in \
  '/var/mobile/Library/Caches/xyz.willy.Zebra' \
  '/var/mobile/Library/Caches/xyz.willy.zebra' \
  '/var/mobile/Library/Caches/com.getzbra.zebra2'; do
  if [ -e "$c" ]; then
    echo "clearing_cache=$c"
    rm -rf "$c"
  fi
done
chown -R mobile:mobile '/var/mobile/Library/Application Support/Zebra' 2>/dev/null || true
chown -R mobile:mobile '/var/mobile/Library/Application Support/xyz.willy.Zebra' 2>/dev/null || true

echo
echo '--- REPAIR: app registration ---'
if [ -d /var/jb/Applications/Zebra.app ]; then
  uicache -p /var/jb/Applications/Zebra.app 2>&1 || true
fi
uicache -a 2>&1 || true
killall -9 Zebra 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
sync
sleep 2

echo
echo '--- AFTER: package state ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' 2>/dev/null | grep -Ei '(^|[ |])(xyz\.willy\.zebra|com\.getzbra\.zebra2)([ |]|$)' || true
if [ -d /var/jb/Applications/Zebra.app ]; then
  ls -ld /var/jb/Applications/Zebra.app
  ls -l /var/jb/Applications/Zebra.app/Zebra 2>/dev/null || true
fi

echo
echo '--- AFTER: registration ---'
uicache -l 2>/dev/null | grep -i -A4 -B4 zebra || true

echo
echo '--- AFTER: launch attempt ---'
LAUNCH_RC=127
if command -v uiopen >/dev/null 2>&1; then
  sudo -u mobile uiopen 'zbra://' >/tmp/zebra-uiopen.out 2>&1
  LAUNCH_RC=$?
  cat /tmp/zebra-uiopen.out 2>/dev/null || true
  echo "uiopen_zbra_rc=$LAUNCH_RC"
  if [ "$LAUNCH_RC" -ne 0 ]; then
    sudo -u mobile uiopen 'zebra://' >/tmp/zebra-uiopen2.out 2>&1
    LAUNCH_RC=$?
    cat /tmp/zebra-uiopen2.out 2>/dev/null || true
    echo "uiopen_zebra_rc=$LAUNCH_RC"
  fi
else
  echo 'uiopen=missing'
fi
sleep 5
ps aux 2>/dev/null | grep -i '[Z]ebra' || true

echo
echo '--- AFTER: newest crash if launch still fails ---'
NEWLATEST="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -iname '*zebra*.ips' -o -iname '*zebra*.crash' -o -iname '*zebra*' \) -print 2>/dev/null | while IFS= read -r f; do printf '%s %s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"; done | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [ -n "$NEWLATEST" ] && [ -f "$NEWLATEST" ]; then
  echo "newest_crash=$NEWLATEST"
  sed -n '1,220p' "$NEWLATEST" 2>/dev/null | tail -n 220 || true
else
  echo 'newest_crash=none'
fi

echo 'zebra_repair_pass_complete=true'
exit 0

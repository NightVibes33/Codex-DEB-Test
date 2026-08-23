#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
D=/var/jb/usr/lib/TweakInject
B=/var/mobile/.zebra-tweak-bisect-$$
CANDIDATES="82Hack AutoRevenueCat FLEXList FLEXing Flex LimneosCrack Lynx Snowboard Speedy iarrays_hack_"
mkdir -p "$B"

restore_all() {
  for n in $CANDIDATES; do
    [ -f "$B/$n.plist" ] && mv -f "$B/$n.plist" "$D/$n.plist" 2>/dev/null || true
  done
  killall -9 Zebra 2>/dev/null || true
  rm -rf "$B" 2>/dev/null || true
}
trap restore_all EXIT INT TERM

zpid() { ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}'; }
launch_test() {
  label="$1"
  killall -9 Zebra 2>/dev/null || true
  sleep 2
  sudo -u mobile uiopen 'zbra://' >/tmp/zebra-bisect-open.txt 2>&1 || true
  sleep 28
  pid="$(zpid)"
  if [ -n "$pid" ]; then
    echo "RESULT|$label|SURVIVED|pid=$pid"
    killall -9 Zebra 2>/dev/null || true
    return 0
  fi
  echo "RESULT|$label|DIED"
  return 1
}

echo '=== Zebra per-tweak isolation ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
echo "candidates=$CANDIDATES"

# Disable only the UIKit-wide candidate plists. Other tweak filters remain untouched.
for n in $CANDIDATES; do
  if [ -f "$D/$n.plist" ]; then
    mv "$D/$n.plist" "$B/$n.plist"
    echo "staged=$n"
  else
    echo "missing=$n"
  fi
done

# Control: if this still dies, the culprit is outside this candidate set.
launch_test 'ALL_10_DISABLED'

# Restore exactly one candidate at a time while the other nine remain disabled.
for n in $CANDIDATES; do
  [ -f "$B/$n.plist" ] || continue
  mv "$B/$n.plist" "$D/$n.plist"
  echo "testing_only=$n"
  launch_test "$n"
  mv "$D/$n.plist" "$B/$n.plist" 2>/dev/null || true
done

# Restore everything before exiting.
restore_all
trap - EXIT INT TERM

echo '--- restore verification ---'
for n in $CANDIDATES; do
  if [ -f "$D/$n.plist" ]; then echo "restored=$n"; else echo "RESTORE_MISSING=$n"; fi
done

echo 'zebra_tweak_isolation_complete=true'
exit 0

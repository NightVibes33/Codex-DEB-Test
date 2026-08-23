#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
D=/var/jb/usr/lib/TweakInject
CANDS="82Hack AutoRevenueCat FLEXList FLEXing Flex LimneosCrack Lynx Snowboard Speedy iarrays_hack_"

echo '=== RESTORE ZEBRA TWEAKS + SOURCES FIRST ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'

# 1) Immediately restore any tweak plists left staged by an interrupted bisect.
for B in /var/mobile/.zebra-tweak-bisect-*; do
  [ -d "$B" ] || continue
  for p in "$B"/*.plist; do
    [ -f "$p" ] || continue
    n="$(basename "$p")"
    mv -f "$p" "$D/$n" 2>/dev/null || cp -f "$p" "$D/$n" 2>/dev/null || true
  done
  rm -rf "$B" 2>/dev/null || true
done
for n in $CANDS; do [ -f "$D/$n.plist" ] && echo "tweak_filter_restored=$n" || echo "tweak_filter_missing=$n"; done

# 2) Restore Zebra state/sources from the backup created before our earlier reset.
LATEST="$(ls -dt /var/mobile/ZebraRepairBackup-* 2>/dev/null | head -n1)"
echo "latest_zebra_backup=${LATEST:-none}"
if [ -n "$LATEST" ] && [ -d "$LATEST" ]; then
  AS1="$LATEST/var__mobile__Library__Application Support__Zebra"
  AS2="$LATEST/var__mobile__Library__Application Support__xyz.willy.Zebra"
  P1="$LATEST/var__mobile__Library__Preferences__xyz.willy.Zebra.plist"
  P2="$LATEST/var__mobile__Library__Preferences__xyz.willy.zebra.plist"
  mkdir -p '/var/mobile/Library/Application Support' '/var/mobile/Library/Preferences' 2>/dev/null || true
  if [ -d "$AS1" ]; then rm -rf '/var/mobile/Library/Application Support/Zebra'; cp -a "$AS1" '/var/mobile/Library/Application Support/Zebra'; echo restored_state=Zebra; fi
  if [ -d "$AS2" ]; then rm -rf '/var/mobile/Library/Application Support/xyz.willy.Zebra'; cp -a "$AS2" '/var/mobile/Library/Application Support/xyz.willy.Zebra'; echo restored_state=xyz.willy.Zebra; fi
  if [ -f "$P1" ]; then cp -a "$P1" '/var/mobile/Library/Preferences/xyz.willy.Zebra.plist'; echo restored_pref=xyz.willy.Zebra; fi
  if [ -f "$P2" ]; then cp -a "$P2" '/var/mobile/Library/Preferences/xyz.willy.zebra.plist'; echo restored_pref=xyz.willy.zebra; fi
  chown -R mobile:mobile '/var/mobile/Library/Application Support/Zebra' '/var/mobile/Library/Application Support/xyz.willy.Zebra' 2>/dev/null || true
  chown mobile:mobile '/var/mobile/Library/Preferences/xyz.willy.Zebra.plist' '/var/mobile/Library/Preferences/xyz.willy.zebra.plist' 2>/dev/null || true
fi

echo '--- source/state verification ---'
for p in '/var/mobile/Library/Application Support/Zebra' '/var/mobile/Library/Application Support/xyz.willy.Zebra'; do
  [ -e "$p" ] || continue
  echo "STATE=$p"
  find "$p" -maxdepth 2 -type f 2>/dev/null | grep -Ei 'source|list|repo' | head -n 30 || true
  du -sh "$p" 2>/dev/null || true
done

# Do not leave safe-mode variables globally set.
launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
launchctl unsetenv _MSSafeMode 2>/dev/null || true
sudo -u mobile launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
sudo -u mobile launchctl unsetenv _MSSafeMode 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true

echo 'restore_complete=true'

# 3) Fast 10-candidate group bisect. Only plist filters move; dylibs and packages are untouched.
T=/var/mobile/.zebra-fast-bisect-$$
mkdir -p "$T"
restore_all() {
  for p in "$T"/*.plist; do [ -f "$p" ] && mv -f "$p" "$D/$(basename "$p")" 2>/dev/null || true; done
  rm -rf "$T" 2>/dev/null || true
}
trap restore_all EXIT INT TERM HUP

move_out() { for n in $1; do [ -f "$D/$n.plist" ] && mv "$D/$n.plist" "$T/$n.plist"; done; }
move_in()  { for n in $1; do [ -f "$T/$n.plist" ] && mv "$T/$n.plist" "$D/$n.plist"; done; }
zpid() { ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}'; }
test_launch() {
  label="$1"
  killall -9 Zebra 2>/dev/null || true
  sleep 1
  sudo -u mobile uiopen 'zbra://' >/dev/null 2>&1 || true
  sleep 23
  p="$(zpid)"
  if [ -n "$p" ]; then echo "TEST|$label|SURVIVED"; return 0; else echo "TEST|$label|DIED"; return 1; fi
}

# Disable all 10; verify culprit is inside this set.
move_out "$CANDS"
if ! test_launch all10_disabled; then
  echo 'CULPRIT_RESULT=outside_10_candidate_set'
  restore_all
  trap - EXIT INT TERM HUP
  exit 0
fi

# Group A vs B: enable first five only.
G1="82Hack AutoRevenueCat FLEXList FLEXing Flex"
G2="LimneosCrack Lynx Snowboard Speedy iarrays_hack_"
move_in "$G1"
if test_launch group1; then BAD="$G2"; move_out "$G1"; else BAD="$G1"; move_out "$G1"; fi

echo "bad_group=$BAD"

# Test each bad-group tweak one at a time with all other candidates disabled.
CULPRITS=""
for n in $BAD; do
  move_in "$n"
  if test_launch "only_$n"; then :; else CULPRITS="$CULPRITS $n"; fi
  move_out "$n"
done

echo "CULPRIT_RESULT=${CULPRITS:-none_identified}"

restore_all
trap - EXIT INT TERM HUP
for n in $CANDS; do [ -f "$D/$n.plist" ] && echo "final_restored=$n" || echo "FINAL_MISSING=$n"; done

echo 'zebra_restore_and_isolation_complete=true'
exit 0

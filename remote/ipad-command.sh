#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
D=/var/jb/usr/lib/TweakInject
ALL="82Hack AutoRevenueCat FLEXList FLEXing Flex LimneosCrack Lynx Snowboard Speedy iarrays_hack_"
REMAIN="Flex LimneosCrack Lynx Snowboard Speedy iarrays_hack_"

echo '=== RESTORE FIRST, THEN FAST ISOLATE ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'

# Restore anything left staged by cancelled tests.
for B in /var/mobile/.zebra-tweak-bisect-* /var/mobile/.zebra-fast-bisect-*; do
  [ -d "$B" ] || continue
  for p in "$B"/*.plist; do [ -f "$p" ] && mv -f "$p" "$D/$(basename "$p")" 2>/dev/null || true; done
  rm -rf "$B" 2>/dev/null || true
done
for n in $ALL; do [ -f "$D/$n.plist" ] && echo "RESTORED_TWEAK=$n" || echo "MISSING_TWEAK=$n"; done

# Restore Zebra sources/state backup made before the earlier clean-state test.
LATEST="$(ls -dt /var/mobile/ZebraRepairBackup-* 2>/dev/null | head -n1)"
echo "BACKUP=${LATEST:-none}"
if [ -n "$LATEST" ] && [ -d "$LATEST" ]; then
  AS1="$LATEST/var__mobile__Library__Application Support__Zebra"
  AS2="$LATEST/var__mobile__Library__Application Support__xyz.willy.Zebra"
  P1="$LATEST/var__mobile__Library__Preferences__xyz.willy.Zebra.plist"
  P2="$LATEST/var__mobile__Library__Preferences__xyz.willy.zebra.plist"
  mkdir -p '/var/mobile/Library/Application Support' '/var/mobile/Library/Preferences' 2>/dev/null || true
  if [ -d "$AS1" ]; then rm -rf '/var/mobile/Library/Application Support/Zebra'; cp -a "$AS1" '/var/mobile/Library/Application Support/Zebra'; echo RESTORED_SOURCE_STATE=Zebra; fi
  if [ -d "$AS2" ]; then rm -rf '/var/mobile/Library/Application Support/xyz.willy.Zebra'; cp -a "$AS2" '/var/mobile/Library/Application Support/xyz.willy.Zebra'; echo RESTORED_SOURCE_STATE=xyz.willy.Zebra; fi
  [ -f "$P1" ] && cp -a "$P1" '/var/mobile/Library/Preferences/xyz.willy.Zebra.plist' 2>/dev/null && echo RESTORED_PREF=xyz.willy.Zebra
  [ -f "$P2" ] && cp -a "$P2" '/var/mobile/Library/Preferences/xyz.willy.zebra.plist' 2>/dev/null && echo RESTORED_PREF=xyz.willy.zebra
  chown -R mobile:mobile '/var/mobile/Library/Application Support/Zebra' '/var/mobile/Library/Application Support/xyz.willy.Zebra' 2>/dev/null || true
fi
find '/var/mobile/Library/Application Support/xyz.willy.Zebra' -maxdepth 2 -type f 2>/dev/null | grep -Ei 'source|list|repo' | head -n 20 || true

echo RESTORE_PHASE_COMPLETE=true

T=/var/mobile/.zebra-quick-$$
mkdir -p "$T"
restore_filters() {
  for p in "$T"/*.plist; do [ -f "$p" ] && mv -f "$p" "$D/$(basename "$p")" 2>/dev/null || true; done
  rm -rf "$T" 2>/dev/null || true
}
trap restore_filters EXIT INT TERM HUP
move_out(){ for n in $1; do [ -f "$D/$n.plist" ] && mv "$D/$n.plist" "$T/$n.plist"; done; }
move_in(){ for n in $1; do [ -f "$T/$n.plist" ] && mv "$T/$n.plist" "$D/$n.plist"; done; }
zpid(){ ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}'; }
testz(){
  lab="$1"; killall -9 Zebra 2>/dev/null || true; sleep 1
  sudo -u mobile uiopen 'zbra://' >/dev/null 2>&1 || true
  sleep 22
  if [ -n "$(zpid)" ]; then echo "TEST|$lab|SURVIVED"; return 0; else echo "TEST|$lab|DIED"; return 1; fi
}

# First four already independently survived in the previous run:
# 82Hack AutoRevenueCat FLEXList FLEXing
# Isolate only the six remaining suspects.
move_out "$REMAIN"

# Flex alone.
move_in "Flex"
if testz Flex; then
  move_out "Flex"
  # Split remaining five: [LimneosCrack Lynx Snowboard] vs [Speedy iarrays_hack_]
  G="LimneosCrack Lynx Snowboard"
  move_in "$G"
  if testz group_Limneos_Lynx_Snowboard; then
    move_out "$G"
    move_in "Speedy"
    if testz Speedy; then CULPRIT="iarrays_hack_"; else CULPRIT="Speedy"; fi
  else
    move_out "$G"
    move_in "LimneosCrack"
    if testz LimneosCrack; then
      move_out "LimneosCrack"
      move_in "Lynx"
      if testz Lynx; then CULPRIT="Snowboard"; else CULPRIT="Lynx"; fi
    else
      CULPRIT="LimneosCrack"
    fi
  fi
else
  CULPRIT="Flex"
fi

echo "CULPRIT_RESULT=$CULPRIT"

# Put EVERY tweak filter back globally.
restore_filters
trap - EXIT INT TERM HUP
for n in $ALL; do [ -f "$D/$n.plist" ] && echo "FINAL_TWEAK_PRESENT=$n" || echo "FINAL_TWEAK_MISSING=$n"; done

# Leave Zebra open with tweak injection suppressed only for this launch; immediately clear env again.
killall -9 Zebra 2>/dev/null || true
launchctl setenv DISABLE_TWEAKS 1 2>/dev/null || true
launchctl setenv _MSSafeMode 1 2>/dev/null || true
sudo -u mobile launchctl setenv DISABLE_TWEAKS 1 2>/dev/null || true
sudo -u mobile launchctl setenv _MSSafeMode 1 2>/dev/null || true
sudo -u mobile uiopen 'zbra://' >/dev/null 2>&1 || true
sleep 3
launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
launchctl unsetenv _MSSafeMode 2>/dev/null || true
sudo -u mobile launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
sudo -u mobile launchctl unsetenv _MSSafeMode 2>/dev/null || true
echo "FINAL_ZEBRA_PID=$(zpid)"
echo zebra_done=true
exit 0

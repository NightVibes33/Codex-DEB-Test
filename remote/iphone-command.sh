#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
TI=/var/jb/usr/lib/TweakInject
BACKUP=/var/mobile/Library/ChatGPT-Tweak-Backups
BAD="$TI/mmaintenanced_hook.plist"

echo '=== IPHONE TWEAK REPAIR + PREFERENCE AUDIT ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== REPAIR SYSTEMMEMORYRESETFIX FILTER =====\n'
mkdir -p "$BACKUP" 2>/dev/null
if [ -f "$BAD" ]; then
  stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)
  cp -p "$BAD" "$BACKUP/mmaintenanced_hook.plist.$stamp.bak" 2>/dev/null
  echo "backup=$BACKUP/mmaintenanced_hook.plist.$stamp.bak"
  echo 'original_base64:'
  base64 "$BAD" 2>/dev/null | tr -d '\r\n'; echo
  cat > "$BAD" <<'EOF'
Filter = {
    Executables = (
        "mmaintenanced"
    );
};
EOF
  chmod 0644 "$BAD" 2>/dev/null
  chown root:wheel "$BAD" 2>/dev/null || true
  echo 'replacement_text:'
  cat "$BAD"
else
  echo 'mmaintenanced_hook.plist=MISSING'
fi

printf '\n===== APPSYNC FILTER VALIDATION =====\n'
AS="$TI/AppSyncUnified-installd.plist"
if [ -f "$AS" ]; then
  grep -nE '<key>Filter</key>|<key>Executables</key>|<string>installd</string>|</dict>|</plist>' "$AS" 2>/dev/null || true
else
  echo 'AppSyncUnified-installd.plist=MISSING'
fi

printf '\n===== PREFERENCELOADER CORE PACKAGES =====\n'
for pkg in preferenceloader ws.hbang.common applist rocketbootstrap ellekit com.opa334.ellekit com.opa334.dopamine tweaksettings; do
  dpkg-query -W -f='${Status}\t${Package}\t${Version}\t${Architecture}\n' "$pkg" 2>/dev/null || true
done

echo '-- fuzzy package names --'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\n' 2>/dev/null | grep -Ei 'preferenceloader|tweaksettings|applist|rocketbootstrap|ellekit|cephei' || true

printf '\n===== PREFERENCE BUNDLES =====\n'
for d in /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences; do
  echo "DIR=$d"
  if [ -d "$d" ]; then
    find "$d" -maxdepth 2 -mindepth 1 -print 2>/dev/null | sort
  else
    echo MISSING
  fi
done

printf '\n===== PREFERENCE FILE OWNERS =====\n'
for p in /var/jb/Library/PreferenceBundles/*.bundle /var/jb/Library/PreferenceLoader/Preferences/*.plist; do
  [ -e "$p" ] || continue
  echo "ITEM=$p"
  dpkg-query -S "$p" 2>/dev/null || dpkg-query -S "${p#/var/jb}" 2>/dev/null || echo 'owner=UNKNOWN'
done

printf '\n===== TWEAK PACKAGE MANIFEST PREFERENCE CONTENT =====\n'
for list in /var/jb/var/lib/dpkg/info/*.list; do
  [ -f "$list" ] || continue
  if grep -Eq 'PreferenceBundles|PreferenceLoader/Preferences|\.bundle/' "$list" 2>/dev/null; then
    pkg=$(basename "$list" .list)
    echo "PKG=$pkg"
    grep -E 'PreferenceBundles|PreferenceLoader/Preferences|\.bundle/' "$list" 2>/dev/null | head -n 30
  fi
done

printf '\n===== SETTINGS / INJECTION STATE =====\n'
ps -A -o pid=,ppid=,%cpu=,%mem=,comm= 2>/dev/null | grep -Ei 'Preferences|SpringBoard|mmaintenanced' || true
launchctl list 2>/dev/null | grep -Ei 'ellekit|rocketbootstrap|dopamine' || true

echo '-- restarting only affected processes --'
killall Preferences 2>/dev/null || true
killall mmaintenanced 2>/dev/null || true
sleep 2
ps -A -o pid=,comm= 2>/dev/null | grep -E '[ /]mmaintenanced$' || true

echo '=== END IPHONE TWEAK REPAIR + PREFERENCE AUDIT ==='

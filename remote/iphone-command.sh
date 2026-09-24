#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH

echo '=== TWEAK PATH TOPOLOGY + CIRCLEAPPS EXPORT ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  echo "--- DIR $d ---"
  ls -ld "$d" 2>/dev/null || true
  stat -f 'inode=%i dev=%d mode=%Sp uid=%u gid=%g path=%N' "$d" 2>/dev/null || true
  readlink "$d" 2>/dev/null || true
done

echo '--- CircleApps file topology ---'
for f in \
 /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib \
 /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib.disabled \
 /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.dylib \
 /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.dylib.disabled \
 /var/jb/usr/lib/TweakInject/CircleAppsiPhone.plist \
 /var/jb/usr/lib/TweakInject/CircleAppsiPhone.plist.disabled; do
  [ -e "$f" ] || continue
  stat -f 'inode=%i dev=%d size=%z mtime=%Sm path=%N' -t '%Y-%m-%d %H:%M:%S %z' "$f" 2>/dev/null || true
done

echo
echo '=== CIRCLEAPPS DEPENDENCIES ==='
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' com.sugiuta.circleapps15 ws.hbang.common com.opa334.altlist preferenceloader ellekit 2>/dev/null || true
echo '--- package file list ---'
for root in /var/jb/Library/dpkg/info /var/jb/var/lib/dpkg/info; do
  [ -f "$root/com.sugiuta.circleapps15.list" ] && cat "$root/com.sugiuta.circleapps15.list"
done

echo
echo '=== CIRCLEAPPS DYLIB STRINGS / OBJC NAMES ==='
DY=/var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib.disabled
[ -f "$DY" ] || DY=/var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.dylib.disabled
if [ -f "$DY" ]; then
  file "$DY" 2>/dev/null || true
  strings "$DY" 2>/dev/null | grep -E 'SB|Circle|Icon|insert|View|Controller|App|Dock|Folder|Root|Home|Switcher|Preference|gesture|button|scroll|layout|list|array|index' | head -n 500 || true
  echo '=== CIRCLEAPPS_DYLIB_BASE64_BEGIN ==='
  base64 "$DY"
  echo '=== CIRCLEAPPS_DYLIB_BASE64_END ==='
fi

echo
echo '=== CIRCLEAPPS PLIST ==='
PL=/var/jb/usr/lib/TweakInject/CircleAppsiPhone.plist.disabled
[ -f "$PL" ] || PL=/var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.plist.disabled
[ -f "$PL" ] && { plutil -p "$PL" 2>/dev/null || strings "$PL" 2>/dev/null; }

echo 'CIRCLEAPPS_EXPORT_COMPLETE=1'
exit 0

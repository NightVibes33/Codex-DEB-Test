#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== TWEAK FUNCTIONALITY AUDIT ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null
printf 'build='; sw_vers -buildVersion 2>/dev/null
printf 'model='; sysctl -n hw.model 2>/dev/null

echo
echo '=== CIRCLEAPPS PACKAGE / DEPENDENCIES ==='
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' com.sugiuta.circleapps15 2>/dev/null || true
for p in mobilesubstrate preferenceloader ws.hbang.common com.opa334.altlist ellekit; do
  dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' "$p" 2>/dev/null || echo "missing_pkg=$p"
done
for f in  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib.disabled  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.plist  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.plist.disabled; do
  [ -e "$f" ] && ls -lT "$f" 2>/dev/null || true
done

echo
echo '=== CIRCLEAPPS PREFERENCES ==='
find /var/mobile/Library/Preferences /var/jb/var/mobile/Library/Preferences -maxdepth 1 -type f 2>/dev/null  | grep -Ei 'circle.*apps|sugiuta' | sort | while IFS= read -r f; do
    echo "===== PREF=$f ====="
    plutil -p "$f" 2>/dev/null || cat "$f" 2>/dev/null || true
 done

echo
echo '=== CIRCLEAPPS DYLIB DEPENDENCIES ==='
CIRC=
for x in /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib.disabled; do
  [ -f "$x" ] && CIRC="$x" && break
done
if [ -n "$CIRC" ]; then
  file "$CIRC" 2>/dev/null || true
  otool -L "$CIRC" 2>/dev/null || true
  echo '--- imported classes / strings hints ---'
  strings "$CIRC" 2>/dev/null | grep -Ei 'favorite|recent|bundle|identifier|array|insertObject|icon|preference|circleapps|altlist' | head -n 220 || true
fi

echo
echo '=== COMMON SUPPORT LIBRARIES ==='
for p in  /var/jb/Library/Frameworks/Cephei.framework/Cephei  /var/jb/Library/Frameworks/AltList.framework/AltList  /var/jb/usr/lib/librocketbootstrap.dylib  /var/jb/usr/lib/libSandy.dylib  /var/jb/usr/lib/libsparkapplist.dylib  /var/jb/usr/lib/libcolorpicker.dylib  /var/jb/usr/lib/libCSColorPicker.dylib; do
  if [ -e "$p" ]; then echo "present=$p"; else echo "missing=$p"; fi
done

echo
echo '=== ALL ENABLED TWEAK DEPENDENCY FAILURES ==='
for d in /var/jb/usr/lib/TweakInject/*.dylib; do
  [ -f "$d" ] || continue
  n="${d##*/}"
  bad=0
  deps="$(otool -L "$d" 2>/dev/null | tail -n +2 | awk '{print $1}')"
  for dep in $deps; do
    case "$dep" in
      /System/*|/usr/lib/libSystem*|/usr/lib/libobjc*|/usr/lib/libc++*|/usr/lib/libsqlite3*|/usr/lib/libz*|/usr/lib/libxml2*|/usr/lib/libarchive*|/usr/lib/libcompression*|@rpath/*|@loader_path/*|@executable_path/*)
        continue ;;
    esac
    if [ -e "$dep" ] || [ -e "/var/jb$dep" ]; then
      continue
    fi
    if [ "$bad" = 0 ]; then echo "===== MISSING_DEPS $n ====="; bad=1; fi
    echo "missing=$dep"
  done
done

echo
echo '=== MALFORMED FILTER PLISTS ==='
for p in /var/jb/usr/lib/TweakInject/*.plist; do
  [ -f "$p" ] || continue
  plutil -lint "$p" >/dev/null 2>&1 || echo "bad_plist=$p"
done

echo
echo '=== DISABLED TWEAK PAYLOADS ==='
find /var/jb/usr/lib/TweakInject -maxdepth 1 -type f -name '*.disabled' -print 2>/dev/null | sort || true

echo
echo '=== PACKAGE OWNERS FOR SPRINGBOARD TWEAKS ==='
for p in /var/jb/usr/lib/TweakInject/*.plist; do
  [ -f "$p" ] || continue
  strings "$p" 2>/dev/null | grep -Eqi 'com\.apple\.springboard|SpringBoard' || continue
  n="${p##*/}"; n="${n%.plist}"
  rel="/usr/lib/TweakInject/$n.dylib"
  owner="$(grep -l -F "$rel" /var/jb/var/lib/dpkg/info/*.list /var/jb/Library/dpkg/info/*.list 2>/dev/null | head -n1 | sed -E 's#.*/##;s/\.list$//')"
  [ -n "$owner" ] || owner=unknown
  ver="$(dpkg-query -W -f='${Version}' "$owner" 2>/dev/null)"
  echo "$n | owner=$owner | version=$ver"
done

echo 'TWEAK_FUNCTIONALITY_AUDIT_COMPLETE=1'
exit 0

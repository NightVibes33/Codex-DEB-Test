#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

echo '=== TrollStore installation verification ==='
printf 'verified_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true

if [ -f /System/Library/CoreServices/SystemVersion.plist ] && command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY'
import plistlib
p='/System/Library/CoreServices/SystemVersion.plist'
with open(p,'rb') as f: d=plistlib.load(f)
print('ios_version=' + str(d.get('ProductVersion','')))
print('ios_build=' + str(d.get('ProductBuildVersion','')))
PY
fi

echo '=== Package database ==='
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='package=${Package} version=${Version} status=${db:Status-Abbrev}\n' 2>/dev/null | grep -Ei 'trollstore|trollhelper|troll' || true
else
  echo 'dpkg_query=missing'
fi

echo '=== Registered apps mentioning TrollStore ==='
if command -v uicache >/dev/null 2>&1; then
  uicache -l 2>/dev/null | grep -i -A3 -B2 troll || true
else
  echo 'uicache=missing'
fi

echo '=== App bundles ==='
find \
  /var/containers/Bundle/Application \
  /private/var/containers/Bundle/Application \
  /Applications \
  /var/jb/Applications \
  /private/preboot \
  -maxdepth 7 -type d \( -iname '*TrollStore*.app' -o -iname '*TrollHelper*.app' -o -iname '*PersistenceHelper*.app' \) 2>/dev/null | sort -u > /tmp/trollstore-apps.txt || true

if [ ! -s /tmp/trollstore-apps.txt ]; then
  echo 'trollstore_app_bundles=0'
else
  printf 'trollstore_app_bundles='; wc -l < /tmp/trollstore-apps.txt | tr -d ' '
  while IFS= read -r app; do
    echo '---'
    echo "app_path=$app"
    if [ -f "$app/Info.plist" ] && command -v python3 >/dev/null 2>&1; then
      python3 - "$app/Info.plist" <<'PY'
import plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: d=plistlib.load(f)
except Exception as e:
    print('plist_error='+type(e).__name__)
    raise SystemExit
for key,label in [
 ('CFBundleDisplayName','display_name'),
 ('CFBundleName','bundle_name'),
 ('CFBundleIdentifier','bundle_id'),
 ('CFBundleShortVersionString','short_version'),
 ('CFBundleVersion','bundle_version'),
 ('CFBundleExecutable','executable')]:
    print(label+'='+str(d.get(key,'')))
PY
    fi
    exe=""
    if command -v python3 >/dev/null 2>&1 && [ -f "$app/Info.plist" ]; then
      exe=$(python3 - "$app/Info.plist" <<'PY'
import plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: d=plistlib.load(f)
    print(d.get('CFBundleExecutable',''))
except Exception: pass
PY
)
    fi
    if [ -n "$exe" ] && [ -f "$app/$exe" ]; then
      printf 'binary_size='; stat -f '%z' "$app/$exe" 2>/dev/null || stat -c '%s' "$app/$exe" 2>/dev/null || true
      printf 'binary_type='; file "$app/$exe" 2>/dev/null || true
      if command -v ldid >/dev/null 2>&1; then
        echo 'entitlements_begin'
        ldid -e "$app/$exe" 2>/dev/null | grep -E 'platform-application|private.security|application-identifier|no-container|unsandboxed|get-task-allow' || true
        echo 'entitlements_end'
      fi
    fi
  done < /tmp/trollstore-apps.txt
fi

echo '=== TrollStore support files and helpers ==='
for p in \
  /var/mobile/Library/TrollStore \
  /private/var/mobile/Library/TrollStore \
  /var/containers/Bundle/Application/.TrollStore \
  /private/var/containers/Bundle/Application/.TrollStore \
  /usr/local/bin/trollstorehelper \
  /var/jb/usr/local/bin/trollstorehelper \
  /var/jb/usr/bin/trollstorehelper \
  /private/preboot/*/jb/usr/local/bin/trollstorehelper; do
  for match in $p; do
    [ -e "$match" ] && echo "support_path=$match"
  done
done

echo '=== Running processes ==='
ps -ax -o pid=,comm= 2>/dev/null | grep -Ei 'TrollStore|trollstore|trollhelper|PersistenceHelper' || true

echo 'verification=read-only-complete'

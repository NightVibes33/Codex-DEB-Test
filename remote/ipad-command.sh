#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'

echo '=== Gif2Ani Settings crash collection ==='
printf 'collected_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || true
printf 'settings_bundle='; file "$BUNDLE/Gif2AniPrefs" 2>/dev/null || true
printf 'theme_catalog_bytes='; wc -c < "$BUNDLE/ThemeCatalog.json" 2>/dev/null || echo missing
printf 'open_catalog_bytes='; wc -c < "$BUNDLE/OpenThemeCatalog.json" 2>/dev/null || echo missing
printf 'preferences_exists='; [ -f "$PREFS" ] && echo true || echo false

printf 'preferences_processes_before='; ps -A 2>/dev/null | grep '[P]references' | tr '\n' ' ' || true
echo

echo '=== newest relevant crash files ==='
FILES="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' -o -name 'SpringBoard-*.ips' \) -print 2>/dev/null | while IFS= read -r f; do stat -f '%m %N' "$f" 2>/dev/null || stat -c '%Y %n' "$f" 2>/dev/null || true; done | sort -rn | head -n 5 | cut -d' ' -f2-)"

if [ -z "$FILES" ]; then
  echo 'relevant_crash_files=none'
  exit 2
fi

count=0
printf '%s\n' "$FILES" | while IFS= read -r crash; do
  [ -n "$crash" ] || continue
  count=$((count + 1))
  echo "--- crash_file_$count=$crash ---"
  printf 'mtime='; stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%SZ' "$crash" 2>/dev/null || stat -c '%y' "$crash" 2>/dev/null || true
  printf 'bytes='; wc -c < "$crash" 2>/dev/null || true
  echo '--- key crash lines ---'
  grep -E -i -m 120 'incident|crashReporterKey|process|bundle|exception|termination|reason|signal|faulting|triggered by|last exception|backtrace|abort|selector|unrecognized|NSInvalidArgument|NSInternalInconsistency|SIGABRT|EXC_|Gif2Ani|G2Theme|G2Open|G2Remote|Preference' "$crash" 2>/dev/null || true
  echo '--- crash head ---'
  sed -n '1,220p' "$crash" 2>/dev/null || true
  echo "--- end crash_file_$count ---"
done

echo 'crash_collection=complete'

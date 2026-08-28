#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

OUT='/var/mobile/Media/HiddenGestaltPull'
rm -rf "$OUT"
mkdir -p "$OUT"

echo '=== HIDDEN: LIVE MOBILEGESTALT PULL ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true

TERMS='internal|debug|developer|development|diagnostic|menu|hidden|prototype|experiment|feature|capabil|gestalt|siri|assistant|camera|springboard|controlcenter|multitask|stage|carplay|alwayson|battery|face.?id|touch.?id|wallet|telephony'

echo '--- locate MobileGestalt files/caches ---'
find /var/containers/Shared/SystemGroup /private/var/containers/Shared/SystemGroup /var/mobile/Library /private/var/mobile/Library /System/Library \
  -maxdepth 8 -type f \( -iname '*gestalt*' -o -iname '*mobilegestalt*' -o -iname '*capabilit*' \) -print 2>/dev/null \
  | sort -u | tee "$OUT/gestalt-files.txt" | sed -n '1,240p'

echo '--- known MobileGestalt cache roots ---'
find /var/containers/Shared/SystemGroup /private/var/containers/Shared/SystemGroup \
  -maxdepth 7 -type d \( -iname '*mobilegestalt*' -o -iname '*gestalt*' \) -print 2>/dev/null \
  | sort -u | tee "$OUT/gestalt-dirs.txt" | sed -n '1,160p'

echo '--- dump candidate plist/json/text files and filter high-signal terms ---'
: > "$OUT/high-signal.txt"
COUNT=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  COUNT=$((COUNT + 1))
  echo "### FILE=$f" >> "$OUT/high-signal.txt"
  if command -v plutil >/dev/null 2>&1; then
    plutil -p "$f" 2>/dev/null | grep -Eai "$TERMS" | sed -n '1,260p' >> "$OUT/high-signal.txt"
  fi
  strings -a "$f" 2>/dev/null | grep -Eai "$TERMS" | sed -n '1,260p' >> "$OUT/high-signal.txt"
  echo >> "$OUT/high-signal.txt"
done < "$OUT/gestalt-files.txt"
echo "candidate_file_count=$COUNT"

echo '--- search gestalt directories for plist/cache payloads ---'
: > "$OUT/cache-high-signal.txt"
while IFS= read -r d; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 5 -type f -print 2>/dev/null | while IFS= read -r f; do
    echo "### FILE=$f" >> "$OUT/cache-high-signal.txt"
    if command -v plutil >/dev/null 2>&1; then
      plutil -p "$f" 2>/dev/null | grep -Eai "$TERMS" | sed -n '1,320p' >> "$OUT/cache-high-signal.txt"
    fi
    strings -a "$f" 2>/dev/null | grep -Eai "$TERMS" | sed -n '1,320p' >> "$OUT/cache-high-signal.txt"
    echo >> "$OUT/cache-high-signal.txt"
  done
done < "$OUT/gestalt-dirs.txt"

# Also inspect Apple's internal Settings manifests because they name the exact capability keys that gate menus.
echo '--- internal Settings manifest capability gates ---'
: > "$OUT/settings-gates.txt"
for root in /System/Library/PreferenceManifestsInternal /System/Library/PreferenceBundles; do
  [ -d "$root" ] || continue
  find "$root" -type f \( -name '*.plist' -o -name '*.strings' \) -print 2>/dev/null | while IFS= read -r f; do
    HITS="$(plutil -p "$f" 2>/dev/null | grep -Eai 'requiredCapabilities|requiredDeviceCapabilities|featureFlag|internal|developer|debug|prototype|experiment|hidden|predicate|condition' | sed -n '1,100p')"
    if [ -n "$HITS" ]; then
      echo "### FILE=$f" >> "$OUT/settings-gates.txt"
      printf '%s\n' "$HITS" >> "$OUT/settings-gates.txt"
      echo >> "$OUT/settings-gates.txt"
    fi
  done
done

echo '--- HIGH SIGNAL: MobileGestalt files ---'
sed -n '1,900p' "$OUT/high-signal.txt"
echo '--- HIGH SIGNAL: MobileGestalt cache roots ---'
sed -n '1,1200p' "$OUT/cache-high-signal.txt"
echo '--- HIGH SIGNAL: Settings capability gates ---'
sed -n '1,1200p' "$OUT/settings-gates.txt"

echo '--- artifact summary ---'
for f in "$OUT"/*.txt; do
  [ -f "$f" ] || continue
  printf '%s lines=' "$f"
  wc -l < "$f"
done

echo "GESTALT_PULL_DIR=$OUT"
echo 'HIDDEN_GESTALT_PULL_COMPLETE=true'
exit 0

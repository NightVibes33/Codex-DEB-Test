#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }
INFO=/var/jb/var/lib/dpkg/info
TI=/var/jb/usr/lib/TweakInject
MS=/var/jb/Library/MobileSubstrate/DynamicLibraries
TMP=/tmp/tweak-inventory.$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT INT TERM

printf '%s\n' '=== FULL IPHONE TWEAK PACKAGE INVENTORY V2 ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

section 'BOOTSTRAP PATH TOPOLOGY'
for p in /var/jb "$TI" "$MS" /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences /Library/MobileSubstrate/DynamicLibraries /usr/lib/TweakInject /Library/PreferenceBundles /Library/PreferenceLoader/Preferences; do
  if [ -e "$p" ] || [ -L "$p" ]; then ls -ld "$p" 2>/dev/null; else echo "MISSING $p"; fi
done

section 'DPKG AUDIT'
dpkg --audit 2>&1 | head -n 120

section 'CORE INJECTION PACKAGES'
for pkg in ellekit preferenceloader applist rocketbootstrap xyz.cypwn.tweaksettings; do
  dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Section}\t${db:Status-Abbrev}\t${Description}\n' "$pkg" 2>/dev/null
done

section 'ALL INSTALLED PACKAGES WITH TWEAK-LIKE METADATA'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Section}\t${db:Status-Abbrev}\t${Description}\n' 2>/dev/null > "$TMP/all-packages.tsv"
grep -Ei '\t(tweak|tweaks|system|utilities|development|themes)\t|tweak|substrate|ellekit|springboard|preference|hook|patch|crack|jailbreak' "$TMP/all-packages.tsv" | head -n 350

section 'SINGLE-PASS PACKAGE MANIFEST INDEX'
: > "$TMP/owners.tsv"
: > "$TMP/tweak-packages.txt"
count=0
for lf in "$INFO"/*.list; do
  [ -f "$lf" ] || continue
  pkg=$(basename "$lf" .list)
  grep -E '/(var/jb/)?(Library/MobileSubstrate/DynamicLibraries|usr/lib/TweakInject|Library/PreferenceBundles|Library/PreferenceLoader/Preferences|Applications/[^/]+\.app)(/|$)' "$lf" 2>/dev/null > "$TMP/matches"
  [ -s "$TMP/matches" ] || continue
  count=$((count+1))
  echo "$pkg" >> "$TMP/tweak-packages.txt"
  echo "--- PACKAGE $pkg ---"
  dpkg-query -W -f='version=${Version}\narch=${Architecture}\nsection=${Section}\nstatus=${db:Status-Abbrev}\ndescription=${Description}\n' "$pkg" 2>/dev/null
  echo 'interesting_files:'
  head -n 120 "$TMP/matches"
  missing=0
  while IFS= read -r f; do
    printf '%s\t%s\n' "$f" "$pkg" >> "$TMP/owners.tsv"
    case "$f" in
      */Library/MobileSubstrate/DynamicLibraries/*|*/usr/lib/TweakInject/*|*/Library/PreferenceBundles/*|*/Library/PreferenceLoader/Preferences/*)
        if [ ! -e "$f" ] && [ ! -L "$f" ]; then
          echo "MISSING_ON_DISK=$f"
          missing=$((missing+1))
        fi
        ;;
    esac
  done < "$TMP/matches"
  echo "missing_interesting_files=$missing"
done
echo "tweak_like_package_count=$count"
echo 'tweak_like_package_names:'
cat "$TMP/tweak-packages.txt" 2>/dev/null

section 'ACTUAL INJECTION FILES AND OWNER LOOKUP'
for f in "$TI"/*.dylib "$TI"/*.plist; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  base=$(basename "$f")
  echo "FILE=$f"
  owner=$(awk -F '\t' -v b="/$base" 'index($1,b)==length($1)-length(b)+1 {print $2; exit}' "$TMP/owners.tsv" 2>/dev/null)
  if [ -n "$owner" ]; then
    echo "OWNER=$owner"
    dpkg-query -W -f='version=${Version} arch=${Architecture} status=${db:Status-Abbrev} description=${Description}\n' "$owner" 2>/dev/null
  else
    echo 'OWNER=ORPHAN_OR_MANUAL_FILE'
  fi
done

section 'ROOTFUL / WRONG-PREFIX FILES'
for root in /Library/MobileSubstrate/DynamicLibraries /usr/lib/TweakInject /Library/PreferenceBundles /Library/PreferenceLoader/Preferences; do
  if [ -d "$root" ]; then
    echo "ROOTFUL_DIR=$root"
    find "$root" -maxdepth 2 \( -type f -o -type l \) -print 2>/dev/null | head -n 200
  fi
done

section 'INSTALLED ROOTFUL-ARCH PACKAGES'
awk -F '\t' '$3=="iphoneos-arm" {print}' "$TMP/all-packages.tsv" | head -n 300

section 'PREFERENCE UI INVENTORY'
echo 'PreferenceLoader entries:'
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -name '*.plist' -print 2>/dev/null | sort
echo 'Preference bundles:'
find /var/jb/Library/PreferenceBundles -maxdepth 1 -type d -name '*.bundle' -print 2>/dev/null | sort
echo 'Dedicated jailbreak apps:'
find /var/jb/Applications -maxdepth 1 -type d -name '*.app' -print 2>/dev/null | sort

section 'DOPAMINE / ELLEKIT SETTINGS AND DISABLE MARKERS'
for f in /var/mobile/Library/Preferences/com.opa334.Dopamine.plist /var/mobile/Library/Preferences/com.opa334.ElleKit.plist /var/jb/var/mobile/Library/Preferences/com.opa334.Dopamine.plist; do
  if [ -f "$f" ]; then
    echo "PLIST=$f"
    plutil -p "$f" 2>/dev/null | head -n 160
    strings "$f" 2>/dev/null | grep -Ei 'tweak|inject|disable|safe|ellekit' | head -n 80
  fi
done
find /var/jb /var/mobile -maxdepth 5 \( -iname '*safe*mode*' -o -iname '*disable*tweak*' -o -iname '*ellekit*disable*' \) -print 2>/dev/null | head -n 120

section 'CURRENT JAILBREAK SERVICES'
launchctl list 2>/dev/null | grep -Ei 'ellekit|rocket|substrate|substitute|dopamine|preference' | head -n 120

printf '%s\n' '=== END FULL TWEAK PACKAGE INVENTORY V2 ==='

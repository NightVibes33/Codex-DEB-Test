#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo '=== CYPWN REPO INVENTORY ==='
echo "captured_at=$(date 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== CYPWN SOURCES =====\n'
grep -RHiE 'cypwn|CyPwn' /var/jb/etc/apt/sources.list /var/jb/etc/apt/sources.list.d 2>/dev/null || true

printf '\n===== CYPWN APT LIST FILES =====\n'
find /var/jb/var/lib/apt/lists -maxdepth 1 -type f -print 2>/dev/null | grep -i cypwn || true

printf '\n===== INSTALLED CYPWN PACKAGES =====\n'
dpkg-query -W -f='${Status}\t${Package}\t${Version}\t${Architecture}\t${binary:Summary}\n' 2>/dev/null | grep -iE '\t(xyz\.cypwn\.|cypwn\.)' | sort || true

printf '\n===== AVAILABLE CYPWN-ID PACKAGES =====\n'
apt-cache pkgnames 2>/dev/null | grep -Ei '^(xyz\.cypwn\.|cypwn\.)' | sort -u | while IFS= read -r p; do
  [ -n "$p" ] || continue
  cand=$(apt-cache policy "$p" 2>/dev/null | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p' | head -n1)
  [ -n "$cand" ] || cand=none
  meta=$(apt-cache show "$p" 2>/dev/null | sed -n '1,/^$/p' | grep -E '^(Package|Version|Architecture|Depends|Pre-Depends|Description):' | tr '\n' '|' )
  installed=$(dpkg-query -W -f='${Status}' "$p" 2>/dev/null)
  case "$installed" in *'install ok installed'*) state=INSTALLED ;; *) state=AVAILABLE ;; esac
  printf '%s\t%s\tcandidate=%s\t%s\n' "$state" "$p" "$cand" "$meta"
done

printf '\n===== KEYWORD CANDIDATES FROM CYPWN LIST FILES =====\n'
for f in /var/jb/var/lib/apt/lists/*cypwn*Packages* /var/jb/var/lib/apt/lists/*Cypwn*Packages*; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  grep -E '^(Package|Name|Version|Architecture|Depends|Description):' "$f" 2>/dev/null | grep -Ei 'theme|springboard|lock|control|gesture|status|dock|icon|battery|keyboard|notification|tweak|custom|home|app switch|volume|music|camera|clipboard|settings|widget|animation|color|font|rootless|iphoneos-arm64|^Package:|^Name:|^Version:|^Architecture:' | head -n 700 || true
done

printf '\n===== END CYPWN REPO INVENTORY =====\n'

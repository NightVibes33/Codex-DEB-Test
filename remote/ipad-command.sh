#!/bin/sh
# bridge-retrigger=2026-07-26T11:02:00-05:00
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile
WORK='/tmp/gif2ani-snowboard-inventory'
rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

printf '%s\n' '=== Inventory SnowBoard Respring packs from configured iPad repositories ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'gif2ani_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent
printf 'snowboard_version='; dpkg-query -W -f='${Version}\n' com.spark.snowboard 2>/dev/null || echo absent
printf 'respring_extension_version='; dpkg-query -W -f='${Version}\n' com.spark.snowboard.respringextension 2>/dev/null || echo absent

echo '--- configured_sources ---'
for f in /var/jb/etc/apt/sources.list /var/jb/etc/apt/sources.list.d/*.list /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
  [ -f "$f" ] || continue
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$f" | while IFS= read -r line; do printf 'source=%s|%s\n' "$f" "$line"; done
done

echo '--- repository_candidates ---'
apt-cache dumpavail > "$WORK/dumpavail.txt"
python3 - "$WORK/dumpavail.txt" "$WORK/candidates.tsv" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text(errors='replace')
records = []
for stanza in re.split(r'\n\s*\n', text):
    fields = {}
    current = None
    for raw in stanza.splitlines():
        if raw.startswith((' ', '\t')) and current:
            fields[current] = fields.get(current, '') + ' ' + raw.strip()
            continue
        if ':' not in raw:
            continue
        key, value = raw.split(':', 1)
        current = key.strip()
        fields[current] = value.strip()
    package = fields.get('Package', '')
    if not package:
        continue
    joined = ' '.join(fields.get(k, '') for k in ('Package','Name','Description','Depends','Section')).lower()
    depends = fields.get('Depends', '').lower()
    is_candidate = (
        'com.spark.snowboard.respringextension' in depends
        or ('snowboard' in joined and 'respring' in joined)
        or ('respring' in joined and 'com.spark.snowboard' in depends)
    )
    if not is_candidate:
        continue
    records.append(fields)
records.sort(key=lambda x: (x.get('Name') or x.get('Package','')).lower())
out = []
for f in records:
    values = [
        f.get('Package',''), f.get('Name',''), f.get('Version',''), f.get('Architecture',''),
        f.get('Filename',''), f.get('Size',''), f.get('SHA256',''), f.get('Depends',''),
        f.get('Section',''), f.get('Description',''), f.get('Homepage',''), f.get('Depiction','')
    ]
    values = [re.sub(r'[\t\r\n]+', ' ', v).strip() for v in values]
    out.append('\t'.join(values))
pathlib.Path(sys.argv[2]).write_text('\n'.join(out) + ('\n' if out else ''))
print(f'repository_candidate_count={len(records)}')
for i, f in enumerate(records, 1):
    print('repo_pack_%03d=%s|%s|%s|%s|%s|%s' % (
        i, f.get('Package',''), f.get('Name',''), f.get('Version',''),
        f.get('Filename',''), f.get('Size',''), f.get('SHA256','')))
PY

echo '--- installed_theme_directories ---'
python3 - <<'PY'
from pathlib import Path
import os, re, subprocess
roots = [Path('/var/jb/Library/Themes'), Path('/Library/Themes')]
seen = set(); rows=[]
image_ext={'.png','.jpg','.jpeg','.gif','.webp'}
for root in roots:
    if not root.is_dir():
        continue
    for theme in sorted(root.iterdir(), key=lambda p:p.name.lower()):
        if not theme.is_dir() or theme.name.startswith('.'):
            continue
        files=[]
        try:
            for p in theme.rglob('*'):
                try:
                    if p.is_file() and p.suffix.lower() in image_ext:
                        files.append(p)
                except OSError:
                    pass
        except OSError:
            continue
        lower=(' '.join([theme.name] + [str(p.relative_to(theme)) for p in files[:200]])).lower()
        likely=('respring' in lower or 'bootlogo' in lower or any('respring' in p.name.lower() for p in files))
        if not likely or not files:
            continue
        canonical=str(theme.resolve())
        if canonical in seen: continue
        seen.add(canonical)
        owner=''
        try:
            sample=str(files[0])
            owner=subprocess.check_output(['dpkg-query','-S',sample], text=True, stderr=subprocess.DEVNULL).split(':',1)[0].strip()
        except Exception:
            pass
        rows.append((theme.name, canonical, owner, len(files), min(len(p.read_bytes()) for p in files[:20]) if files else 0))
print(f'installed_respring_theme_count={len(rows)}')
for i,(name,path,owner,count,_dummy) in enumerate(rows,1):
    clean=lambda s: re.sub(r'[|\r\n]+',' ',s).strip()
    print(f'installed_theme_{i:03d}={clean(name)}|{clean(owner)}|{count}|{clean(path)}')
PY

echo '--- candidate_downloadability ---'
TAB="$(printf '\t')"
COUNT=0
DOWNLOADABLE=0
while IFS="$TAB" read -r PACKAGE NAME VERSION ARCH FILENAME SIZE SHA DEPENDS SECTION DESCRIPTION HOMEPAGE DEPICTION; do
  [ -n "$PACKAGE" ] || continue
  COUNT=$((COUNT + 1))
  mkdir -p "$WORK/download-$COUNT"
  cd "$WORK/download-$COUNT"
  set +e
  apt download "$PACKAGE=$VERSION" >download.log 2>&1
  STATUS=$?
  set -e
  DEB="$(find . -maxdepth 1 -type f -name '*.deb' -print -quit)"
  if [ "$STATUS" -eq 0 ] && [ -n "$DEB" ] && [ -s "$DEB" ]; then
    ACTUAL_PACKAGE="$(dpkg-deb -f "$DEB" Package 2>/dev/null | tr -d '\r\n')"
    ACTUAL_NAME="$(dpkg-deb -f "$DEB" Name 2>/dev/null | tr -d '\r\n')"
    ACTUAL_VERSION="$(dpkg-deb -f "$DEB" Version 2>/dev/null | tr -d '\r\n')"
    ACTUAL_SIZE="$(wc -c < "$DEB" | tr -d ' ')"
    ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
    THEME_FILES="$(dpkg-deb -c "$DEB" 2>/dev/null | grep -E '/Library/Themes/.*(Respring|respring|BootLogo|bootlogo)|/Library/Themes/.*\.(png|gif|jpg|jpeg|webp)$' | wc -l | tr -d ' ')"
    if [ "$ACTUAL_PACKAGE" = "$PACKAGE" ] && [ "$ACTUAL_VERSION" = "$VERSION" ] && [ "$THEME_FILES" -gt 0 ]; then
      DOWNLOADABLE=$((DOWNLOADABLE + 1))
      printf 'downloadable_%03d=passed|%s|%s|%s|%s|%s|theme_files=%s\n' "$DOWNLOADABLE" "$ACTUAL_PACKAGE" "$ACTUAL_NAME" "$ACTUAL_VERSION" "$ACTUAL_SIZE" "$ACTUAL_SHA" "$THEME_FILES"
    else
      printf 'candidate_%03d=metadata_or_payload_mismatch|%s|actual=%s|version=%s|theme_files=%s\n' "$COUNT" "$PACKAGE" "$ACTUAL_PACKAGE" "$ACTUAL_VERSION" "$THEME_FILES"
    fi
  else
    REASON="$(tail -n 1 download.log 2>/dev/null | tr '|\r\n' '   ')"
    printf 'candidate_%03d=not_directly_downloadable|%s|%s\n' "$COUNT" "$PACKAGE" "$REASON"
  fi
  cd "$WORK"
done < "$WORK/candidates.tsv"
printf 'candidate_download_attempts=%s\n' "$COUNT"
printf 'verified_direct_download_count=%s\n' "$DOWNLOADABLE"
echo 'snowboard_inventory_complete=success'

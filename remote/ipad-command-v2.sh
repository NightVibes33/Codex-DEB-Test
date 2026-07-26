#!/bin/sh
set -u
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
SPRINGY_CATALOG="$BUNDLE/OpenThemeCatalog.json"
SNOWBOARD_CATALOG="$BUNDLE/SnowBoardCatalog.json"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
DIAGNOSTIC="$MEDIA_ROOT/LastPackageVerification.plist"
WORK='/tmp/gif2ani-358-fixed-sample-audit'
FAILURES=0

printf '%s\n' '=== Gif2Ani 3.5.8 corrected Springy and SnowBoard sample audit ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani 2>/dev/null || true)"
printf 'installed_version=%s\n' "$VERSION_NOW"
[ "$VERSION_NOW" = '3.5.8' ] || FAILURES=$((FAILURES + 1))

rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

python3 - "$SPRINGY_CATALOG" "$SNOWBOARD_CATALOG" "$WORK/tests.psv" <<'PY'
import json, pathlib, sys
springy=json.loads(pathlib.Path(sys.argv[1]).read_text())
snowboard=json.loads(pathlib.Path(sys.argv[2]).read_text())
sp=next(x for x in springy['themes'] if x['name']=='Gameboy Advance')
sb=next(x for x in snowboard['themes'] if x['package']=='com.thwlfu.cakrespring')
rows=[]
for kind, x in [('springy',sp),('snowboard',sb)]:
    fields=[kind,x['package'],str(x['bytes']),x['sha256'],x['downloadURL'],x.get('archiveSubpath',''),x['name']]
    assert all('|' not in value and '\n' not in value for value in fields)
    rows.append('|'.join(fields))
    print(f"catalog_{kind}_name={x['name']}")
    print(f"catalog_{kind}_package={x['package']}")
    print(f"catalog_{kind}_bytes={x['bytes']}")
    print(f"catalog_{kind}_sha256={x['sha256']}")
    print(f"catalog_{kind}_archive_subpath={x.get('archiveSubpath','')}")
pathlib.Path(sys.argv[3]).write_text('\n'.join(rows)+'\n')
PY

mkdir -p "$MEDIA_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
INDEX=0
while IFS='|' read -r KIND EXPECTED_PACKAGE EXPECTED_BYTES EXPECTED_SHA DOWNLOAD_URL ARCHIVE_SUBPATH DISPLAY_NAME; do
  INDEX=$((INDEX + 1))
  CASE_DIR="$WORK/$KIND"
  DEB="$CASE_DIR/theme.deb"
  EXTRACTED="$CASE_DIR/extracted"
  STDOUT_FILE="$CASE_DIR/package.stdout"
  STDERR_FILE="$CASE_DIR/package.stderr"
  mkdir -p "$CASE_DIR" "$EXTRACTED"
  chown -R mobile:mobile "$CASE_DIR"

  printf '%s_test_name=%s\n' "$KIND" "$DISPLAY_NAME"
  printf '%s_archive_subpath_value=%s\n' "$KIND" "${ARCHIVE_SUBPATH:-<empty>}"
  EFFECTIVE_URL="$(sudo -u mobile curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$DEB" --write-out '%{url_effective}' "$DOWNLOAD_URL" 2>"$CASE_DIR/curl.stderr")"
  CURL_STATUS=$?
  printf '%s_curl_status=%s\n' "$KIND" "$CURL_STATUS"
  printf '%s_effective_url=%s\n' "$KIND" "$EFFECTIVE_URL"
  if [ "$CURL_STATUS" -ne 0 ] || [ ! -s "$DEB" ]; then
    FAILURES=$((FAILURES + 1))
    continue
  fi

  ACTUAL_BYTES="$(wc -c < "$DEB" | tr -d ' ')"
  ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
  OWNER_UID="$(ls -dn "$DEB" | awk '{print $3}')"
  sudo -u mobile sh -c 'dpkg-deb -f "$1" Package >"$2" 2>"$3"' sh "$DEB" "$STDOUT_FILE" "$STDERR_FILE"
  DPKG_STATUS=$?
  ACTUAL_PACKAGE="$(tr -d '\r\n' < "$STDOUT_FILE")"

  printf '%s_expected_bytes=%s\n' "$KIND" "$EXPECTED_BYTES"
  printf '%s_actual_bytes=%s\n' "$KIND" "$ACTUAL_BYTES"
  printf '%s_bytes_match=%s\n' "$KIND" "$( [ "$ACTUAL_BYTES" = "$EXPECTED_BYTES" ] && echo true || echo false )"
  printf '%s_expected_sha256=%s\n' "$KIND" "$EXPECTED_SHA"
  printf '%s_actual_sha256=%s\n' "$KIND" "$ACTUAL_SHA"
  printf '%s_sha256_match=%s\n' "$KIND" "$( [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] && echo true || echo false )"
  printf '%s_expected_package=%s\n' "$KIND" "$EXPECTED_PACKAGE"
  printf '%s_actual_package=%s\n' "$KIND" "$ACTUAL_PACKAGE"
  printf '%s_package_match=%s\n' "$KIND" "$( [ "$ACTUAL_PACKAGE" = "$EXPECTED_PACKAGE" ] && echo true || echo false )"
  printf '%s_dpkg_deb_status=%s\n' "$KIND" "$DPKG_STATUS"
  printf '%s_owner_uid=%s\n' "$KIND" "$OWNER_UID"
  if [ -s "$STDERR_FILE" ]; then
    printf '%s_dpkg_deb_stderr=' "$KIND"; tr '\n' ' ' < "$STDERR_FILE"; echo
  else
    printf '%s_dpkg_deb_stderr=(empty)\n' "$KIND"
  fi

  rm -rf "$EXTRACTED"
  mkdir -p "$EXTRACTED"
  dpkg-deb -x "$DEB" "$EXTRACTED" >"$CASE_DIR/extract.stdout" 2>"$CASE_DIR/extract.stderr"
  EXTRACT_STATUS=$?
  printf '%s_extract_status=%s\n' "$KIND" "$EXTRACT_STATUS"

  if [ -n "$ARCHIVE_SUBPATH" ]; then
    if [ -d "$EXTRACTED/$ARCHIVE_SUBPATH" ]; then
      printf '%s_archive_subpath_present=true\n' "$KIND"
      MEDIA_ROOT_FOR_TEST="$EXTRACTED/$ARCHIVE_SUBPATH"
    else
      printf '%s_archive_subpath_present=false\n' "$KIND"
      MEDIA_ROOT_FOR_TEST="$EXTRACTED/__missing__"
    fi
  else
    printf '%s_archive_subpath_present=not_required\n' "$KIND"
    MEDIA_ROOT_FOR_TEST="$EXTRACTED"
  fi

  MEDIA_COUNT="$(find "$MEDIA_ROOT_FOR_TEST" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) 2>/dev/null | wc -l | tr -d ' ')"
  printf '%s_media_count=%s\n' "$KIND" "$MEDIA_COUNT"
  if [ "$KIND" = springy ]; then
    python3 - "$EXTRACTED" <<'PY'
import pathlib, sys
root=pathlib.Path(sys.argv[1])
exts={'.png','.jpg','.jpeg','.gif','.webp'}
rows=[]
for directory in [root, *[p for p in root.rglob('*') if p.is_dir()]]:
    count=sum(1 for p in directory.iterdir() if p.is_file() and p.suffix.lower() in exts)
    if count:
        rows.append((count,str(directory.relative_to(root))))
for count,path in sorted(rows,reverse=True)[:8]:
    print(f"springy_direct_media_directory={path}|files={count}")
PY
  fi

  MATCH=true
  [ "$ACTUAL_BYTES" = "$EXPECTED_BYTES" ] || MATCH=false
  [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || MATCH=false
  [ "$ACTUAL_PACKAGE" = "$EXPECTED_PACKAGE" ] || MATCH=false
  [ "$DPKG_STATUS" -eq 0 ] || MATCH=false
  [ "$OWNER_UID" = '501' ] || MATCH=false
  [ "$EXTRACT_STATUS" -eq 0 ] || MATCH=false
  [ "$MEDIA_COUNT" -ge 1 ] || MATCH=false
  printf '%s_full_sample_match=%s\n' "$KIND" "$MATCH"
  [ "$MATCH" = true ] || FAILURES=$((FAILURES + 1))
done < "$WORK/tests.psv"

printf 'sample_count=%s\n' "$INDEX"
if [ -f "$DIAGNOSTIC" ]; then
  echo '--- LastPackageVerification.plist ---'
  plutil -p "$DIAGNOSTIC" 2>/dev/null || cat "$DIAGNOSTIC"
else
  echo 'last_package_verification=absent'
fi

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'gif2ani_gallery_reopened=true'
fi
printf 'diagnostic_failures=%s\n' "$FAILURES"
[ "$FAILURES" -eq 0 ] && echo 'gif2ani_358_springy_and_snowboard_samples=success' || echo 'gif2ani_358_springy_and_snowboard_samples=failure'
exit 0

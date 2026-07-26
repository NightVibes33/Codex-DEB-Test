#!/bin/sh
set -u
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
SPRINGY_CATALOG="$BUNDLE/OpenThemeCatalog.json"
SNOWBOARD_CATALOG="$BUNDLE/SnowBoardCatalog.json"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
DIAGNOSTIC="$MEDIA_ROOT/LastPackageVerification.plist"
WORK='/tmp/gif2ani-358-sample-diagnostic'
FAILURES=0

printf '%s\n' '=== Gif2Ani 3.5.8 non-aborting sample diagnostic ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani 2>/dev/null || true)"
printf 'installed_version=%s\n' "$VERSION_NOW"
[ "$VERSION_NOW" = '3.5.8' ] || FAILURES=$((FAILURES + 1))

rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

python3 - "$SPRINGY_CATALOG" "$SNOWBOARD_CATALOG" "$WORK/tests.tsv" <<'PY'
import json, pathlib, sys
springy=json.loads(pathlib.Path(sys.argv[1]).read_text())
snowboard=json.loads(pathlib.Path(sys.argv[2]).read_text())
sp=next(x for x in springy['themes'] if x['name']=='Gameboy Advance')
sb=next(x for x in snowboard['themes'] if x['package']=='com.thwlfu.cakrespring')
for kind, x in [('springy',sp),('snowboard',sb)]:
    print(f"catalog_{kind}_name={x['name']}")
    print(f"catalog_{kind}_identifier={x['identifier']}")
    print(f"catalog_{kind}_package={x['package']}")
    print(f"catalog_{kind}_bytes={x['bytes']}")
    print(f"catalog_{kind}_sha256={x['sha256']}")
    print(f"catalog_{kind}_url={x['downloadURL']}")
    print(f"catalog_{kind}_archive_subpath={x.get('archiveSubpath','')}")
rows=[]
for kind, x in [('springy',sp),('snowboard',sb)]:
    rows.append('\t'.join([kind,x['package'],str(x['bytes']),x['sha256'],x['downloadURL'],x.get('archiveSubpath',''),x['name']]))
pathlib.Path(sys.argv[3]).write_text('\n'.join(rows)+'\n')
PY

mkdir -p "$MEDIA_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
TAB="$(printf '\t')"
INDEX=0
while IFS="$TAB" read -r KIND EXPECTED_PACKAGE EXPECTED_BYTES EXPECTED_SHA DOWNLOAD_URL ARCHIVE_SUBPATH DISPLAY_NAME; do
  INDEX=$((INDEX + 1))
  CASE_DIR="$WORK/$KIND"
  DEB="$CASE_DIR/theme.deb"
  EXTRACTED="$CASE_DIR/extracted"
  STDOUT_FILE="$CASE_DIR/package.stdout"
  STDERR_FILE="$CASE_DIR/package.stderr"
  mkdir -p "$CASE_DIR" "$EXTRACTED"
  chown -R mobile:mobile "$CASE_DIR"

  printf '%s_test_name=%s\n' "$KIND" "$DISPLAY_NAME"
  EFFECTIVE_URL="$(sudo -u mobile curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$DEB" --write-out '%{url_effective}' "$DOWNLOAD_URL" 2>"$CASE_DIR/curl.stderr")"
  CURL_STATUS=$?
  printf '%s_curl_status=%s\n' "$KIND" "$CURL_STATUS"
  printf '%s_effective_url=%s\n' "$KIND" "$EFFECTIVE_URL"
  if [ -s "$CASE_DIR/curl.stderr" ]; then
    printf '%s_curl_stderr=' "$KIND"; tr '\n' ' ' < "$CASE_DIR/curl.stderr"; echo
  fi
  if [ "$CURL_STATUS" -ne 0 ] || [ ! -s "$DEB" ]; then
    FAILURES=$((FAILURES + 1))
    continue
  fi

  ACTUAL_BYTES="$(wc -c < "$DEB" | tr -d ' ')"
  ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
  OWNER_UID="$(ls -dn "$DEB" | awk '{print $3}')"
  printf '%s_expected_bytes=%s\n' "$KIND" "$EXPECTED_BYTES"
  printf '%s_actual_bytes=%s\n' "$KIND" "$ACTUAL_BYTES"
  printf '%s_bytes_match=%s\n' "$KIND" "$( [ "$ACTUAL_BYTES" = "$EXPECTED_BYTES" ] && echo true || echo false )"
  printf '%s_expected_sha256=%s\n' "$KIND" "$EXPECTED_SHA"
  printf '%s_actual_sha256=%s\n' "$KIND" "$ACTUAL_SHA"
  printf '%s_sha256_match=%s\n' "$KIND" "$( [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] && echo true || echo false )"
  printf '%s_owner_uid=%s\n' "$KIND" "$OWNER_UID"

  sudo -u mobile sh -c 'dpkg-deb -f "$1" Package >"$2" 2>"$3"' sh "$DEB" "$STDOUT_FILE" "$STDERR_FILE"
  DPKG_STATUS=$?
  ACTUAL_PACKAGE="$(tr -d '\r\n' < "$STDOUT_FILE")"
  printf '%s_dpkg_deb_status=%s\n' "$KIND" "$DPKG_STATUS"
  printf '%s_expected_package=%s\n' "$KIND" "$EXPECTED_PACKAGE"
  printf '%s_actual_package=%s\n' "$KIND" "$ACTUAL_PACKAGE"
  printf '%s_package_match=%s\n' "$KIND" "$( [ "$ACTUAL_PACKAGE" = "$EXPECTED_PACKAGE" ] && echo true || echo false )"
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
      MEDIA_COUNT="$(find "$EXTRACTED/$ARCHIVE_SUBPATH" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
    else
      printf '%s_archive_subpath_present=false\n' "$KIND"
      MEDIA_COUNT=0
    fi
  else
    MEDIA_COUNT="$(find "$EXTRACTED" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
  fi
  printf '%s_media_count=%s\n' "$KIND" "$MEDIA_COUNT"

  MATCH=true
  [ "$ACTUAL_BYTES" = "$EXPECTED_BYTES" ] || MATCH=false
  [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || MATCH=false
  [ "$ACTUAL_PACKAGE" = "$EXPECTED_PACKAGE" ] || MATCH=false
  [ "$OWNER_UID" = '501' ] || MATCH=false
  [ "$EXTRACT_STATUS" -eq 0 ] || MATCH=false
  [ "$MEDIA_COUNT" -ge 1 ] || MATCH=false
  printf '%s_full_sample_match=%s\n' "$KIND" "$MATCH"
  [ "$MATCH" = true ] || FAILURES=$((FAILURES + 1))
done < "$WORK/tests.tsv"

printf 'sample_count=%s\n' "$INDEX"
if [ -f "$DIAGNOSTIC" ]; then
  echo '--- LastPackageVerification.plist ---'
  if command -v plutil >/dev/null 2>&1; then
    plutil -p "$DIAGNOSTIC" 2>/dev/null || cat "$DIAGNOSTIC"
  else
    cat "$DIAGNOSTIC"
  fi
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
echo 'gif2ani_358_sample_diagnostic=complete'
exit 0

#!/bin/sh
# fast extraction trigger 2026-08-23
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

OUT_DIR='/var/mobile/Media/WallPicsExport'
OUT_ZIP='/var/mobile/Media/WallPics-full-app.zip'
META='/var/mobile/Media/WallPics-export-info.txt'

rm -rf "$OUT_DIR" "$OUT_ZIP" "$META"
mkdir -p "$OUT_DIR"

read_plist_value() {
  key="$1"
  plist="$2"
  plutil -extract "$key" raw -o - "$plist" 2>/dev/null || true
}

match_app() {
  app="$1"
  [ -d "$app" ] || return 1
  plist="$app/Info.plist"
  base="$(basename "$app")"
  display=''
  name=''
  bundle=''
  if [ -f "$plist" ]; then
    display="$(read_plist_value CFBundleDisplayName "$plist")"
    name="$(read_plist_value CFBundleName "$plist")"
    bundle="$(read_plist_value CFBundleIdentifier "$plist")"
  fi
  haystack="$(printf '%s\n%s\n%s\n%s\n' "$base" "$display" "$name" "$bundle" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$haystack" | grep -Eq 'wall[[:space:]_-]*pics|wallpics'
}

APP=''
for p in /var/jb/Applications/WallPics.app /Applications/WallPics.app /System/Applications/WallPics.app; do
  if [ -d "$p" ]; then APP="$p"; break; fi
done

if [ -z "$APP" ]; then
  for root in /var/containers/Bundle/Application /private/var/containers/Bundle/Application; do
    [ -d "$root" ] || continue
    direct="$(find "$root" -maxdepth 2 -type d -iname '*wall*pic*.app' 2>/dev/null | sed -n '1p')"
    if [ -n "$direct" ]; then APP="$direct"; break; fi
    find "$root" -maxdepth 2 -type d -name '*.app' 2>/dev/null | while IFS= read -r candidate; do
      if match_app "$candidate"; then
        printf '%s\n' "$candidate"
        break
      fi
    done > "$OUT_DIR/matches.txt"
    APP="$(sed -n '1p' "$OUT_DIR/matches.txt" 2>/dev/null || true)"
    [ -n "$APP" ] && break
  done
fi

if [ -z "$APP" ]; then
  for root in /var/jb/Applications /Applications /System/Applications; do
    [ -d "$root" ] || continue
    direct="$(find "$root" -maxdepth 2 -type d -iname '*wall*pic*.app' 2>/dev/null | sed -n '1p')"
    if [ -n "$direct" ]; then APP="$direct"; break; fi
    find "$root" -maxdepth 2 -type d -name '*.app' 2>/dev/null | while IFS= read -r candidate; do
      if match_app "$candidate"; then
        printf '%s\n' "$candidate"
        break
      fi
    done > "$OUT_DIR/matches.txt"
    APP="$(sed -n '1p' "$OUT_DIR/matches.txt" 2>/dev/null || true)"
    [ -n "$APP" ] && break
  done
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo 'WALLPICS_EXPORT_FAIL=app_not_found'
  exit 2
fi

PLIST="$APP/Info.plist"
BUNDLE_ID='unknown'
DISPLAY_NAME='WallPics'
VERSION='unknown'
BUILD='unknown'
EXECUTABLE='unknown'
if [ -f "$PLIST" ]; then
  BUNDLE_ID="$(read_plist_value CFBundleIdentifier "$PLIST")"; [ -n "$BUNDLE_ID" ] || BUNDLE_ID='unknown'
  tmp="$(read_plist_value CFBundleDisplayName "$PLIST")"; [ -n "$tmp" ] && DISPLAY_NAME="$tmp"
  tmp="$(read_plist_value CFBundleShortVersionString "$PLIST")"; [ -n "$tmp" ] && VERSION="$tmp"
  tmp="$(read_plist_value CFBundleVersion "$PLIST")"; [ -n "$tmp" ] && BUILD="$tmp"
  tmp="$(read_plist_value CFBundleExecutable "$PLIST")"; [ -n "$tmp" ] && EXECUTABLE="$tmp"
fi

{
  echo "app_path=$APP"
  echo "display_name=$DISPLAY_NAME"
  echo "bundle_id=$BUNDLE_ID"
  echo "version=$VERSION"
  echo "build=$BUILD"
  echo "executable=$EXECUTABLE"
  echo "bundle_bytes=$(du -sk "$APP" 2>/dev/null | awk '{print $1 * 1024}')"
} > "$META"

PARENT="$(dirname "$APP")"
BASE="$(basename "$APP")"
echo "WALLPICS_ZIP_START app=$APP"

if command -v zip >/dev/null 2>&1; then
  (cd "$PARENT" && zip -0 -qry -y "$OUT_ZIP" "$BASE")
elif command -v bsdtar >/dev/null 2>&1; then
  (cd "$PARENT" && bsdtar -cf "$OUT_ZIP" --format zip "$BASE")
else
  echo 'WALLPICS_EXPORT_FAIL=no_zip_tool'
  exit 3
fi

[ -s "$OUT_ZIP" ] || { echo 'WALLPICS_EXPORT_FAIL=empty_zip'; exit 4; }
ZIP_BYTES="$(stat -f '%z' "$OUT_ZIP" 2>/dev/null || wc -c < "$OUT_ZIP")"
SHA256="$(sha256sum "$OUT_ZIP" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$OUT_ZIP" 2>/dev/null | awk '{print $1}' || true)"

echo "WALLPICS_APP_PATH=$APP"
echo "WALLPICS_DISPLAY_NAME=$DISPLAY_NAME"
echo "WALLPICS_BUNDLE_ID=$BUNDLE_ID"
echo "WALLPICS_VERSION=$VERSION"
echo "WALLPICS_BUILD=$BUILD"
echo "WALLPICS_ZIP=$OUT_ZIP"
echo "WALLPICS_ZIP_BYTES=$ZIP_BYTES"
echo "WALLPICS_SHA256=$SHA256"
echo 'WALLPICS_EXPORT=SUCCESS'

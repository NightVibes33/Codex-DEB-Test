#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 APP_BUNDLE ROOTD_BINARY OUTPUT_DEB" >&2
  exit 2
fi

APP_BUNDLE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
ROOTD_BINARY="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
OUTPUT_DEB="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

mkdir -p \
  "$ROOT/DEBIAN" \
  "$ROOT/var/jb/Applications" \
  "$ROOT/var/jb/usr/libexec" \
  "$ROOT/var/jb/Library/LaunchDaemons" \
  "$ROOT/var/jb/var/run" \
  "$ROOT/var/jb/var/log"

cp "$SCRIPT_DIR/control" "$ROOT/DEBIAN/control"
cp "$SCRIPT_DIR/postinst" "$ROOT/DEBIAN/postinst"
cp "$SCRIPT_DIR/prerm" "$ROOT/DEBIAN/prerm"
chmod 0755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/prerm"

cp -R "$APP_BUNDLE" "$ROOT/var/jb/Applications/DarkSwordAI.app"
cp "$ROOTD_BINARY" "$ROOT/var/jb/usr/libexec/darksword-rootd"
cp "$SCRIPT_DIR/../rootd/com.nightvibes.darksword-rootd.plist" \
  "$ROOT/var/jb/Library/LaunchDaemons/com.nightvibes.darksword-rootd.plist"

chmod 0755 "$ROOT/var/jb/usr/libexec/darksword-rootd"
chmod 0644 "$ROOT/var/jb/Library/LaunchDaemons/com.nightvibes.darksword-rootd.plist"

mkdir -p "$(dirname "$OUTPUT_DEB")"
dpkg-deb --root-owner-group --build "$ROOT" "$OUTPUT_DEB"
echo "$OUTPUT_DEB"

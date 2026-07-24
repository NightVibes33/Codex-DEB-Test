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
LAB_SOURCE="$(cd "$SCRIPT_DIR/../.." && pwd)/jailbreak-lab"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

test -d "$LAB_SOURCE"
test -f "$LAB_SOURCE/bin/darksword-poc-run"
test -f "$LAB_SOURCE/bin/darksword-crash-classify"

mkdir -p \
  "$ROOT/DEBIAN" \
  "$ROOT/var/jb/Applications" \
  "$ROOT/var/jb/usr/bin" \
  "$ROOT/var/jb/usr/libexec" \
  "$ROOT/var/jb/usr/share/darksword" \
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
cp -R "$LAB_SOURCE" "$ROOT/var/jb/usr/share/darksword/jailbreak-lab"

chmod 0755 "$ROOT/var/jb/usr/libexec/darksword-rootd"
chmod 0644 "$ROOT/var/jb/Library/LaunchDaemons/com.nightvibes.darksword-rootd.plist"
chmod 0755 \
  "$ROOT/var/jb/usr/share/darksword/jailbreak-lab/bin/darksword-poc-run" \
  "$ROOT/var/jb/usr/share/darksword/jailbreak-lab/bin/darksword-crash-classify"

ln -s ../share/darksword/jailbreak-lab/bin/darksword-poc-run \
  "$ROOT/var/jb/usr/bin/darksword-poc-run"
ln -s ../share/darksword/jailbreak-lab/bin/darksword-crash-classify \
  "$ROOT/var/jb/usr/bin/darksword-crash-classify"

mkdir -p "$(dirname "$OUTPUT_DEB")"
dpkg-deb --root-owner-group --build "$ROOT" "$OUTPUT_DEB"
echo "$OUTPUT_DEB"

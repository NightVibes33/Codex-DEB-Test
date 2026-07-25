#!/bin/sh
set -eu

REPO="NightVibes33/Codex-DEB-Test"
TAG="codex-ios-latest"
ASSET="codex-ios_latest_iphoneos-arm64.deb"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
DEB_URL="${BASE_URL}/${ASSET}"
SUM_URL="${DEB_URL}.sha256"

say() {
  printf '\033[1;36m[Codex iOS]\033[0m %s\n' "$*"
}

fail() {
  printf '\033[1;31m[Codex iOS] ERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  fail "Run this installer through sudo: curl -fsSL https://codex-ios.vercel.app/install.sh | sudo sh"
fi

command -v curl >/dev/null 2>&1 || fail "curl is required. Install it with your package manager first."
command -v dpkg >/dev/null 2>&1 || fail "dpkg is required. Install it with your package manager first."

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in
  iphoneos-arm64|arm64|aarch64) ;;
  *) fail "Unsupported architecture: $ARCH. This package is for arm64 iOS devices." ;;
esac

if [ ! -d /var/jb ]; then
  fail "This installer currently targets a rootless jailbreak with /var/jb."
fi

TMPDIR="$(mktemp -d /tmp/codex-ios.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM
DEB="$TMPDIR/$ASSET"
SUM="$TMPDIR/$ASSET.sha256"

say "Downloading the latest iphoneos-arm64 package..."
curl -fL --retry 4 --retry-delay 2 -o "$DEB" "$DEB_URL" || fail "The release package is not available yet. Check the GitHub Actions build."
curl -fL --retry 4 --retry-delay 2 -o "$SUM" "$SUM_URL" || fail "The package checksum is not available."

EXPECTED="$(tr -d '[:space:]' < "$SUM")"
[ -n "$EXPECTED" ] || fail "The downloaded checksum is empty."

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$DEB" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL="$(shasum -a 256 "$DEB" | awk '{print $1}')"
elif command -v openssl >/dev/null 2>&1; then
  ACTUAL="$(openssl dgst -sha256 "$DEB" | awk '{print $NF}')"
else
  fail "No SHA-256 verifier is installed. Install coreutils or openssl."
fi

[ "$ACTUAL" = "$EXPECTED" ] || fail "SHA-256 verification failed; refusing to install."
say "Checksum verified."

say "Installing Codex CLI..."
if ! dpkg -i "$DEB"; then
  if command -v apt-get >/dev/null 2>&1; then
    say "Resolving package dependencies..."
    apt-get update
    apt-get -f install -y
    dpkg -i "$DEB"
  else
    fail "dpkg reported missing dependencies and apt-get is unavailable."
  fi
fi

mkdir -p /var/mobile/.codex
chown -R mobile:mobile /var/mobile/.codex 2>/dev/null || true
chmod 700 /var/mobile/.codex 2>/dev/null || true

say "Installed successfully."
printf '\nRun these commands as the mobile user:\n\n'
printf '  export CODEX_HOME=/var/mobile/.codex\n'
printf '  codex login --device-auth\n'
printf '  codex\n\n'
printf 'For explicit unrestricted jailbreak access after login:\n\n'
printf '  sudo -E codex --dangerously-bypass-approvals-and-sandbox\n\n'

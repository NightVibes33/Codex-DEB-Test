#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export GIT_TERMINAL_PROMPT=0

WORK_ROOT="/var/mobile/Documents/DarkSword-Workspace"
REPO_DIR="$WORK_ROOT/Dopamine"
HTTPS_REMOTE="https://github.com/NightVibes33/Dopamine.git"
SSH_REMOTE="git@github.com:NightVibes33/Dopamine.git"
mkdir -p "$WORK_ROOT"

echo "=== iPad toolchain ==="
uname -a
id
git --version
python3 --version
printf 'gh_path='; command -v gh 2>/dev/null || echo missing
printf 'ssh_path='; command -v ssh 2>/dev/null || echo missing

echo "=== Existing GitHub authentication ==="
GH_AUTH=0
if command -v gh >/dev/null 2>&1; then
  if gh auth status -h github.com >/tmp/gh-auth.txt 2>&1; then
    GH_AUTH=1
    gh auth setup-git >/dev/null 2>&1 || true
  fi
  sed -E 's/(token:).*/\1 [redacted]/I' /tmp/gh-auth.txt 2>/dev/null || true
fi

echo "gh_authenticated=$GH_AUTH"
echo "credential_helper=$(git config --global --get credential.helper 2>/dev/null || echo none)"

mkdir -p /var/mobile/.ssh
chmod 700 /var/mobile/.ssh
if [ ! -f /var/mobile/.ssh/id_ed25519 ]; then
  ssh-keygen -q -t ed25519 -N '' -C 'NightVibes33-iPad6,11-DarkSword' -f /var/mobile/.ssh/id_ed25519
  chown -R mobile:mobile /var/mobile/.ssh 2>/dev/null || true
fi

SSH_OUTPUT="$(HOME=/var/mobile ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -T git@github.com 2>&1 || true)"
printf '%s\n' "$SSH_OUTPUT"
case "$SSH_OUTPUT" in
  *"successfully authenticated"*) SSH_AUTH=1 ;;
  *) SSH_AUTH=0 ;;
esac
echo "ssh_authenticated=$SSH_AUTH"

echo "=== Fast clone of Dopamine main ==="
if [ -d "$REPO_DIR/.git" ]; then
  cd "$REPO_DIR"
  git remote set-url origin "$HTTPS_REMOTE"
  git fetch --depth 1 origin main
  git checkout -B main FETCH_HEAD
else
  rm -rf "$REPO_DIR"
  git clone --depth 1 --single-branch --branch main "$HTTPS_REMOTE" "$REPO_DIR"
  cd "$REPO_DIR"
fi

echo "repo=$REPO_DIR"
echo "source_head=$(git rev-parse HEAD)"

mkdir -p research
{
  echo "# iPad 5 on-device DarkSword workspace"
  echo
  echo "Generated and committed directly on the iPad6,11 through the Tailscale SSH bridge."
  echo
  echo "- Device: $(uname -m)"
  echo "- Kernel: $(uname -r)"
  echo "- Source branch: main"
  echo "- Source SHA before this manifest: $(git rev-parse HEAD)"
  echo "- Page size: $(pagesize 2>/dev/null || getconf PAGESIZE 2>/dev/null || echo unknown)"
  echo "- File descriptor limit: $(ulimit -n)"
  echo "- Rootless bootstrap: $([ -d /var/jb ] && echo present || echo absent)"
  echo
  echo "No credentials or personal files are recorded here."
} > research/IPAD5_ONDEVICE_WORKSPACE.md

git config user.name "NightVibes33 iPad"
git config user.email "214680657+NightVibes33@users.noreply.github.com"
git add research/IPAD5_ONDEVICE_WORKSPACE.md
if git diff --cached --quiet; then
  echo "commit=already-current"
else
  git commit -m "Record iPad 5 on-device DarkSword workspace"
  echo "local_commit=$(git rev-parse HEAD)"
fi

echo "=== Direct push from iPad ==="
if [ "$SSH_AUTH" -eq 1 ]; then
  git remote set-url origin "$SSH_REMOTE"
else
  git remote set-url origin "$HTTPS_REMOTE"
fi

if git push --dry-run origin HEAD:main >/tmp/ipad-push.log 2>&1; then
  echo "push_dry_run=success"
  git push origin HEAD:main
  echo "push=success"
  echo "pushed_head=$(git rev-parse HEAD)"
else
  echo "push_dry_run=failure"
  sed -E 's/(token|password|secret)[:=][^ ]+/\1=[redacted]/Ig' /tmp/ipad-push.log | tail -30
  echo "push=blocked-by-github-auth"
  echo "=== iPad deploy public key ==="
  cat /var/mobile/.ssh/id_ed25519.pub
fi

echo "=== Done ==="
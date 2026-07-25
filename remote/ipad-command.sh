#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

WORK_ROOT=/var/mobile/Documents/DarkSword-Workspace
REPO_DIR=$WORK_ROOT/Dopamine
SSH_KEY=/var/mobile/.ssh/id_ed25519
SSH_WRAPPER=/var/mobile/.ssh/github-ipad-ssh
BOOT_PRIVATE=$WORK_ROOT/.github-bootstrap/bootstrap-rsa-private.json
SSH_LOG=/tmp/ipad-github-ssh.log

[ -d "$REPO_DIR/.git" ] || { echo push_error=ipad-repo-missing; exit 1; }
[ -s "$SSH_KEY" ] || { echo push_error=ipad-ssh-key-missing; exit 1; }

printf '%s\n' '#!/bin/sh' 'exec /var/jb/usr/bin/ssh -i /var/mobile/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "$@"' > "$SSH_WRAPPER"
chmod 700 "$SSH_WRAPPER"
chown mobile:mobile "$SSH_WRAPPER" 2>/dev/null || true

echo '=== GitHub SSH verification ==='
/var/jb/usr/bin/ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -T git@github.com > "$SSH_LOG" 2>&1 || true
cat "$SSH_LOG"
grep -q 'successfully authenticated' "$SSH_LOG" || { echo ssh_authenticated=0; exit 1; }
echo ssh_authenticated=1

cd "$REPO_DIR"
git remote set-url origin git@github.com:NightVibes33/Dopamine.git
printf 'local_head='; git rev-parse HEAD
printf 'local_subject='; git log -1 --pretty=%s

echo '=== Push from iPad ==='
GIT_SSH="$SSH_WRAPPER" GIT_TERMINAL_PROMPT=0 git push origin HEAD:main
echo push=success
printf 'pushed_head='; git rev-parse HEAD

rm -f "$BOOT_PRIVATE" "$SSH_LOG"
rmdir "$WORK_ROOT/.github-bootstrap" 2>/dev/null || true
echo bootstrap_private_key=erased
echo github_auth=ssh-key

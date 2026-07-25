#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

SSH_KEY=/var/mobile/.ssh/id_ed25519
SSH_WRAPPER=/var/mobile/.ssh/github-ipad-ssh
PATCH_COMMIT=492bf619e7abf1e3bcaa8ad01c624c27fbacc5d9
PATCH_SCRIPT=/tmp/ipad5-adaptive-patch.sh

[ -s "$SSH_KEY" ] || { echo 'bootstrap_error=ipad-ssh-key-missing'; exit 1; }
printf '%s\n' '#!/bin/sh' 'exec /var/jb/usr/bin/ssh -i /var/mobile/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "$@"' > "$SSH_WRAPPER"
chmod 700 "$SSH_WRAPPER"
export GIT_SSH="$SSH_WRAPPER"
export GIT_TERMINAL_PROMPT=0

echo '=== GitHub SSH verification ==='
SSH_RESULT="$(/var/jb/usr/bin/ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
printf '%s\n' "$SSH_RESULT"
echo "$SSH_RESULT" | grep -q 'successfully authenticated' || { echo 'bootstrap_error=github-ssh-auth-failed'; exit 1; }

echo '=== Load preserved patch job ==='
curl -fsSL "https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/${PATCH_COMMIT}/remote/ipad-command.sh" -o "$PATCH_SCRIPT"
chmod 700 "$PATCH_SCRIPT"
sha256sum "$PATCH_SCRIPT" 2>/dev/null || true

# The preserved script inherits GIT_SSH and performs the patch, checks, commit, and push.
/bin/sh "$PATCH_SCRIPT"
rm -f "$PATCH_SCRIPT"
echo 'retry=complete'

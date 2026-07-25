#!/bin/sh
set -eu

# Triggered from ChatGPT on 2026-07-25

echo "=== iPad SSH bridge diagnostic ==="
date || true
id
uname -a
printf 'user='; whoami
printf 'cwd='; pwd
printf 'sshd='; command -v sshd || true
printf 'sudo='; command -v sudo || true
printf 'tailscale-ip='; if command -v tailscale >/dev/null 2>&1; then tailscale ip -4 2>/dev/null || true; else echo "Tailscale CLI not installed in the jailbreak shell"; fi

echo "=== rootless jailbreak paths ==="
ls -ld /var/jb 2>/dev/null || true
ls -l /var/jb/usr/sbin/sshd 2>/dev/null || true

#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

echo '=== Hardware memory ==='
sysctl hw.memsize 2>&1 || true
sysctl hw.pagesize 2>&1 || true

echo '=== Compression and swap sysctls ==='
for key in vm.swapusage vm.compressor_mode vm.compressor_available vm.compressor_is_active vm.page_free_target vm.page_free_min vm.memory_pressure; do
  printf '%s: ' "$key"
  sysctl -n "$key" 2>&1 || true
done

echo '=== VM statistics ==='
vm_stat 2>&1 | sed -n '1,30p' || true

echo '=== Dynamic pager availability ==='
printf 'dynamic_pager_binary='; command -v dynamic_pager 2>/dev/null || echo missing
launchctl print system/com.apple.dynamic_pager 2>&1 | sed -n '1,80p' || true
launchctl list 2>/dev/null | grep -i pager || true

echo '=== VM storage directories ==='
for dir in /private/var/vm /var/vm /private/var/mobile/Library/Caches; do
  echo "path=$dir"
  ls -la "$dir" 2>&1 | sed -n '1,40p' || true
done

echo '=== Filesystem capacity ==='
df -h / /private/var 2>&1 || true
mount 2>&1 | sed -n '1,40p' || true

echo '=== Current pressure evidence ==='
printf 'process_count='; ps -ax 2>/dev/null | wc -l | tr -d ' '
printf 'node_count='; pgrep -x node 2>/dev/null | wc -l | tr -d ' '

echo 'diagnostic=read-only-no-memory-settings-changed'

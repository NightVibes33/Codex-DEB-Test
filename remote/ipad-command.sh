#!/bin/sh
set -eu

export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

echo "=== DarkSword on-device jailbreak research profile ==="
date || true
id
uname -a

echo
echo "=== OS and hardware ==="
for key in kern.ostype kern.osrelease kern.osversion kern.version hw.machine hw.model hw.memsize hw.ncpu hw.pagesize; do
  printf '%s=' "$key"
  sysctl -n "$key" 2>/dev/null || echo unavailable
done
if [ -r /System/Library/CoreServices/SystemVersion.plist ]; then
  plutil -p /System/Library/CoreServices/SystemVersion.plist 2>/dev/null || cat /System/Library/CoreServices/SystemVersion.plist
fi

echo
echo "=== CPU mitigation indicators ==="
sysctl -a 2>/dev/null | grep -Ei 'ptrauth|pointer.auth|arm64e|pac|ppl|kptr|kaslr' | head -80 || true

echo
echo "=== Current jailbreak/bootstrap ==="
ls -ld /var/jb 2>/dev/null || true
for path in /var/jb/basebin /var/jb/procursus /var/jb/.procursus_strapped /var/jb/usr/lib/ellekit /var/jb/usr/lib/TweakInject; do
  ls -ld "$path" 2>/dev/null || true
done
printf 'bootstrap-packages='; dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null | grep -Ei 'dopamine|ellekit|substitute|substrate|procursus|sileo|zebra|libhooker|openssh|sudo|ldid|theos|clang|llvm|frida' || true

echo
echo "=== Available research tools ==="
for tool in clang clang++ cc make cmake ninja ld ldid codesign_allocate python3 perl ruby git curl wget jq plutil otool nm strings objdump jtool jtool2 img4tool ipsw frida frida-server gdb lldb launchctl vm_stat; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$p" ] && printf '%s=%s\n' "$tool" "$p"
done

echo
echo "=== Kernel and dyld assets ==="
for path in \
  /System/Library/Caches/com.apple.kernelcaches/kernelcache \
  /System/Library/dyld/dyld_shared_cache_arm64 \
  /System/Library/dyld/dyld_shared_cache_arm64e \
  /usr/lib/dyld; do
  if [ -e "$path" ]; then
    ls -lh "$path"
    shasum -a 256 "$path" 2>/dev/null | head -1 || true
  fi
done
find /private/preboot -maxdepth 5 -type f \( -name 'kernelcache*' -o -name 'dyld_shared_cache_arm64*' \) -print 2>/dev/null | head -40 || true

echo
echo "=== Code-signing and trust components ==="
for path in /usr/libexec/amfid /usr/libexec/trustd /usr/libexec/containermanagerd /usr/libexec/sandboxd /System/Library/Frameworks/IOSurface.framework/IOSurface; do
  if [ -e "$path" ]; then
    ls -lh "$path"
    codesign -dvvv "$path" 2>&1 | grep -E 'Identifier=|TeamIdentifier=|CodeDirectory|Signature=' | head -12 || true
  fi
done

echo
echo "=== Kernel-facing device nodes ==="
ls -l /dev 2>/dev/null | grep -E '(^| )(kmem|mem|klog|dtrace|ktrace|bpf|pf|audit|random|urandom|zero|null)$' || true
ls -l /dev/bpf* /dev/dtrace* 2>/dev/null | head -40 || true

echo
echo "=== Relevant running processes ==="
ps -axo pid,uid,comm 2>/dev/null | grep -Ei 'jailbreak|dopamine|ellekit|amfid|trustd|launchd|sshd|sileo|troll|frida' | head -80 || true

echo
echo "=== Resource headroom ==="
vm_stat 2>/dev/null | head -20 || true
df -h / /var /var/jb 2>/dev/null || true
ulimit -a 2>/dev/null || true

echo
echo "=== Profile complete ==="

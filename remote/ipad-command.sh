#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

echo "=== Exact target ==="
for key in kern.osrelease kern.osversion hw.machine hw.model hw.memsize hw.ncpu hw.pagesize; do
  printf '%s=' "$key"; sysctl -n "$key" 2>/dev/null || echo unavailable
done
plutil -p /System/Library/CoreServices/SystemVersion.plist 2>/dev/null || true

echo "=== Bootstrap identity ==="
ls -ld /var/jb /var/jb/basebin /var/jb/procursus /var/jb/.procursus_strapped 2>/dev/null || true
ls -la /var/jb/basebin 2>/dev/null | head -40 || true
dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null | grep -Ei 'palera1n|dopamine|jailbreak|ellekit|libhooker|substitute|substrate|frida|theos|clang|llvm|ldid' | head -60 || true

echo "=== Versioned toolchain ==="
for p in /var/jb/usr/bin/clang* /var/jb/usr/bin/ld* /var/jb/usr/bin/llvm-* /var/jb/usr/bin/make /var/jb/usr/bin/cmake /var/jb/usr/bin/ninja /var/jb/usr/bin/ldid; do
  [ -e "$p" ] && ls -lh "$p"
done
for p in /var/jb/usr/bin/clang-16 /var/jb/usr/bin/ld.lld-16 /var/jb/usr/bin/llvm-config-16; do
  if [ -x "$p" ]; then "$p" --version 2>/dev/null | head -3 || true; fi
done

echo "=== SDK/header availability ==="
for p in /var/jb/usr/include /var/jb/usr/local/include /var/jb/Library/Developer/CommandLineTools/SDKs /var/jb/var/theos /var/jb/opt/theos /var/theos; do
  [ -e "$p" ] && ls -ld "$p"
done
find /var/jb -maxdepth 5 -type d \( -name 'iPhoneOS*.sdk' -o -name 'MacOSX*.sdk' \) -print 2>/dev/null | head -20 || true

echo "=== Kernel/dyld search ==="
find /private/preboot /System/Library -type f \( -iname '*kernelcache*' -o -name 'dyld_shared_cache_arm64*' \) -print 2>/dev/null | head -60 || true
find /System/Library /usr/lib -maxdepth 4 -type f -name 'dyld_shared_cache*' -print 2>/dev/null | head -30 || true

echo "=== Low-memory baseline ==="
printf 'nofiles='; ulimit -n
vm_stat 2>/dev/null | grep -E 'Pages free|Pages active|Pages inactive|Pages wired|Pages occupied by compressor' || true

echo "=== Minimal native compile test ==="
TMP=/var/jb/var/tmp/darksword-native-test
mkdir -p "$TMP"
cat > "$TMP/main.c" <<'EOF'
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
int main(void) {
  printf("native-ok uid=%d euid=%d pointer_bits=%zu\\n", getuid(), geteuid(), sizeof(void*) * 8);
  return 0;
}
EOF
if [ -x /var/jb/usr/bin/clang-16 ]; then
  set +e
  /var/jb/usr/bin/clang-16 "$TMP/main.c" -o "$TMP/native-test" >"$TMP/build.log" 2>&1
  rc=$?
  set -e
  echo "compile_exit=$rc"
  tail -20 "$TMP/build.log" || true
  if [ "$rc" -eq 0 ]; then
    ldid -S "$TMP/native-test" 2>/dev/null || true
    ls -lh "$TMP/native-test"
    "$TMP/native-test" || true
  fi
else
  echo "clang-16 executable missing"
fi

echo "=== Done ==="

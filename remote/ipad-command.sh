#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

URL='https://nfzerox.github.io/cydia/debs/VirtualMac_1.2.deb'
ORIG='/var/mobile/Media/VirtualMac_1.2.deb'
WORK='/var/mobile/Media/VirtualMac12-ipad5-work'
PATCHED='/var/mobile/Media/VirtualMac_1.2-ipad5-test.deb'

echo '=== VIRTUALMAC 1.2 IPAD5 LIVE TEST ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
printf 'sw_vers='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || sysctl -n kern.osversion 2>/dev/null || true
printf 'hw_machine='; sysctl -n hw.machine 2>/dev/null || uname -m
printf 'hw_model='; sysctl -n hw.model 2>/dev/null || true
printf 'uname='; uname -a

echo '--- virtualization capability probes ---'
for key in kern.hv_support hw.optional.arm.FEAT_VHE hw.optional.armv8_2_sha3 hw.optional.arm64; do
  printf '%s=' "$key"
  sysctl -n "$key" 2>&1 || true
done
sysctl -a 2>/dev/null | grep -Ei 'hypervisor|hv_support|virtualization|VHE' | sed -n '1,120p' || true

echo '--- download official 1.2 ---'
rm -f "$ORIG" "$PATCHED"
if command -v curl >/dev/null 2>&1; then
  curl -L --fail --retry 3 --connect-timeout 20 -o "$ORIG" "$URL"
  DOWNLOAD_RC=$?
elif command -v wget >/dev/null 2>&1; then
  wget -O "$ORIG" "$URL"
  DOWNLOAD_RC=$?
else
  echo 'no curl/wget available'
  DOWNLOAD_RC=127
fi
echo "download_rc=$DOWNLOAD_RC"
[ "$DOWNLOAD_RC" -eq 0 ] || exit "$DOWNLOAD_RC"
ls -lh "$ORIG" 2>&1
sha256sum "$ORIG" 2>/dev/null || shasum -a 256 "$ORIG" 2>/dev/null || true

echo '--- official package metadata ---'
dpkg-deb -f "$ORIG" Package Version Architecture Depends 2>&1
META_RC=$?
echo "metadata_rc=$META_RC"
[ "$META_RC" -eq 0 ] || exit "$META_RC"

echo '--- unpack + patch only firmware upper-bound dependency ---'
rm -rf "$WORK"
mkdir -p "$WORK/root"
dpkg-deb -R "$ORIG" "$WORK/root"
UNPACK_RC=$?
echo "unpack_rc=$UNPACK_RC"
[ "$UNPACK_RC" -eq 0 ] || exit "$UNPACK_RC"
CONTROL="$WORK/root/DEBIAN/control"
echo 'control_before:'
sed -n '1,80p' "$CONTROL"
cp "$CONTROL" "$WORK/control.original"
# Keep all real runtime dependencies; remove only the package-manager iOS <16.4 guard so we can test the actual device/runtime failure.
sed -i 's/, *firmware *(<< *16\.4)//g; s/firmware *(<< *16\.4), *//g' "$CONTROL"
echo 'control_after:'
sed -n '1,80p' "$CONTROL"
dpkg-deb -b "$WORK/root" "$PATCHED"
REPACK_RC=$?
echo "repack_rc=$REPACK_RC"
[ "$REPACK_RC" -eq 0 ] || exit "$REPACK_RC"
ls -lh "$PATCHED"
dpkg-deb -f "$PATCHED" Package Version Architecture Depends 2>&1

echo '--- install patched package ---'
dpkg -i "$PATCHED" 2>&1
INSTALL_RC=$?
echo "install_rc=$INSTALL_RC"
dpkg-query -W -f='package=${Package}\nversion=${Version}\nstatus=${Status}\narch=${Architecture}\n' com.mac.virtual 2>&1 || true

echo '--- locate payload ---'
APP=''
for p in /var/jb/Applications/VirtualMac.app /Applications/VirtualMac.app; do
  if [ -d "$p" ]; then APP="$p"; break; fi
done
echo "app_path=${APP:-absent}"
if [ -n "$APP" ]; then
  ls -la "$APP" | sed -n '1,120p'
  if [ -x "$APP/VirtualMac" ]; then
    file "$APP/VirtualMac" 2>&1 || true
    command -v otool >/dev/null 2>&1 && otool -L "$APP/VirtualMac" 2>&1 | sed -n '1,120p' || true
  fi
  if [ -f "$APP/Info.plist" ]; then
    plutil -p "$APP/Info.plist" 2>&1 | sed -n '1,180p' || true
    BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$APP/Info.plist" 2>/dev/null)"
  else
    BUNDLE_ID=''
  fi
else
  BUNDLE_ID=''
fi
echo "bundle_id=${BUNDLE_ID:-unknown}"

echo '--- runtime payload sanity ---'
for p in \
  /var/root/VirtualMac/payload/Frameworks/Hypervisor.framework/Versions/A/Hypervisor \
  /var/root/VirtualMac/payload/Frameworks/Virtualization.framework/Versions/A/Virtualization \
  /var/root/VirtualMac/payload/VirtualMachine.xpc/Contents/MacOS/com.apple.Virtualization.VirtualMachine \
  /var/root/VirtualMac/install/install-launcher \
  /var/jb/usr/bin/virtualmac-diagnostics; do
  if [ -e "$p" ]; then
    echo "PRESENT=$p"
    ls -lh "$p" 2>/dev/null
    file "$p" 2>/dev/null || true
  else
    echo "MISSING=$p"
  fi
done

echo '--- register and launch app ---'
if [ -n "$APP" ]; then
  /var/jb/usr/bin/uicache -p "$APP" 2>&1 || /var/jb/usr/bin/uicache -a 2>&1 || true
fi
killall -9 VirtualMac 2>/dev/null || true
LAUNCH_RC=1
if [ -n "$BUNDLE_ID" ]; then
  sudo -u mobile uiopen "$BUNDLE_ID" 2>&1
  LAUNCH_RC=$?
fi
if [ "$LAUNCH_RC" -ne 0 ]; then
  sudo -u mobile uiopen 'virtualmac://' 2>&1
  LAUNCH_RC=$?
fi
echo "uiopen_rc=$LAUNCH_RC"
sleep 8
ps ax 2>/dev/null | grep '[V]irtualMac' | sed -n '1,80p' || true
APP_PID="$(ps ax 2>/dev/null | awk '/[V]irtualMac.app\/VirtualMac/{print $1; exit}')"
echo "virtualmac_app_pid=${APP_PID:-absent}"

echo '--- diagnostics ---'
if [ -x /var/jb/usr/bin/virtualmac-diagnostics ]; then
  /var/jb/usr/bin/virtualmac-diagnostics 2>&1 | sed -n '1,260p'
elif [ -x /usr/bin/virtualmac-diagnostics ]; then
  /usr/bin/virtualmac-diagnostics 2>&1 | sed -n '1,260p'
fi

echo '--- recent crash evidence ---'
find /var/mobile/Library/Logs/CrashReporter -type f \( -iname '*VirtualMac*' -o -iname '*Virtualization*' \) -mmin -15 -print 2>/dev/null | tail -n 20
for f in $(find /var/mobile/Library/Logs/CrashReporter -type f -iname '*VirtualMac*' -mmin -15 -print 2>/dev/null | tail -n 3); do
  echo "CRASH_FILE=$f"
  sed -n '1,220p' "$f" 2>/dev/null || true
done

echo '--- final ---'
if [ -n "$APP_PID" ]; then
  echo 'APP_LAUNCH=PASS'
else
  echo 'APP_LAUNCH=FAIL'
fi
if sysctl -n kern.hv_support >/tmp/vmhv 2>/dev/null && [ "$(cat /tmp/vmhv)" = '1' ]; then
  echo 'KERNEL_HYPERVISOR=AVAILABLE'
else
  echo 'KERNEL_HYPERVISOR=UNAVAILABLE_OR_UNEXPOSED'
fi
echo "PATCHED_DEB=$PATCHED"
echo 'VIRTUALMAC12_IPAD5_TEST_COMPLETE=true'
exit 0

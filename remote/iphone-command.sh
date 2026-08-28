#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl

echo '=== IOS NATIVE BROADCOM RFMON TEST ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== STAGED RFMONCTL =====\n'
ls -l "$RFMON" 2>&1 || true
if [ ! -x "$RFMON" ]; then
  echo 'rfmonctl_result=missing-or-not-executable'
  exit 0
fi

printf '\n===== BPF DEVICES BEFORE =====\n'
ls -la /dev/bpf* 2>&1 | head -n 120 || true

printf '\n===== SAFE GET MONITOR STATE =====\n'
"$RFMON" en0 get 2>&1
GET_RC=$?
echo "rfmon_get_rc=$GET_RC"

printf '\n===== INTERFACE BEFORE =====\n'
ipconfig getsummary en0 2>&1 | head -n 100 || true

printf '\n===== GUARDED 2 SECOND MONITOR PULSE =====\n'
if [ "$GET_RC" -eq 0 ]; then
  # Detached fallback restores station mode and restarts Wi-Fi even if enabling
  # monitor mode temporarily drops the SSH/Tailscale path.
  nohup sh -c 'sleep 7; /var/jb/usr/local/bin/rfmonctl en0 off >/tmp/rfmon-recovery.txt 2>&1 || true; killall wifid >/dev/null 2>&1 || true' >/tmp/rfmon-guard.txt 2>&1 </dev/null &
  "$RFMON" en0 pulse 2 2>&1
  PULSE_RC=$?
  echo "rfmon_pulse_rc=$PULSE_RC"
  sleep 2
else
  echo 'rfmon_pulse_skipped=get-monitor-ioctl-failed'
fi

printf '\n===== MONITOR STATE AFTER =====\n'
"$RFMON" en0 get 2>&1
AFTER_RC=$?
echo "rfmon_after_get_rc=$AFTER_RC"

printf '\n===== INTERFACE AFTER =====\'
ipconfig getsummary en0 2>&1 | head -n 100 || true

printf '\n===== IOKIT MONITOR COUNTS AFTER =====\n'
ioreg -l -w0 2>/dev/null | grep -Ei 'IO80211InterfaceMonitor|IO80211ControllerMonitor|AppleBCMWLANUserClient|IO80211APIUserClient' | head -n 120 || true

echo '=== END IOS NATIVE BROADCOM RFMON TEST ==='

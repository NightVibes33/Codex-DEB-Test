# Safe Mode Repair 1.1.0 — Dopamine iPhone 6s

A real Home Screen app, installed automatically by `com.nightvibes.safemoderepair` DEB, using a local privileged, mobile-only UNIX socket.

## What changed

- Rebuilt dark native UIKit interface with an evidence overview, search, disabled-tweak recovery, and a diagnostics tab.
- Distinguishes crash-stack evidence from an inconclusive crash. **A zero score is not a finding of innocence or guilt.**
- Adds controlled single-tweak isolation directly in the app: select a tweak → **Test by temporarily disabling** → **Respring** → record whether Safe Mode disappeared. The result is saved and surfaced at the top of the tweak list.
- If Safe Mode persists, the tested tweak is restored; respring again to apply.
- If Safe Mode clears, the tweak remains disabled until you explicitly restore or uninstall it.
- Any time during the test, **Cancel test and restore** reverses the change; respring to apply.
- The separate **Uninstall** action checks APT dependency simulation or uses `dpkg --no-act` if APT package indexes are malformed. No automatic package removals.
- Includes a native, read-only end-to-end service smoke test in deployment.

## Evidence and limits

The October 19, 2026 iPhone 6s SpringBoard report contained no injected tweak libraries in its image list; it indicated repeated VM memory-shortage faults. **No software can attribute that report to a particular tweak by crash-frame matching alone.** Controlled isolation can provide new evidence. Multiple interacting tweaks can require more than one test.

The app does not auto-disable anything on first run. It does not clear preferences, automatically respring, or remove packages. Its isolation test requires explicit confirmation before each disruptive operation.

## Installation

Install `safe-mode-repair_1.1.0_iphoneos-arm64.deb` using Sileo, Zebra, Filza, or `dpkg -i`. The post-install script registers `/var/jb/Applications/SafeModeRepair.app` using `uicache` and launches `com.nightvibes.smr.rootd`.

Bundle ID: `com.nightvibes.safemoderepair`.

Logs and active tests: `/var/mobile/Library/SafeModeRepair/`.

Emergency CLI remains:

```sh
sudo /var/jb/usr/local/bin/safemode-repair menu
```

Build / SSH deployment: `.github/workflows/build-safe-mode-repair-app.yml`.

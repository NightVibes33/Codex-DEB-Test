# Safe Mode Repair — iPhone 6s app

**Built for** iPhone 6s (`iPhone8,1`), iOS 15+, Dopamine rootless and ElleKit.

## Install the DEB

Install `safe-mode-repair_1.0.0_iphoneos-arm64.deb` using Filza, Sileo, Zebra, or `dpkg -i` via SSH.

The DEB **automatically installs a real native UIKit application** at:

`/var/jb/Applications/SafeModeRepair.app`

Package scripts run `uicache` to register the **Safe Mode Repair** Home Screen icon and load its root-owned launchd daemon (`com.nightvibes.smr.rootd`).

App bundle ID: `com.nightvibes.safemoderepair`.

## In-app tools

Open **Safe Mode Repair** from the Home Screen. The main screen scans SpringBoard/backboardd crash reports and lists installed tweak libraries with their originating Debian package. Tap any tweak for:

- **Disable tweak**: reversibly rename its dylib and filter without deleting preferences. No automatic respring.
- **Uninstall package**: confirm removal, then the service checks APT's removal simulation; if your repository index is malformed, performs a dependency-respecting `dpkg --no-act --remove` before removal.
- **Restore**: tap **Disabled** at the top to list disabled tweaks and re-enable one.

The app has a **Refresh** button. The scanner bases suspicion on crashing-thread frames, **not merely on a loaded library list**. If the native scanner is terminated by device memory pressure, the interface falls back to an installed-tweak list and clearly labels attribution as unavailable. No tweak is automatically modified.

## Components

- `remote/smr-app/main.m`: native UIKit iPhone UI and socket client.
- `remote/smr-app/rootd.c`: local root daemon with a strict command allowlist; the socket is owned by the mobile user with 0600 permissions.
- `remote/safemode-repair`: reversible file management and dependency-checked uninstall.
- `remote/smr-scan.c`: native crash stack scanner.
- `remote/smr-app/postinst`: registers the Home Screen app and starts the daemon.
- `.github/workflows/build-safe-mode-repair-app.yml`: builds the signed app, packages the DEB, and SSH-installs it on the iPhone 6s when merged to `main`.

The previous terminal command remains available for recovery:

```sh
sudo /var/jb/usr/local/bin/safemode-repair menu
```

Logs and results are under `/var/mobile/Library/SafeModeRepair/`. Installing the package does not reboot or respring the device.

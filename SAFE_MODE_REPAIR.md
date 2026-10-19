# iPhone 6s Safe Mode Repair

For **iPhone8,1**, iOS 15.8.8, Dopamine rootless and ElleKit.

The GitHub Actions workflow **iPhone 6s Safe Mode Repair Installer** builds an iOS arm64 scanner, connects to the existing iPhone over Tailscale/SSH using the configured GitHub secrets, installs both files to `/var/jb/usr/local/bin/` and immediately collects a **read-only** crash report.

## On-device menu

Run over SSH or from a privileged jailbreak terminal:

```sh
sudo /var/jb/usr/local/bin/safemode-repair menu
```

- **Scan:** Uses real crashing/faulting thread and exception frames from the newest SpringBoard/backboardd .ips/.crash reports. Merely being listed in `usedImages` does *not* make a tweak suspicious. Results are ranked by evidence score, with Debian package ownership when possible. These are suspect rankings, not proof of a single cause.
- **Disable:** Renames only the chosen tweak's .dylib and matching .plist by appending `.safemode-repair-disabled`. Reversible; does not wipe preferences.
- **Uninstall:** Resolves package ownership, previews APT removal, rejects dependent-package removals and prompts for an explicit `REMOVE package.id` confirmation.
- **Re-enable:** Restores a tweak disabled by this tool.
- **List disabled:** Shows the reversible disabled-file set.

The tool does not automatically respring or change any tweak during initial deployment. Run a respring separately when ready. Evidence: `/var/mobile/Library/SafeModeRepair/latest.tsv`; history: `actions.log`. If Tailscale/SSH is unreachable, the installer reports failure without claiming the iPhone was modified.

CLI: `safemode-repair scan|disable NAME|enable NAME|uninstall NAME|list-disabled`.

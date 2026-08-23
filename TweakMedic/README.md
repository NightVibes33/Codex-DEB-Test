# TweakMedic

TweakMedic is a rootless jailbreak diagnostic app that automatically isolates tweak-injection failures.

## Surfaces

- **Home Screen app** — Home, Scan, History, and Settings tabs.
- **iOS Settings pane** — scan defaults and a launcher into the full app.
- **`tweakmedicctl`** — terminal/SSH interface to the same daemon.

## Engine

For a selected app TweakMedic:

1. inventories installed apps and active `TweakInject` filters;
2. determines filters eligible for the target, including UIKit-wide filters;
3. reproduces the failure with normal injection;
4. verifies the app survives with matching filters disabled;
5. binary-searches the candidate set;
6. performs culprit-only and culprit-disabled A/B verification;
7. optionally probes pair interactions when a single dylib is not sufficient;
8. writes a JSON report to `/var/mobile/Library/TweakMedic/Reports`;
9. restores every temporarily moved filter even after exceptions or daemon restarts;
10. reopens TweakMedic with the completed result.

## Recovery model

Temporary filter moves live only under `/var/mobile/Library/TweakMedic/Staging`. `tweakmedicd` restores this directory at daemon startup and around every test. User-requested global disables are stored separately in `/var/mobile/Library/TweakMedic/Disabled` and are never mistaken for interrupted staging.

## CLI

```sh
tweakmedicctl ping
tweakmedicctl snapshot
tweakmedicctl status
tweakmedicctl reports
tweakmedicctl scan xyz.willy.Zebra 22
tweakmedicctl disable Snowboard
tweakmedicctl enable Snowboard
tweakmedicctl restore
```

Package uninstall is intentionally explicit:

```sh
tweakmedicctl uninstall <dpkg-package-id>
```

## Target

- rootless Dopamine-style bootstrap
- arm64
- iOS/iPadOS 15+
- tested through the repository's Tailscale iPad device-proof workflow

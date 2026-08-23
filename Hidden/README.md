# Hidden

**See what Apple shipped but did not expose.**

Hidden is a rootless jailbreak system-discovery app for Apple system applications, private frameworks, preference bundles, and internal configuration resources.

## v0.1

- Scans Apple system apps and CoreServices applications.
- Scans Apple PrivateFrameworks.
- Scans system PreferenceBundles and internal preference manifests.
- Extracts suspicious feature-flag, prototype, diagnostics, hidden-controller, capability, Siri, Camera, SpringBoard, Control Center, multitasking, and CarPlay evidence.
- Reads structured plist resources and printable executable strings.
- Deduplicates and confidence-ranks findings.
- Search UI with exact source path and evidence copy actions.
- Read-only: v0.1 does not patch system files or permanently override capabilities.

## Planned

1. Gate Tracer — correlate a hidden controller/feature with capability and preference checks.
2. Apple Feature Graph — map flags, frameworks, controllers, and system services.
3. Temporary Test Override — reversible process-lifetime experiments without modifying system files.
4. Confirmed-feature profiles — save only verified local overrides.
5. Generate Tweak — export a minimal ElleKit tweak for a verified override.

## Build

```sh
export THEOS=/opt/theos
make clean package FINALPACKAGE=1
```

Package ID: `com.nightvibes.hidden`

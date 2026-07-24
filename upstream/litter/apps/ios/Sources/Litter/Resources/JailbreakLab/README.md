# DarkSword Jailbreak Lab

This directory is packaged into `/var/jb/usr/share/darksword/jailbreak-lab` by the rootless `.deb` build.

## Components

- `harnesses/`: minimal test-harness templates for user-owned devices.
- `bin/darksword-poc-run`: resource-limited runner that records command, hashes, timing, output, and exit state.
- `bin/darksword-crash-classify`: local classifier for `.ips`, `.panic`, and `.crash` reports.
- `schema/experiment.schema.json`: stable experiment-record format.

## Safety boundary

The lab supports authorized on-device vulnerability research, crash reproduction, fuzz-harness testing, and diagnostic collection. It does not include a ready-made kernel exploit, credential extraction, destructive storage commands, persistence installation, or unattended kernel-memory writes.

Every experiment gets its own directory under:

```text
/var/mobile/Library/DarkSwordLab/experiments/<timestamp>-<id>/
```

The record contains the exact command, executable SHA-256, timeout, stdout/stderr, exit code, and timestamps so results are reproducible and reviewable.

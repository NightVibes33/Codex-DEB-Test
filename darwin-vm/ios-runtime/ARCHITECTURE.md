# VibePhone — iOS/iPadOS custom runtime architecture

This branch is intentionally **iOS/iPadOS-only**. The Windows lane is not part of this target.

## Product goal

Build a dedicated virtual iPhone runtime hosted by the VibeContainers shell. The guest uses a user-supplied Apple IPSW plus a vphone-style patched boot/CFW pipeline. The host execution engine is our own native runtime and does **not** embed QEMU, expose a generic VM creator, require a companion PC, or call macOS `Virtualization.framework`.

The project is specialized around one job: booting and operating an Apple mobile guest inside the VibePhone app.

## Source roles

### VibeContainers — host application

Pinned from `NightVibes33/VibeContainers`.

Reuse:
- SwiftUI iPhone/iPad shell
- SpringBoard-like host UI and multitasking chrome
- file import/download/storage helpers
- touch/controller routing
- ZIP/IPSW handling primitives
- unsigned real-device IPA packaging

Replace for the virtual-phone path:
- LiveContainer executable patching
- in-process guest Mach-O launch
- LiveProcess guest hosting
- relaunch tickets/JIT handoff as the primary execution model

LiveContainer can remain available for the original container feature, but it is not the virtual phone CPU/runtime.

### vphone-cli — boot and CFW donor

Pinned from `Lakr233/vphone-cli` (MIT).

Use as the authoritative reference/donor for:
- Apple firmware artifact selection and layout
- iBoot/boot-chain patch families
- kernel/trust-cache patch families
- ramdisk/root filesystem preparation
- base CFW install phases
- JB CFW phases (`scripts/cfw_install_jb.sh`)
- Procursus/bootstrap/BaseBin deployment concepts
- launchd/LaunchServices modifications required by the virtual guest

Do **not** port its macOS host dependency directly:
- `VZVirtualMachine`
- `Virtualization.framework`
- host APFS attach/mount operations that require macOS

Those responsibilities are replaced by VibePhone runtime/storage APIs suitable for a real iPhone/iPad host.

### Nyxian — userspace compatibility donor

Nyxian remains a reference for Darwin userspace/syscall behavior and compatibility tests. It is not the Apple guest kernel and does not replace XNU.

## Guest payload

VibePhone never ships Apple firmware bytes. A user imports an IPSW.

For each virtual phone, the firmware store resolves and persists:
- iBoot/boot loader artifact(s)
- kernelcache
- device tree
- trust cache
- ramdisk
- root/system filesystem images
- build identity and hardware profile metadata

The native runtime ABI v3 exposes `vp_runtime_stage_boot_images`, which validates and stages the Apple boot-image set into sparse guest physical memory and selects the reset/entry vector.

## Custom execution runtime

`Native/VPhoneRuntimeCore.*`
- sparse guest-physical memory
- lifecycle/state machine
- serial callback
- boot-image staging
- execution scheduling/budgeting

`Native/VPhoneAArch64.*`
- VibePhone-owned AArch64 execution engine
- no QEMU/TCG dependency
- interpreter is the mandatory standalone path
- optional acceleration may be added later only when it does not make a PC mandatory

The current interpreter is an early execution core, **not yet a complete XNU-capable CPU**. Full Apple guest boot requires continued implementation of EL1/EL2 architectural state, exceptions, MMU/page tables, system registers, timers/interrupts, atomics, SIMD/FP and the instruction families exercised by iBoot/XNU.

`Native/VPhoneKernelSurface.*`
- host-side runtime services and Darwin compatibility surface
- must not pretend to be the guest XNU kernel
- once XNU boots, guest syscalls stay inside the guest; this surface becomes boot/runtime/device support rather than a replacement kernel

## Virtual hardware

The custom machine layer will expose only hardware required by the Apple mobile guest:

1. interrupt controller/timers
2. serial console
3. storage/block device backed by the per-phone image set
4. virtual display/framebuffer
5. multitouch/keyboard/controller input
6. user-space virtual NIC/NAT
7. clocks/NVRAM/platform configuration needed by the selected Apple build

Wi-Fi UI/radio semantics and Bluetooth come after basic networking/display/input are stable.

## Guest jailbreak / CFW

The jailbreak exists **inside the virtual phone**. Host iOS is not jailbroken by this pipeline.

Port order from `vphone-cli`:
1. base CFW phases
2. boot-chain patch manifest
3. kernel/trust-cache patch manifest
4. launchd modifications
5. iosbinpack/BaseBin resources
6. Procursus bootstrap
7. first-boot JB setup and app registration

The original vphone scripts manipulate APFS volumes while the VM is off on macOS. VibePhone must translate those operations into its own image/filesystem mutation layer instead of invoking macOS `diskutil`, `mount_apfs`, or `Virtualization.framework`.

## Independence

The unsigned IPA is a complete standalone host artifact after the user signs it for installation. At runtime it must not require:
- a Windows executable
- a Mac
- a remote VM
- a remote JIT server
- QEMU

## Engineering milestones

### M0 — host/runtime build
- VibeContainers-derived host builds for generic arm64 iPhone/iPad.
- custom native runtime links into the app.
- unsigned IPA artifact is produced.
- CI verifies the Payload contains no QEMU binary/library.

### M1 — firmware pipeline
- import/index one supported IPSW
- resolve boot artifacts
- port vphone patch manifest into deterministic on-device patch operations
- stage iBoot/kernelcache/device-tree/trust-cache/ramdisk through runtime ABI v3

### M2 — real boot-chain execution
- expand the AArch64 engine until patched iBoot executes
- implement required exception levels/system registers/MMU
- first serial output from Apple boot code

### M3 — XNU
- reach XNU early boot
- implement interrupt/timer/storage devices required to continue
- boot to launchd

### M4 — graphical iOS
- display/framebuffer bridge to Metal
- touch/input bridge
- SpringBoard render and interaction

### M5 — networking + JB
- user-space virtual NIC/NAT
- complete CFW/JB filesystem phases
- Procursus/BaseBin/launchd bootstrap starts inside guest

### M6 — polish
- persistent virtual phones
- snapshots/recovery
- multiple hardware/firmware profiles
- Wi-Fi/Bluetooth semantics where feasible

## Current truth

CI can compile the custom runtime and VibeContainers host, but **a full Apple guest is not booting yet**. The next correctness gate is patched Apple boot code producing serial output through the custom CPU/device runtime. No milestone is considered complete from source presence alone.

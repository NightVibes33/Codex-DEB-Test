# VPhone iOS Runtime

This directory is the iPhone/iPad-only replacement path for the earlier generic VM experiments.

## Goal

Build a dedicated real-device iOS/iPadOS app that uses the current VibeContainers shell and packaging, but boots guests through our own runtime instead of QEMU or a generic VM UI.

The design has three layers:

1. **VibeContainers host** — SpringBoard-style UI, iPhone/iPad layout, imports, storage, signing, multitasking shell, real-device IPA packaging.
2. **VibeKernel / VPhoneRuntime** — our own AArch64 execution core, guest physical memory, CPU state, scheduler, traps, and eventually MMU/EL1/interrupt/device emulation.
3. **vphone firmware/CFW research** — reuse the firmware preparation, boot-chain patching concepts, jailbreak/bootstrap payload layout, and restore metadata from vphone-cli. Do not embed Apple's macOS-only Virtualization.framework host.

## Why vphone-aio is not the host runtime

`34306/vphone-aio` is a packaged distribution around `Lakr233/vphone-cli`. The current vphone-cli host boots through Apple's private Virtualization.framework/PV=3 path and requires Apple Silicon macOS plus host security relaxation. That host path is unavailable inside a normal iPhone/iPad application.

We therefore reuse the portable firmware/CFW knowledge and build our own on-device runtime.

## Kernel strategy

A clean-room XNU replacement would not be ABI-compatible enough to boot stock iOS userspace. The practical target is:

- keep the Apple kernelcache/boot artifacts as the eventual guest payload;
- build our own **execution kernel/runtime** underneath it;
- emulate the AArch64 privileged environment, guest physical memory, MMU/system registers, interrupts, timers, and the Apple/PV devices required for SpringBoard;
- use a patched/jailbroken guest image prepared from the vphone research pipeline.

The first committed runtime is intentionally small but real: it owns CPU state and guest memory and interprets a seed set of AArch64 instructions without QEMU. CI runs the interpreter smoke test natively and cross-compiles it for iPhoneOS arm64 before injecting it into the current VibeContainers project and packaging an unsigned real-device IPA.

## Milestones

### M0 — custom runtime seed
- AArch64 register file and PC/SP state
- guest physical-memory arena
- instruction fetch/decode/execute loop
- MOVZ/MOVK, ADD/SUB immediate, B/BL/BR/RET, basic LDR/STR, NOP, WFI, SVC
- host smoke test
- iPhoneOS arm64 compilation
- VibeContainers unsigned IPA integration

### M1 — privileged CPU core
- CurrentEL/PSTATE handling
- MRS/MSR system-register bank
- exception vectors and SVC/IRQ/FIQ entry
- timer/counter registers
- EL1 MMU translation: TTBR/TCR/SCTLR/MAIR
- page-table walking and permission faults

### M2 — Apple boot environment
- boot-args/device-tree handoff
- kernelcache and trust-cache loading
- ramdisk/root filesystem attachment
- interrupt controller + UART
- enough platform registers for early XNU boot

### M3 — graphical iOS
- AppleParavirtGPU/display transport
- IOSurface mapper
- touch/keyboard input device
- networking transport
- launchd -> backboardd -> SpringBoard

### M4 — jailbroken guest
- adapt the vphone `jb` CFW payload/boot-chain changes to our guest bundle format
- rootless/rootful bootstrap storage as appropriate
- Sileo/TrollStore payload staging where compatible
- snapshot/revert support in the VibeContainers host

## Upstream pins

See `vendor.lock.json`. The build lane pins both VibeContainers and vphone-cli so changes upstream cannot silently alter the runtime build.

## Non-goals

- no QEMU frontend
- no generic PC/VM creator UI
- no dependency on a Windows or Mac machine at runtime
- no claim that M0 already boots iOS; SpringBoard requires the later privileged CPU/MMU/device milestones

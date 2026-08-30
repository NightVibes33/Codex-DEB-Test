# iOS-only runtime architecture

This branch is intentionally iOS/iPadOS-only. The Windows host lane is not part of this target.

## Goal

Build a dedicated Darwin/iOS virtual phone runtime hosted by the VibeContainers shell, using the `34306/vphone-aio` architecture as the primary reference/runtime source where compatible. This is not a generic VM frontend and must not expose a generic QEMU-style machine creator.

## Runtime layers

1. **Host shell — VibeContainers**
   - SwiftUI/iPhone/iPad host UI
   - firmware/image import and storage
   - device profiles and guest lifecycle UI
   - touch/controller routing
   - unsigned real-device IPA packaging

2. **Guest execution core — vphone-derived runtime**
   - Apple/XNU guest boot path
   - guest memory and CPU execution layer
   - device model and interrupt routing
   - virtual display/input/network devices
   - jailbreak/bootstrap integration supplied by the vphone runtime where license/source permits

3. **Apple guest payload**
   - Apple-provided kernelcache / trust cache / ramdisk / filesystem extracted from a user-supplied IPSW
   - no custom replacement iOS kernel is shipped
   - runtime-specific kernel patches are generated/applied at boot when required by the chosen vphone path

4. **Display and input**
   - dedicated framebuffer/virtual display bridge into a Metal-backed iOS view
   - UIKit touch, keyboard and controller events translated to guest input events

5. **Networking**
   - user-space virtual NIC/NAT first
   - Wi-Fi UI/radio emulation only after basic guest networking is stable

6. **Jailbreak/bootstrap**
   - bootstrap lives inside the guest, not in the host app process
   - package manager/rootfs state is guest-owned and persistent per virtual device

## Independence

The IPA is fully independent. It does not require a Windows executable, Windows service, remote JIT server, or companion PC to boot its guest. Any optional JIT acceleration must have a functional interpreter/TCG-style fallback so the host app remains standalone.

## Migration from VibeContainers

Reuse:
- `iOSSim/Core/*`
- `iOSSim/Springboard/*` for the host shell only
- `iOSSim/Controller/*`
- import/download/storage helpers
- `ZipArchive`
- build and unsigned IPA workflow

Replace for the virtual-phone path:
- LiveContainer executable patching
- in-process guest launch
- LiveProcess app hosting
- guest Mach-O relaunch tickets

Add:
- `Runtime/VPhoneCoreBridge`
- `Runtime/FirmwareStore`
- `Runtime/VirtualPhoneSession`
- `Runtime/DisplayBridge`
- `Runtime/InputBridge`
- `Runtime/NetworkBridge`
- `Runtime/GuestBootstrap`

## First engineering milestone

The first milestone is deliberately lower than "SpringBoard works":

- VibeContainers host app launches on a real iPhone/iPad.
- A virtual-phone session can allocate guest RAM and create the vphone-derived machine/runtime.
- A user-selected IPSW can be imported and indexed.
- Kernelcache/ramdisk/device-tree artifacts can be resolved for one supported target.
- Guest boot reaches the first serial/kernel log without using a PC.

Only after that milestone is green do we enable full userspace, framebuffer, touch, networking and guest jailbreak bootstrap.

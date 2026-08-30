# iOS Runtime Architecture — VibeContainers + Nyxian + vPhone

Target branch: `temp/darwin-vm-windows11`

## Goal

Build an iPhone/iPad-only, real-device host that behaves like a self-contained virtual/jailbroken iOS environment without QEMU or a generic VM UI.

The runtime executes ARM64 guest code natively where possible and virtualizes the kernel-facing contract in userspace. It does not attempt to boot a second XNU kernel inside a stock iOS app.

## Layer ownership

### 1. VibeContainers — host shell

Reuse the existing physical-device app as the product shell:

- SwiftUI SpringBoard-style home screen and multitasking UX
- iPhone/iPad layouts, gestures and app switching
- package/source import and download flows
- persistent guest/container storage
- existing real-device Xcode project
- unsigned IPA packaging and GitHub Actions
- host-side settings, logs and diagnostics

The existing LiveContainer guest execution backend becomes a compatibility backend only. New virtual-phone processes launch through `RuntimeCore` instead.

### 2. Nyxian — userspace kernel foundation

Fork the relevant AGPL-3.0 Nyxian/LindChain components into a clearly attributed `RuntimeCore/KernelSurface` layer and adapt them to a single virtual-phone runtime.

Initial kernel personality responsibilities:

- process objects, PIDs and lifecycle
- privilege/credential model
- virtual entitlements
- task-port handoff and Mach IPC service
- guest memory copy in/out
- virtual file descriptor/process tables
- syscall shims and dispatch
- `posix_spawn`/`vfork`/`sysctl`/`ioctl`/`libproc` compatibility
- `task_for_pid`/`task_name_for_pid` guest semantics
- guest `setuid`/`setgid` semantics
- virtual mount/root filesystem namespace
- launch service and process-pool integration

Rename only product-facing APIs; preserve upstream copyright/SPDX attribution and AGPL requirements.

### 3. vPhone/vphone-cli — guest firmware + jailbreak recipe

Do not embed the unlicensed `34306/vphone-aio` archive or redistribute Apple firmware.

Port the MIT-licensed `Lakr233/vphone-cli` concepts that are useful to a userspace guest:

- firmware/IPSW metadata parsing and version selection
- root filesystem layout knowledge
- jailbreak/bootstrap staging recipe
- Procursus `/var/jb` layout
- first-boot bootstrap finalization
- Sileo/APT package setup
- jailbreak marker/layout conventions
- optional guest SSH service
- package/deb staging and persistence

Hardware-VM-only boot-chain patches, Virtualization.framework plumbing, DFU restore, PV=3 and macOS SIP/AMFI code do not belong in the on-device runtime.

## Runtime model

```text
VibeContainers UI / Window Manager
            |
            v
       RuntimeBridge
            |
            v
+-------------------------------+
| RuntimeCore                   |
|  ProcessManager               |
|  KernelSurface (Nyxian)       |
|  MachIPC                      |
|  SyscallShim                  |
|  VirtualCredentials           |
|  VirtualEntitlements          |
|  VirtualFS                    |
|  LaunchService                |
+-------------------------------+
            |
            v
+-------------------------------+
| VPhoneGuest                   |
|  /System view                 |
|  /private/var                 |
|  /var/jb -> Procursus         |
|  dpkg/apt/Sileo               |
|  guest apps + daemons         |
+-------------------------------+
            |
            v
 Native ARM64 NSExtension/host
 process pool on real iOS/iPadOS
```

## Important distinction: custom kernel

`KernelSurface` is a userspace microkernel/personality, not a replacement for the host device's XNU kernel. This is intentional. A normal iOS app cannot boot a second privileged XNU kernel directly. Because the host and guest are both ARM64, native guest execution plus syscall/Mach virtualization is the preferred architecture and avoids CPU emulation.

## Repository layout

```text
ios-runtime/
  HostBridge/
  RuntimeCore/
    KernelSurface/
    MachIPC/
    Process/
    Syscalls/
    Credentials/
    Entitlements/
    VirtualFS/
    LaunchService/
  Guest/
    Bootstrap/
    PackageManager/
    RootFS/
    Profiles/
  Display/
  Input/
  Network/
  Diagnostics/
  Tests/
  THIRD_PARTY.md
```

The existing VibeContainers source should be vendored/imported under a separate host directory or brought in as a source snapshot with commit provenance; do not overwrite unrelated temp-branch work blindly.

## Build lane

Create one iOS-only workflow:

`ios-runtime-unsigned.yml`

It should:

1. Build `RuntimeCore` for `iphoneos` arm64.
2. Build the VibeContainers-derived host app for generic iOS device with signing disabled.
3. Verify the runtime symbols are linked into the app.
4. Package `Payload/<App>.app` into an unsigned IPA.
5. Run static checks ensuring no certificate, `.p12`, provisioning profile, Apple IPSW/rootfs, or private key is embedded.
6. Upload the unsigned IPA plus a small runtime diagnostics report.

## Execution modes

### Primary: native ARM64 guest process

Use Nyxian-style NSExtension process workers. Guest Mach-O code executes on the physical ARM64 CPU. Kernel-sensitive behavior routes through shims/KernelSurface.

### Compatibility fallback

Keep the existing VibeContainers/LiveContainer path only for apps that cannot yet run through KernelSurface. It is not the virtual-phone architecture and should be visibly labeled as compatibility mode.

No QEMU backend is part of this iOS target.

## Guest filesystem

Do not ship Apple system images in the IPA.

Create a per-virtual-phone filesystem under the app container:

```text
VirtualPhones/<uuid>/
  SystemView/
  private/var/
  preboot/
  var-jb/
  Applications/
  Containers/
  state.plist
```

Phase 1 can synthesize only the paths/services needed by guest apps. Later, an IPSW importer may allow the user to provide compatible firmware and extract permitted runtime assets locally on-device without redistributing them in the project.

The jailbreak layer should reproduce vPhone's Procursus conventions inside this virtual root, not alter or jailbreak the physical host device.

## Display/input strategy

VibeContainers remains the initial window server / SpringBoard-style shell.

Each guest application gets a surface/session owned by the host UI. RuntimeCore maps guest lifecycle and scene state into the existing VibeContainers window/switcher model.

Do not make real Apple SpringBoard a prerequisite for v1. Once process, Mach IPC, frameworks and system-service compatibility are mature, investigate launching the firmware SpringBoard as an optional advanced guest shell.

## Networking

Start with host-proxied networking per guest namespace:

- URLSession/socket proxy for ordinary traffic
- virtual interface identity maintained by RuntimeCore
- per-guest DNS/proxy configuration
- later raw socket/NE-based support only where platform permissions allow

This gives the virtual phone internet access without pretending to emulate a physical Wi-Fi chipset.

## Jailbreak environment

Recreate the vPhone jailbreak userspace inside the guest namespace:

1. initialize `/private/preboot/<guest-id>/jb-vphone/procursus`
2. publish `/var/jb` into the guest VFS
3. install/bootstrap Procursus-owned tools
4. initialize dpkg/apt state
5. stage Sileo and user-provided packages
6. expose guest-root credentials through KernelSurface
7. run launch-service-managed guest daemons
8. keep all jailbreak state isolated from physical iOS

Tweak injection is a later milestone and must target guest processes only.

## Milestones / gates

### M0 — source freeze and legal/provenance gate

- Pin exact VibeContainers, Nyxian and vphone-cli source commits.
- Add `THIRD_PARTY.md` and preserve licenses.
- No vphone-aio archive or Apple firmware committed.

**Pass:** repository provenance is reproducible.

### M1 — host builds unchanged

- Import VibeContainers host into temp branch.
- Produce an unsigned real-device IPA from GitHub Actions.

**Pass:** IPA contains the existing host and launches after user signing.

### M2 — KernelSurface boots

- Link Nyxian-derived RuntimeCore.
- Initialize a userspace kernel instance.
- Create PID namespace and one worker process.
- Exercise object/radix/process APIs.

**Pass:** diagnostics show `kernelSurface=ready`, PID 1 exists, worker task port registered.

### M3 — first native guest binary

- Launch a simple ARM64 Mach-O inside a worker extension.
- Route basic filesystem/process/sysctl calls through RuntimeCore.
- Capture stdout/stderr in VibeContainers.

**Pass:** guest binary runs without QEMU and sees the virtual root/process identity.

### M4 — virtual root + jailbreak bootstrap

- Implement `/var/jb`, Procursus layout, dpkg state and virtual root credentials.
- Port vphone-cli first-boot bootstrap concepts.

**Pass:** guest shell reports uid 0 in KernelSurface and can run package-manager binaries against the virtual filesystem without modifying the physical host filesystem.

### M5 — real guest app window

- Launch a UIKit app through the new runtime.
- Bridge its scene/surface into the existing VibeContainers window manager.
- Route touch/keyboard and lifecycle controls.

**Pass:** an app opens, renders, accepts touch, backgrounds/resumes, and closes from the host shell.

### M6 — multi-process virtual phone

- Multiple worker extensions/process objects.
- Mach IPC between guest processes.
- launch-service-managed daemons.
- per-process entitlements/credentials.

**Pass:** two or more guest apps/daemons run concurrently and communicate through the virtual kernel contract.

### M7 — jailbreak UX

- Sileo/APT UI inside guest.
- install/uninstall guest packages.
- guest-only tweak loader experiment.

**Pass:** packages alter only the virtual phone and persist across host app restarts.

### M8 — advanced system compatibility

- Broaden private-framework/service shims.
- IPSW user-import pipeline.
- investigate firmware system-app launch, including SpringBoard, only after dependencies are mapped.

**Pass:** system components run only when their required service graph is correctly virtualized; no fake 'green' claim based only on compilation.

## First implementation sequence

1. Snapshot VibeContainers host at its selected commit into the temp branch.
2. Add RuntimeCore as a separate target/module; do not mutate the old LiveContainer backend yet.
3. Port the smallest compilable Nyxian KernelSurface + process object set.
4. Add a bridge: `RuntimeStart`, `RuntimeSpawn`, `RuntimeSignal`, `RuntimeStop`, `RuntimeCopyIn`, `RuntimeCopyOut`.
5. Add one extension worker target for native guest execution.
6. Make GitHub Actions produce an unsigned arm64 IPA and run a runtime-link smoke test.
7. Only after M2 is green, replace one VibeContainers guest-launch button with the new runtime path.
8. Then build the vPhone-inspired virtual jailbreak/rootfs layer.

## Non-goals for the first build

- no QEMU
- no generic VM creator UI
- no Windows EXE
- no bundled Apple firmware
- no physical-host jailbreak
- no claim that Apple SpringBoard is working until it actually renders and accepts input
- no dependency on a Mac at runtime

## Definition of the product

This is a dedicated **native ARM64 virtual iPhone runtime for iPhone/iPad**: VibeContainers supplies the polished phone shell, Nyxian supplies the userspace kernel/process model, and vPhone supplies the proven jailbreak/bootstrap/system-layout knowledge.

# ViPhone

ViPhone is an iPhone/iPad-only virtual-phone experiment. The native VibeContainers host links a purpose-built NyxRuntime interpreter and integrates the pinned Nyxian userspace-kernel surface. It does not use QEMU, Virtualization.framework, or a companion computer.

Current milestone: M1 freestanding Nyxian entry execution through the NyxRuntime interpreter.

## Source layout

- `Host/VibeContainers`: pinned native iOS/iPadOS host application.
- `Runtime`: NyxRuntime public ABI and specialized AArch64 interpreter core.
- `Kernel/Nyxian`: pinned Nyxian source and ksurface ABI donor.
- `HostIntegration`: Swift bridge and diagnostics integrated into the host target.
- `VPhoneResearchKit`: metadata-only home for transferable firmware research.

Apple firmware is never stored in this repository. Future firmware preparation accepts only user-supplied IPSWs.

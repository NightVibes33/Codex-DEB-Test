# VPhone iOS build status

Current target: M0 custom runtime seed integrated into the current VibeContainers real-device host.

Verified before the full IPA link:

- QEMU-free VibeKernel/VPhoneRuntime source check: PASS
- native AArch64 interpreter smoke test: PASS
- iPhoneOS arm64 cross-compile: PASS

Pending CI gate:

- exact pinned VibeContainers + vphone-cli source fetch
- runtime Xcode target injection
- unsigned real-device IPA link/package
- binary marker validation proving VibeKernel is present in the IPA

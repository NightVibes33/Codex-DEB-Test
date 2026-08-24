# VirtualMac Hypervisor Probe Status

- Run: 32682777152
- Commit: 487325b103333274dd6a9c848f5c908581688134
- Build: failure
- Device: skipped

## Device output
```text
No device output produced.
```

## Build output
```text
[0;36m==> [1;39mCleaning…[m
[1;31m> [1;3;39mMaking all for tool vmhvprobe…[m
[0;32m==> [1;39mCompiling hvprobe.c (arm64)…[m
[1mhvprobe.c:8:64: [0m[0;1;31merror: [0m[1munused parameter 'call' [-Werror,-Wunused-parameter][0m
__attribute__((naked)) static uint64_t vm_hv_trap(unsigned int call, void *argument) {
[0;1;32m                                                               ^
[0m[1mhvprobe.c:8:76: [0m[0;1;31merror: [0m[1munused parameter 'argument' [-Werror,-Wunused-parameter][0m
__attribute__((naked)) static uint64_t vm_hv_trap(unsigned int call, void *argument) {
[0;1;32m                                                                           ^
[0m2 errors generated.
make[3]: *** [/opt/theos/makefiles/instance/rules.mk:321: /home/runner/work/Codex-DEB-Test/Codex-DEB-Test/VirtualMacProbe/.theos/obj/arm64/hvprobe.c.ca1b327c.o] Error 1
make[2]: *** [/opt/theos/makefiles/instance/tool.mk:20: /home/runner/work/Codex-DEB-Test/Codex-DEB-Test/VirtualMacProbe/.theos/obj/arm64/vmhvprobe] Error 2
make[1]: *** [/opt/theos/makefiles/instance/tool.mk:11: internal-tool-all_] Error 2
make: *** [/opt/theos/makefiles/master/rules.mk:146: vmhvprobe.all.tool.variables] Error 2
make_exit_code=2
```

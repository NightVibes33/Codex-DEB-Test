#include <stdint.h>
#include <stdio.h>

#define HV_CALL_VM_GET_CAPABILITIES 0u
#define HV_CALL_VM_CREATE 1u
#define HV_UNSUPPORTED ((int32_t)0xfae9400f)

__attribute__((naked)) static uint64_t vm_hv_trap(unsigned int call, void *argument) {
    __asm__ volatile(
        "mov x16, #-0x5\n"
        "svc #0x80\n"
        "ret\n");
}

int main(void) {
    int64_t capabilities = (int64_t)vm_hv_trap(HV_CALL_VM_GET_CAPABILITIES, NULL);
    printf("probe=VirtualMac-hv_trap\n");
    printf("hv_get_capabilities_raw=0x%016llx\n", (unsigned long long)capabilities);
    printf("hv_unsupported_raw=0x%08x\n", (unsigned int)(uint32_t)HV_UNSUPPORTED);

    if ((int32_t)capabilities == HV_UNSUPPORTED) {
        puts("hypervisor_status=UNSUPPORTED");
        puts("virtualmac_hardware_backend=BLOCKED");
        return 2;
    }

    puts("hypervisor_status=AVAILABLE_OR_RECOGNIZED");
    int64_t create_result = (int64_t)vm_hv_trap(HV_CALL_VM_CREATE, NULL);
    printf("hv_vm_create_null_raw=0x%016llx\n", (unsigned long long)create_result);
    if ((int32_t)create_result == HV_UNSUPPORTED) {
        puts("vm_create_status=UNSUPPORTED");
        return 3;
    }
    puts("vm_create_status=TRAP_RECOGNIZED");
    return 0;
}

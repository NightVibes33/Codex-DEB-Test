#include "VPhoneRuntimeCore.h"

#include <stdint.h>
#include <stdio.h>

static uint32_t movz_x(unsigned rd, unsigned imm16) {
    return UINT32_C(0xD2800000) | ((imm16 & 0xFFFFu) << 5) | (rd & 31u);
}

static uint32_t add_x_imm(unsigned rd, unsigned rn, unsigned imm12) {
    return UINT32_C(0x91000000) | ((imm12 & 0xFFFu) << 10) |
           ((rn & 31u) << 5) | (rd & 31u);
}

int main(void) {
    VPMachineConfig cfg = {1, 64ULL * 1024 * 1024, 1179, 2556, 460, 3.0};
    VPRuntime *rt = vp_runtime_create(&cfg);
    if (!rt) return 10;

    const uint64_t base = UINT64_C(0x4000);
    const uint32_t program[] = {
        movz_x(0, 1),
        add_x_imm(0, 0, 1),
        add_x_imm(0, 0, 1),
        UINT32_C(0xD503207F), /* WFI */
        add_x_imm(0, 0, 1),
        UINT32_C(0xD4400000), /* HLT */
    };

    if (vp_runtime_memory_write(rt, base, program, sizeof(program)) != VP_STATUS_OK) return 11;
    if (vp_runtime_set_boot_vector(rt, base) != VP_STATUS_OK) return 12;

    /* First slice retires exactly two instructions and preserves CPU state. */
    vp_runtime_set_instruction_budget(rt, 2);
    if (vp_runtime_boot(rt) != VP_STATUS_BUDGET_EXHAUSTED) return 20;
    if (vp_runtime_state(rt) != VP_RUNTIME_PAUSED) return 21;
    if (vp_runtime_instructions_retired(rt) != 2) return 22;

    /* Resume, execute one ADD, then WFI. Total retired count must continue. */
    vp_runtime_set_instruction_budget(rt, 100);
    if (vp_runtime_boot(rt) != VP_STATUS_GUEST_WAITING) return 30;
    if (vp_runtime_state(rt) != VP_RUNTIME_WAITING) return 31;
    if (vp_runtime_instructions_retired(rt) != 4) return 32;

    /* Calling boot while unsignaled must remain waiting and retire nothing. */
    if (vp_runtime_boot(rt) != VP_STATUS_GUEST_WAITING) return 33;
    if (vp_runtime_instructions_retired(rt) != 4) return 34;

    if (vp_runtime_signal_event(rt) != VP_STATUS_OK) return 40;
    if (vp_runtime_state(rt) != VP_RUNTIME_PAUSED) return 41;

    /* Resume after WFI, execute final ADD and HLT. */
    if (vp_runtime_boot(rt) != VP_STATUS_OK) return 50;
    if (vp_runtime_state(rt) != VP_RUNTIME_STOPPED) return 51;
    if (vp_runtime_instructions_retired(rt) != 6) return 52;

    printf("runtime-resume=ok retired=%llu\n",
           (unsigned long long)vp_runtime_instructions_retired(rt));
    vp_runtime_destroy(rt);
    return 0;
}

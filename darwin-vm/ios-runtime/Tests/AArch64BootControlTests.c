#include "VPhoneRuntimeCore.h"
#include "VPhoneAArch64.h"

#include <stdint.h>
#include <stdio.h>

#define SYSREG(op0, op1, crn, crm, op2) \
    ((((uint16_t)(op0) & 3u) << 14) | (((uint16_t)(op1) & 7u) << 11) | \
     (((uint16_t)(crn) & 15u) << 7) | (((uint16_t)(crm) & 15u) << 3) | \
     ((uint16_t)(op2) & 7u))

#define SYS_CURRENTEL SYSREG(3, 0, 4, 2, 2)
#define SYS_SCTLR_EL1 SYSREG(3, 0, 1, 0, 0)
#define SYS_ELR_EL1   SYSREG(3, 0, 4, 0, 1)
#define SYS_SPSR_EL1  SYSREG(3, 0, 4, 0, 0)

static uint32_t movz_x(unsigned rd, unsigned imm16) {
    return UINT32_C(0xD2800000) | ((imm16 & 0xFFFFu) << 5) | (rd & 31u);
}

static uint32_t mrs(unsigned rt, uint16_t sysreg) {
    return UINT32_C(0xD5200000) | ((uint32_t)sysreg << 5) | (rt & 31u);
}

static uint32_t msr(uint16_t sysreg, unsigned rt) {
    return UINT32_C(0xD5000000) | ((uint32_t)sysreg << 5) | (rt & 31u);
}

static uint32_t cbz_x(unsigned rt, int32_t byte_offset) {
    const int32_t words = byte_offset / 4;
    return UINT32_C(0xB4000000) | (((uint32_t)words & UINT32_C(0x7FFFF)) << 5) | (rt & 31u);
}

static int step_expect(VPRuntime *rt, VPAArch64CPU *cpu, VPCPUStepResult expected, int code) {
    const VPCPUStepResult got = vp_aarch64_step(rt, cpu, NULL);
    if (got != expected) {
        fprintf(stderr, "step %d expected=%d got=%d pc=0x%llx\n",
                code, (int)expected, (int)got, (unsigned long long)cpu->pc);
        return code;
    }
    return 0;
}

int main(void) {
    VPMachineConfig cfg = {1, 64ULL * 1024 * 1024, 1179, 2556, 460, 3.0};
    VPRuntime *rt = vp_runtime_create(&cfg);
    if (!rt) return 10;

    /* Keep the synthetic ERET target within MOVZ's low 16-bit range. */
    const uint64_t base = UINT64_C(0x8000);
    const uint64_t eret_target = base + UINT64_C(0x80);
    const uint32_t program[] = {
        mrs(0, SYS_CURRENTEL),                /* x0 = 4 (EL1) */
        movz_x(1, 0x1234),
        msr(SYS_SCTLR_EL1, 1),
        mrs(2, SYS_SCTLR_EL1),                /* x2 = 0x1234 */
        cbz_x(3, 8),                           /* x3 == 0, skip HLT */
        UINT32_C(0xD4400000),                 /* HLT: must be skipped */
        UINT32_C(0xD503207F),                 /* WFI */
        mrs(4, SYS_CURRENTEL),
        movz_x(5, (unsigned)eret_target),
        msr(SYS_ELR_EL1, 5),
        movz_x(6, 0x0005),                    /* SPSR: EL1h */
        msr(SYS_SPSR_EL1, 6),
        UINT32_C(0xD69F03E0),                 /* ERET -> eret_target */
    };
    const uint32_t target[] = {
        mrs(7, SYS_CURRENTEL),
        UINT32_C(0xD4400000),
    };

    if (vp_runtime_memory_write(rt, base, program, sizeof(program)) != VP_STATUS_OK) return 11;
    if (vp_runtime_memory_write(rt, eret_target, target, sizeof(target)) != VP_STATUS_OK) return 12;

    VPAArch64CPU cpu;
    vp_aarch64_reset(&cpu, base);

    /* Execute through CBZ. It must skip the HLT and land on WFI. */
    for (int i = 0; i < 5; i++) {
        const int rc = step_expect(rt, &cpu, VP_CPU_STEP_OK, 20 + i);
        if (rc) return rc;
    }
    if (cpu.x[0] != 4 || cpu.x[2] != UINT64_C(0x1234)) return 30;
    if (cpu.pc != base + 6 * 4) return 31;

    if (step_expect(rt, &cpu, VP_CPU_STEP_WAITING, 32)) return 32;
    if (!cpu.waiting || cpu.pc != base + 7 * 4) return 33;
    if (vp_aarch64_step(rt, &cpu, NULL) != VP_CPU_STEP_WAITING) return 34;
    vp_aarch64_wake(&cpu);

    /* MRS, ELR write, SPSR write and ERET. */
    for (int i = 0; i < 6; i++) {
        const int rc = step_expect(rt, &cpu, VP_CPU_STEP_OK, 40 + i);
        if (rc) return rc;
    }
    if (cpu.pc != eret_target) return 50;
    if (cpu.current_el != 1) return 51;

    if (step_expect(rt, &cpu, VP_CPU_STEP_OK, 52)) return 52;
    if (cpu.x[7] != 4) return 53;
    if (step_expect(rt, &cpu, VP_CPU_STEP_HALTED, 54)) return 54;

    printf("aarch64-boot-control=ok currentEL=%llu sctlr=0x%llx retired=%llu\n",
           (unsigned long long)cpu.x[7],
           (unsigned long long)cpu.sys.sctlr_el1,
           (unsigned long long)cpu.instructions_retired);

    vp_runtime_destroy(rt);
    return 0;
}

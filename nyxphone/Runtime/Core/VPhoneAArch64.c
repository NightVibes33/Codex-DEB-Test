#include "VPhoneAArch64.h"

#include <string.h>

#define VP_SYSREG(op0, op1, crn, crm, op2) \
    ((((uint16_t)(op0) & 3u) << 14) | (((uint16_t)(op1) & 7u) << 11) | \
     (((uint16_t)(crn) & 15u) << 7) | (((uint16_t)(crm) & 15u) << 3) | \
     ((uint16_t)(op2) & 7u))

#define VP_SYS_CURRENTEL   VP_SYSREG(3, 0, 4, 2, 2)
#define VP_SYS_SPSEL       VP_SYSREG(3, 0, 4, 2, 0)
#define VP_SYS_NZCV        VP_SYSREG(3, 3, 4, 2, 0)
#define VP_SYS_DAIF        VP_SYSREG(3, 3, 4, 2, 1)
#define VP_SYS_SCTLR_EL1   VP_SYSREG(3, 0, 1, 0, 0)
#define VP_SYS_TTBR0_EL1   VP_SYSREG(3, 0, 2, 0, 0)
#define VP_SYS_TTBR1_EL1   VP_SYSREG(3, 0, 2, 0, 1)
#define VP_SYS_TCR_EL1     VP_SYSREG(3, 0, 2, 0, 2)
#define VP_SYS_SPSR_EL1    VP_SYSREG(3, 0, 4, 0, 0)
#define VP_SYS_ELR_EL1     VP_SYSREG(3, 0, 4, 0, 1)
#define VP_SYS_SP_EL0      VP_SYSREG(3, 0, 4, 1, 0)
#define VP_SYS_ESR_EL1     VP_SYSREG(3, 0, 5, 2, 0)
#define VP_SYS_FAR_EL1     VP_SYSREG(3, 0, 6, 0, 0)
#define VP_SYS_MAIR_EL1    VP_SYSREG(3, 0, 10, 2, 0)
#define VP_SYS_VBAR_EL1    VP_SYSREG(3, 0, 12, 0, 0)
#define VP_SYS_TPIDR_EL0   VP_SYSREG(3, 3, 13, 0, 2)
#define VP_SYS_TPIDRRO_EL0 VP_SYSREG(3, 3, 13, 0, 3)
#define VP_SYS_TPIDR_EL1   VP_SYSREG(3, 0, 13, 0, 4)
#define VP_SYS_CNTFRQ_EL0  VP_SYSREG(3, 3, 14, 0, 0)
#define VP_SYS_CNTPCT_EL0  VP_SYSREG(3, 3, 14, 0, 1)
#define VP_SYS_CNTVCT_EL0  VP_SYSREG(3, 3, 14, 0, 2)

static int64_t vp_sign_extend(uint64_t value, unsigned bits) {
    const uint64_t sign = UINT64_C(1) << (bits - 1u);
    return (int64_t)((value ^ sign) - sign);
}

static uint64_t vp_reg_read(const VPAArch64CPU *cpu, uint32_t reg, int sp_allowed) {
    if (reg < 31u) return cpu->x[reg];
    return sp_allowed ? cpu->sp : 0;
}

static void vp_reg_write(VPAArch64CPU *cpu, uint32_t reg, uint64_t value, int is64, int sp_allowed) {
    if (!is64) value = (uint32_t)value;
    if (reg < 31u) cpu->x[reg] = value;
    else if (sp_allowed) cpu->sp = value;
}

static int vp_sysreg_read(VPAArch64CPU *cpu, uint16_t reg, uint64_t *value) {
    if (!cpu || !value) return 0;
    switch (reg) {
        case VP_SYS_CURRENTEL:   *value = ((uint64_t)cpu->current_el & 3u) << 2; return 1;
        case VP_SYS_SPSEL:       *value = cpu->sys.spsel & 1u; return 1;
        case VP_SYS_NZCV:        *value = cpu->sys.nzcv; return 1;
        case VP_SYS_DAIF:        *value = cpu->sys.daif; return 1;
        case VP_SYS_SCTLR_EL1:   *value = cpu->sys.sctlr_el1; return 1;
        case VP_SYS_TTBR0_EL1:   *value = cpu->sys.ttbr0_el1; return 1;
        case VP_SYS_TTBR1_EL1:   *value = cpu->sys.ttbr1_el1; return 1;
        case VP_SYS_TCR_EL1:     *value = cpu->sys.tcr_el1; return 1;
        case VP_SYS_SPSR_EL1:    *value = cpu->sys.spsr_el1; return 1;
        case VP_SYS_ELR_EL1:     *value = cpu->sys.elr_el1; return 1;
        case VP_SYS_SP_EL0:      *value = cpu->sys.sp_el0; return 1;
        case VP_SYS_ESR_EL1:     *value = cpu->sys.esr_el1; return 1;
        case VP_SYS_FAR_EL1:     *value = cpu->sys.far_el1; return 1;
        case VP_SYS_MAIR_EL1:    *value = cpu->sys.mair_el1; return 1;
        case VP_SYS_VBAR_EL1:    *value = cpu->sys.vbar_el1; return 1;
        case VP_SYS_TPIDR_EL0:   *value = cpu->sys.tpidr_el0; return 1;
        case VP_SYS_TPIDRRO_EL0: *value = cpu->sys.tpidrro_el0; return 1;
        case VP_SYS_TPIDR_EL1:   *value = cpu->sys.tpidr_el1; return 1;
        case VP_SYS_CNTFRQ_EL0:  *value = cpu->sys.cntfrq_el0; return 1;
        case VP_SYS_CNTPCT_EL0:
        case VP_SYS_CNTVCT_EL0:  *value = cpu->sys.counter_ticks; return 1;
        default: return 0;
    }
}

static int vp_sysreg_write(VPAArch64CPU *cpu, uint16_t reg, uint64_t value) {
    if (!cpu) return 0;
    switch (reg) {
        case VP_SYS_SPSEL:       cpu->sys.spsel = (uint32_t)(value & 1u); return 1;
        case VP_SYS_NZCV:        cpu->sys.nzcv = value & UINT64_C(0xF0000000); return 1;
        case VP_SYS_DAIF:        cpu->sys.daif = value & UINT64_C(0x3C0); return 1;
        case VP_SYS_SCTLR_EL1:   cpu->sys.sctlr_el1 = value; return 1;
        case VP_SYS_TTBR0_EL1:   cpu->sys.ttbr0_el1 = value; return 1;
        case VP_SYS_TTBR1_EL1:   cpu->sys.ttbr1_el1 = value; return 1;
        case VP_SYS_TCR_EL1:     cpu->sys.tcr_el1 = value; return 1;
        case VP_SYS_SPSR_EL1:    cpu->sys.spsr_el1 = value; return 1;
        case VP_SYS_ELR_EL1:     cpu->sys.elr_el1 = value; return 1;
        case VP_SYS_SP_EL0:      cpu->sys.sp_el0 = value; return 1;
        case VP_SYS_ESR_EL1:     cpu->sys.esr_el1 = value; return 1;
        case VP_SYS_FAR_EL1:     cpu->sys.far_el1 = value; return 1;
        case VP_SYS_MAIR_EL1:    cpu->sys.mair_el1 = value; return 1;
        case VP_SYS_VBAR_EL1:    cpu->sys.vbar_el1 = value; return 1;
        case VP_SYS_TPIDR_EL0:   cpu->sys.tpidr_el0 = value; return 1;
        case VP_SYS_TPIDRRO_EL0: cpu->sys.tpidrro_el0 = value; return 1;
        case VP_SYS_TPIDR_EL1:   cpu->sys.tpidr_el1 = value; return 1;
        case VP_SYS_CNTFRQ_EL0:  cpu->sys.cntfrq_el0 = value; return 1;
        default: return 0;
    }
}

static VPCPUStepResult vp_retire(VPAArch64CPU *cpu, uint64_t next_pc) {
    cpu->pc = next_pc;
    cpu->instructions_retired++;
    cpu->sys.counter_ticks++;
    return VP_CPU_STEP_OK;
}

void vp_aarch64_reset(VPAArch64CPU *cpu, uint64_t reset_vector) {
    if (!cpu) return;
    memset(cpu, 0, sizeof(*cpu));
    cpu->pc = reset_vector;
    cpu->current_el = 1;
    cpu->pstate = UINT64_C(0x5); /* EL1h. */
    cpu->sys.spsel = 1;
    cpu->sys.cntfrq_el0 = UINT64_C(24000000);
    cpu->sys.daif = UINT64_C(0x3C0);
}

void vp_aarch64_wake(VPAArch64CPU *cpu) {
    if (!cpu) return;
    cpu->waiting = 0;
}

VPCPUStepResult vp_aarch64_step(VPRuntime *runtime, VPAArch64CPU *cpu, uint32_t *instruction_out) {
    if (!runtime || !cpu) return VP_CPU_STEP_MEMORY_FAULT;
    if (cpu->halted) return VP_CPU_STEP_HALTED;
    if (cpu->waiting) return VP_CPU_STEP_WAITING;

    uint32_t insn = 0;
    if (vp_runtime_memory_read(runtime, cpu->pc, &insn, sizeof(insn)) != VP_STATUS_OK) {
        return VP_CPU_STEP_MEMORY_FAULT;
    }
    if (instruction_out) *instruction_out = insn;

    const uint64_t current_pc = cpu->pc;
    const uint64_t next_pc = current_pc + 4u;

    /* Common hints. */
    if (insn == UINT32_C(0xD503201F) || /* NOP */
        insn == UINT32_C(0xD503203F) || /* YIELD */
        insn == UINT32_C(0xD503209F) || /* SEV */
        insn == UINT32_C(0xD50320BF)) { /* SEVL */
        return vp_retire(cpu, next_pc);
    }

    /* WFE / WFI complete, advance PC, then wait for a synthetic interrupt/event. */
    if (insn == UINT32_C(0xD503205F) || insn == UINT32_C(0xD503207F)) {
        cpu->waiting = 1;
        cpu->pc = next_pc;
        cpu->instructions_retired++;
        cpu->sys.counter_ticks++;
        return VP_CPU_STEP_WAITING;
    }

    /* CLREX / DSB / DMB / ISB. Ordering is implicit in the interpreter. */
    if ((insn & UINT32_C(0xFFFFF0FF)) == UINT32_C(0xD503305F) ||
        (insn & UINT32_C(0xFFFFF0FF)) == UINT32_C(0xD503309F) ||
        (insn & UINT32_C(0xFFFFF0FF)) == UINT32_C(0xD50330BF) ||
        (insn & UINT32_C(0xFFFFF0FF)) == UINT32_C(0xD50330DF)) {
        return vp_retire(cpu, next_pc);
    }

    /* MSR DAIFSet/DAIFClr, #imm4. */
    if ((insn & UINT32_C(0xFFFFF0FF)) == UINT32_C(0xD50340DF)) {
        const uint64_t imm = (insn >> 8) & 0xFu;
        cpu->sys.daif |= imm << 6;
        return vp_retire(cpu, next_pc);
    }
    if ((insn & UINT32_C(0xFFFFF0FF)) == UINT32_C(0xD50340FF)) {
        const uint64_t imm = (insn >> 8) & 0xFu;
        cpu->sys.daif &= ~(imm << 6);
        return vp_retire(cpu, next_pc);
    }

    /* MSR SPSel, #imm1. */
    if ((insn & UINT32_C(0xFFFFF0FF)) == UINT32_C(0xD50040BF)) {
        cpu->sys.spsel = (insn >> 8) & 1u;
        return vp_retire(cpu, next_pc);
    }

    /* MRS / MSR (register) for the early EL1 register set used by iBoot/XNU. */
    if ((insn & UINT32_C(0xFFE00000)) == UINT32_C(0xD5200000)) {
        const uint16_t sysreg = (uint16_t)((insn >> 5) & UINT32_C(0xFFFF));
        const uint32_t rt = insn & 31u;
        uint64_t value = 0;
        if (!vp_sysreg_read(cpu, sysreg, &value)) return VP_CPU_STEP_SYSTEM_REGISTER_FAULT;
        vp_reg_write(cpu, rt, value, 1, 0);
        return vp_retire(cpu, next_pc);
    }
    if ((insn & UINT32_C(0xFFE00000)) == UINT32_C(0xD5000000)) {
        const uint16_t sysreg = (uint16_t)((insn >> 5) & UINT32_C(0xFFFF));
        const uint32_t rt = insn & 31u;
        if (!vp_sysreg_write(cpu, sysreg, vp_reg_read(cpu, rt, 0))) {
            return VP_CPU_STEP_SYSTEM_REGISTER_FAULT;
        }
        return vp_retire(cpu, next_pc);
    }

    /* ERET. Only EL1 return state is modeled today. */
    if (insn == UINT32_C(0xD69F03E0)) {
        cpu->pc = cpu->sys.elr_el1;
        cpu->pstate = cpu->sys.spsr_el1;
        cpu->current_el = (uint32_t)((cpu->pstate >> 2) & 3u);
        cpu->instructions_retired++;
        cpu->sys.counter_ticks++;
        return VP_CPU_STEP_OK;
    }

    /* Nyx hypervisor console ABI: HVC #0x4E58 writes X1 bytes at guest X0. */
    if ((insn & UINT32_C(0xFFE0001F)) == UINT32_C(0xD4000002)) {
        const uint32_t immediate = (insn >> 5) & UINT32_C(0xFFFF);
        if (immediate != UINT32_C(0x4E58)) return VP_CPU_STEP_SYSTEM_REGISTER_FAULT;
        if (vp_runtime_console_write(runtime, cpu->x[0], (size_t)cpu->x[1]) != VP_STATUS_OK) {
            return VP_CPU_STEP_MEMORY_FAULT;
        }
        return vp_retire(cpu, next_pc);
    }

    /* HLT #imm16 */
    if ((insn & UINT32_C(0xFFE0001F)) == UINT32_C(0xD4400000)) {
        cpu->halted = 1;
        cpu->instructions_retired++;
        cpu->sys.counter_ticks++;
        return VP_CPU_STEP_HALTED;
    }

    /*
     * SVC #imm16. Darwin userspace uses X16 as the normal syscall selector.
     * This remains useful for userspace compatibility tests; real guest XNU
     * syscalls will be handled by XNU once the boot path reaches EL0.
     */
    if ((insn & UINT32_C(0xFFE0001F)) == UINT32_C(0xD4000001)) {
        uint64_t args[8];
        for (uint32_t i = 0; i < 8; i++) args[i] = cpu->x[i];
        uint64_t result = 0;
        const VPStatus status = vp_runtime_dispatch_syscall(runtime, cpu->x[16], args, &result);
        if (status != VP_STATUS_OK) return VP_CPU_STEP_SYSCALL_FAULT;
        cpu->x[0] = result;
        cpu->pc = next_pc;
        cpu->instructions_retired++;
        cpu->syscalls_retired++;
        cpu->sys.counter_ticks++;
        return VP_CPU_STEP_OK;
    }

    /* B / BL immediate. */
    const uint32_t branch_class = insn & UINT32_C(0xFC000000);
    if (branch_class == UINT32_C(0x14000000) || branch_class == UINT32_C(0x94000000)) {
        const int64_t offset = vp_sign_extend(insn & UINT32_C(0x03FFFFFF), 26) << 2;
        if (branch_class == UINT32_C(0x94000000)) cpu->x[30] = next_pc;
        cpu->pc = (uint64_t)((int64_t)current_pc + offset);
        cpu->instructions_retired++;
        cpu->sys.counter_ticks++;
        return VP_CPU_STEP_OK;
    }

    /* BR / BLR / RET Xn. */
    const uint32_t branch_reg = insn & UINT32_C(0xFFFFFC1F);
    if (branch_reg == UINT32_C(0xD61F0000) ||
        branch_reg == UINT32_C(0xD63F0000) ||
        branch_reg == UINT32_C(0xD65F0000)) {
        const uint32_t rn = (insn >> 5) & 31u;
        if (branch_reg == UINT32_C(0xD63F0000)) cpu->x[30] = next_pc;
        cpu->pc = vp_reg_read(cpu, rn, 0);
        cpu->instructions_retired++;
        cpu->sys.counter_ticks++;
        return VP_CPU_STEP_OK;
    }

    /* CBZ / CBNZ, 32- and 64-bit. */
    if ((insn & UINT32_C(0x7E000000)) == UINT32_C(0x34000000)) {
        const int is64 = (int)((insn >> 31) & 1u);
        const int nonzero = (int)((insn >> 24) & 1u);
        const uint32_t rt = insn & 31u;
        uint64_t value = vp_reg_read(cpu, rt, 0);
        if (!is64) value = (uint32_t)value;
        const int take = nonzero ? value != 0 : value == 0;
        const int64_t offset = vp_sign_extend((insn >> 5) & UINT32_C(0x7FFFF), 19) << 2;
        return vp_retire(cpu, take ? (uint64_t)((int64_t)current_pc + offset) : next_pc);
    }

    /* TBZ / TBNZ. */
    if ((insn & UINT32_C(0x7E000000)) == UINT32_C(0x36000000)) {
        const uint32_t bit = (((insn >> 31) & 1u) << 5) | ((insn >> 19) & 31u);
        const int nonzero = (int)((insn >> 24) & 1u);
        const uint32_t rt = insn & 31u;
        const int bit_set = (int)((vp_reg_read(cpu, rt, 0) >> bit) & 1u);
        const int take = nonzero ? bit_set : !bit_set;
        const int64_t offset = vp_sign_extend((insn >> 5) & UINT32_C(0x3FFF), 14) << 2;
        return vp_retire(cpu, take ? (uint64_t)((int64_t)current_pc + offset) : next_pc);
    }

    /* ADR / ADRP. */
    const uint32_t adr_class = insn & UINT32_C(0x9F000000);
    if (adr_class == UINT32_C(0x10000000) || adr_class == UINT32_C(0x90000000)) {
        const uint64_t immlo = (insn >> 29) & 3u;
        const uint64_t immhi = (insn >> 5) & UINT32_C(0x7FFFF);
        const int64_t imm = vp_sign_extend((immhi << 2) | immlo, 21);
        const uint32_t rd = insn & 31u;
        uint64_t value;
        if (adr_class == UINT32_C(0x90000000)) {
            value = (uint64_t)(((int64_t)(current_pc & ~UINT64_C(0xFFF))) + (imm << 12));
        } else {
            value = (uint64_t)((int64_t)current_pc + imm);
        }
        vp_reg_write(cpu, rd, value, 1, 0);
        return vp_retire(cpu, next_pc);
    }

    /* MOVZ / MOVK (wide immediate), 32- and 64-bit. */
    const uint32_t wide_class = insn & UINT32_C(0x7F800000);
    if (wide_class == UINT32_C(0x52800000) || wide_class == UINT32_C(0x72800000)) {
        const int is64 = (int)((insn >> 31) & 1u);
        const uint32_t hw = (insn >> 21) & 3u;
        if (!is64 && hw > 1u) return VP_CPU_STEP_UNIMPLEMENTED;
        const uint32_t shift = hw * 16u;
        const uint64_t imm = (uint64_t)((insn >> 5) & UINT32_C(0xFFFF)) << shift;
        const uint32_t rd = insn & 31u;
        uint64_t value = imm;
        if (wide_class == UINT32_C(0x72800000)) {
            const uint64_t mask = ~(UINT64_C(0xFFFF) << shift);
            value = (vp_reg_read(cpu, rd, 0) & mask) | imm;
        }
        vp_reg_write(cpu, rd, value, is64, 0);
        return vp_retire(cpu, next_pc);
    }

    /* ADD/SUB (immediate), without flags. X31 is SP in this encoding. */
    const uint32_t addsub_class = insn & UINT32_C(0x7F000000);
    if (addsub_class == UINT32_C(0x11000000) || addsub_class == UINT32_C(0x51000000)) {
        const int is64 = (int)((insn >> 31) & 1u);
        const uint32_t shift = (insn >> 22) & 1u;
        uint64_t imm = (insn >> 10) & UINT32_C(0xFFF);
        if (shift) imm <<= 12;
        const uint32_t rn = (insn >> 5) & 31u;
        const uint32_t rd = insn & 31u;
        const uint64_t lhs = vp_reg_read(cpu, rn, 1);
        const uint64_t result = addsub_class == UINT32_C(0x51000000) ? lhs - imm : lhs + imm;
        vp_reg_write(cpu, rd, result, is64, 1);
        return vp_retire(cpu, next_pc);
    }

    /* STR/LDR unsigned immediate for W/X registers. */
    const uint32_t ls_class = insn & UINT32_C(0xFFC00000);
    if (ls_class == UINT32_C(0xF9000000) || ls_class == UINT32_C(0xF9400000) ||
        ls_class == UINT32_C(0xB9000000) || ls_class == UINT32_C(0xB9400000)) {
        const int is64 = (ls_class & UINT32_C(0x40000000)) != 0;
        const int is_load = (ls_class & UINT32_C(0x00400000)) != 0;
        const uint32_t rn = (insn >> 5) & 31u;
        const uint32_t rt = insn & 31u;
        const uint64_t scale = is64 ? 8u : 4u;
        const uint64_t address = vp_reg_read(cpu, rn, 1) + (((insn >> 10) & UINT32_C(0xFFF)) * scale);
        if (is_load) {
            uint64_t value = 0;
            const size_t width = is64 ? 8u : 4u;
            if (vp_runtime_memory_read(runtime, address, &value, width) != VP_STATUS_OK) {
                return VP_CPU_STEP_MEMORY_FAULT;
            }
            vp_reg_write(cpu, rt, value, is64, 0);
        } else {
            uint64_t value = vp_reg_read(cpu, rt, 0);
            const size_t width = is64 ? 8u : 4u;
            if (vp_runtime_memory_write(runtime, address, &value, width) != VP_STATUS_OK) {
                return VP_CPU_STEP_MEMORY_FAULT;
            }
        }
        return vp_retire(cpu, next_pc);
    }

    return VP_CPU_STEP_UNIMPLEMENTED;
}
